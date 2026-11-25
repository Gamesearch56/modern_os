#include "ModernNetNm.h"

#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QProcessEnvironment>
#include <QSet>
#include <QTimer>

#include <csignal>
#include <fcntl.h>
#include <unistd.h>

namespace
{
const QString kWifiUp = QStringLiteral( "/usr/lib/modern/live-wifi-up.sh" );
const QString kWifiState = QStringLiteral( "/run/modern/wifi-state" );
const QString kWifiJoin = QStringLiteral( "/usr/lib/modern/wifi-join.sh" );
}  // namespace

ModernNetNm::ModernNetNm( QObject* parent )
    : QObject( parent )
{
}

QStringList
ModernNetNm::splitNmcli( const QString& line )
{
    QStringList out;
    QString cur;
    bool esc = false;
    for ( QChar c : line )
    {
        if ( esc )
        {
            cur += c;
            esc = false;
            continue;
        }
        if ( c == QLatin1Char( '\\' ) )
        {
            esc = true;
            continue;
        }
        if ( c == QLatin1Char( ':' ) )
        {
            out << cur;
            cur.clear();
            continue;
        }
        cur += c;
    }
    out << cur;
    return out;
}

QString
ModernNetNm::run( const QString& bin, const QStringList& args, int timeoutMs )
{
    QProcess p;
    p.start( bin, args );
    // waitForFinished deadlocks once nmcli fills the pipe. Drain while
    // waiting so a long scan cannot stall the installer.
    QByteArray out;
    const int step = 200;
    int left = timeoutMs;
    while ( left > 0 && !p.waitForFinished( step ) )
    {
        out += p.readAllStandardOutput();
        p.readAllStandardError();
        left -= step;
    }
    out += p.readAllStandardOutput();
    if ( p.state() != QProcess::NotRunning )
    {
        p.kill();
        p.waitForFinished( 1000 );
        return {};
    }
    return QString::fromUtf8( out );
}

// A shell killed on its own leaves nmcli running. That client holds
// NetworkManager, the next call waits, and the screen stays on
// "Checking the password…". The child is its own process group.
static void
groupKill( QProcess* proc )
{
    if ( !proc )
    {
        return;
    }
    const qint64 pid = proc->processId();
    if ( pid > 0 )
    {
        ::kill( -pid, SIGKILL );
    }
    proc->kill();
}

static void
leadGroup( QProcess* proc )
{
    proc->setChildProcessModifier( [] {
        ::setpgid( 0, 0 );
    } );
}

// The live session log is what a problem report can still read. The
// password never goes in it. A failed start has no script log at all.
static void
noteJoin( const QString& text )
{
    QFile file( QStringLiteral( "/run/modern/installer/wifi.log" ) );
    if ( !file.open( QIODevice::WriteOnly | QIODevice::Append ) )
    {
        return;
    }
    file.write( text.left( 800 ).toUtf8() );
    file.write( "\n" );
}

// argv and the process environment are world-readable. The secret is a
// 0600 file the script unlinks as it reads it. Stdin is only a second
// copy: closing that pipe before the script reads it used to drop every
// password, and a right one then looked the same as a wrong one.
static QString
writePassFile( const QString& password )
{
    if ( password.isEmpty() )
    {
        return {};
    }
    const char* path = "/run/modern/wifi-pass";
    const int fd = ::open( path, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0600 );
    if ( fd < 0 )
    {
        return {};
    }
    const QByteArray bytes = password.toUtf8() + '\n';
    const ssize_t wrote = ::write( fd, bytes.constData(), static_cast< size_t >( bytes.size() ) );
    ::close( fd );
    if ( wrote != static_cast< ssize_t >( bytes.size() ) )
    {
        ::unlink( path );
        return {};
    }
    return QString::fromLatin1( path );
}

QVector< QPair< QString, QString > >
ModernNetNm::wirelessProfiles() const
{
    QVector< QPair< QString, QString > > out;
    // One call. A second nmcli per profile runs on the UI thread, and a
    // busy NetworkManager makes every one of them wait out its timeout.
    const QString text = run( QStringLiteral( "nmcli" ),
                              { QStringLiteral( "-t" ),
                                QStringLiteral( "-f" ),
                                QStringLiteral( "UUID,TYPE,802-11-wireless.ssid" ),
                                QStringLiteral( "connection" ),
                                QStringLiteral( "show" ) } );
    for ( const QString& line : text.split( QLatin1Char( '\n' ), Qt::SkipEmptyParts ) )
    {
        const QStringList f = splitNmcli( line );
        if ( f.size() < 3 || f.at( 1 ) != QLatin1String( "802-11-wireless" ) )
        {
            continue;
        }
        const QString ssid = f.mid( 2 ).join( QLatin1Char( ':' ) ).trimmed();
        if ( !ssid.isEmpty() && ssid != QLatin1String( "--" ) )
        {
            out.append( qMakePair( f.at( 0 ), ssid ) );
        }
    }
    return out;
}

QSet< QString >
ModernNetNm::knownWifi() const
{
    QSet< QString > out;
    const auto profiles = wirelessProfiles();
    for ( const auto& profile : profiles )
    {
        out.insert( profile.second );
    }
    return out;
}

QStringList
ModernNetNm::uuidsForSsid( const QString& ssid ) const
{
    QStringList out;
    const auto profiles = wirelessProfiles();
    for ( const auto& profile : profiles )
    {
        if ( profile.second == ssid )
        {
            out.append( profile.first );
        }
    }
    return out;
}

void
ModernNetNm::loadWifi( const QSet< QString >& known )
{
    m_networks.clear();
    if ( !m_wifiRadio )
    {
        return;
    }
    // --rescan no: the default list starts a scan and waits for it, so
    // the progress bar never clears and the event loop cannot finish the
    // scan that is already running.
    const QString wifi = run( QStringLiteral( "nmcli" ),
                              { QStringLiteral( "-w" ),
                                QStringLiteral( "4" ),
                                QStringLiteral( "-t" ),
                                QStringLiteral( "-f" ),
                                QStringLiteral( "IN-USE,SSID,SECURITY,SIGNAL" ),
                                QStringLiteral( "device" ),
                                QStringLiteral( "wifi" ),
                                QStringLiteral( "list" ),
                                QStringLiteral( "--rescan" ),
                                QStringLiteral( "no" ) } );
    QSet< QString > seen;
    for ( const QString& line : wifi.split( QLatin1Char( '\n' ), Qt::SkipEmptyParts ) )
    {
        const QStringList f = splitNmcli( line );
        if ( f.size() < 2 )
        {
            continue;
        }
        Wifi w;
        w.inUse = f.at( 0 ).contains( QLatin1Char( '*' ) );
        w.ssid = f.at( 1 ).trimmed();
        w.security = f.size() > 2 ? f.at( 2 ) : QString();
        w.signal = f.size() > 3 ? f.at( 3 ).toInt() : 0;
        w.locked = !w.security.isEmpty() && w.security != QLatin1String( "--" );
        w.known = known.contains( w.ssid );
        if ( w.ssid.isEmpty() || w.ssid == QLatin1String( "--" ) || seen.contains( w.ssid ) )
        {
            continue;
        }
        seen.insert( w.ssid );
        m_networks.append( w );
    }
}

void
ModernNetNm::refresh()
{
    // A scan finishing during a join used to run this on the UI thread.
    // nmcli then waits on that scan, the password sentence never changes,
    // and the timer that would give up cannot run.
    if ( m_connecting )
    {
        return;
    }
    m_ethernetUp = false;
    m_wifiUp = false;
    m_ethernetAddr.clear();
    m_wifiSsid.clear();
    const QString devices = run( QStringLiteral( "nmcli" ),
                                 { QStringLiteral( "-t" ),
                                   QStringLiteral( "-f" ),
                                   QStringLiteral( "TYPE,STATE,CONNECTION" ),
                                   QStringLiteral( "device" ),
                                   QStringLiteral( "status" ) } );
    for ( const QString& line : devices.split( QLatin1Char( '\n' ), Qt::SkipEmptyParts ) )
    {
        const QStringList f = splitNmcli( line );
        if ( f.size() < 2 )
        {
            continue;
        }
        const QString type = f.at( 0 );
        const QString state = f.at( 1 );
        const QString conn = f.size() > 2 ? f.at( 2 ) : QString();
        const bool up = state == QLatin1String( "connected" )
                         || state.startsWith( QLatin1String( "connected" ) );
        if ( type == QLatin1String( "ethernet" ) && up )
        {
            m_ethernetUp = true;
        }
        if ( type == QLatin1String( "wifi" ) && up )
        {
            m_wifiUp = true;
            m_wifiSsid = conn;
        }
    }

    const QString addrs = run( QStringLiteral( "ip" ),
                               { QStringLiteral( "-4" ),
                                 QStringLiteral( "-o" ),
                                 QStringLiteral( "addr" ),
                                 QStringLiteral( "show" ),
                                 QStringLiteral( "scope" ),
                                 QStringLiteral( "global" ) } );
    for ( const QString& line : addrs.split( QLatin1Char( '\n' ), Qt::SkipEmptyParts ) )
    {
        const QStringList bits = line.split( QLatin1Char( ' ' ), Qt::SkipEmptyParts );
        if ( bits.size() < 4 )
        {
            continue;
        }
        const QString iface = bits.at( 1 );
        if ( iface.startsWith( QLatin1String( "wl" ) ) || iface.startsWith( QLatin1String( "lo" ) ) )
        {
            continue;
        }
        m_ethernetAddr = bits.at( 3 ).section( QLatin1Char( '/' ), 0, 0 );
        if ( !m_ethernetAddr.isEmpty() )
        {
            m_ethernetUp = true;
            break;
        }
    }

    const QString radio
        = run( QStringLiteral( "nmcli" ), { QStringLiteral( "radio" ), QStringLiteral( "wifi" ) } )
              .trimmed();
    m_wifiRadio = radio.contains( QLatin1String( "enabled" ) );

    // ip route show default exits 0 with empty stdout when there is no
    // default route. systemd-networkd owns live ethernet, so this is the
    // Next gate even when NM reports the NIC as unmanaged.
    const QString v4 = run( QStringLiteral( "ip" ),
                            { QStringLiteral( "-4" ),
                              QStringLiteral( "route" ),
                              QStringLiteral( "show" ),
                              QStringLiteral( "default" ) } );
    const QString v6 = run( QStringLiteral( "ip" ),
                            { QStringLiteral( "-6" ),
                              QStringLiteral( "route" ),
                              QStringLiteral( "show" ),
                              QStringLiteral( "default" ) } );
    m_hasRoute = !v4.trimmed().isEmpty() || !v6.trimmed().isEmpty();

    m_wifiState.clear();
    QFile state( kWifiState );
    if ( state.open( QIODevice::ReadOnly ) )
    {
        m_wifiState = QString::fromUtf8( state.readLine() ).trimmed();
    }

    loadWifi( knownWifi() );
    emit changed();
}

void
ModernNetNm::scan()
{
    if ( m_scan )
    {
        return;
    }
    m_scanning = true;
    emit changed();
    m_scan = new QProcess( this );
    connect( m_scan, &QProcess::readyReadStandardOutput, m_scan, [ this ]() {
        m_scan->readAllStandardOutput();
    } );
    connect( m_scan, &QProcess::readyReadStandardError, m_scan, [ this ]() {
        m_scan->readAllStandardError();
    } );
    connect( m_scan,
             QOverload< int, QProcess::ExitStatus >::of( &QProcess::finished ),
             this,
             [ this ]() {
                 m_scan->deleteLater();
                 m_scan = nullptr;
                 m_scanning = false;
                 refresh();
             } );
    // live-wifi-up.sh --scan should exit on its own. If it does not, the
    // Refresh bar would stay up for the rest of the step.
    auto* scanLimit = new QTimer( m_scan );
    scanLimit->setSingleShot( true );
    connect( scanLimit, &QTimer::timeout, m_scan, [ this ]() {
        groupKill( m_scan );
    } );
    scanLimit->start( 25000 );
    leadGroup( m_scan );
    // A bare rescan cannot recover a radio that appeared late, was
    // soft-blocked, or was taken by iwd again; the helper does that first.
    if ( QFileInfo( kWifiUp ).isExecutable() )
    {
        m_scan->start( kWifiUp, { QStringLiteral( "--scan" ) } );
        return;
    }
    m_scan->start( QStringLiteral( "nmcli" ),
                   { QStringLiteral( "-w" ),
                     QStringLiteral( "20" ),
                     QStringLiteral( "device" ),
                     QStringLiteral( "wifi" ),
                     QStringLiteral( "list" ),
                     QStringLiteral( "--rescan" ),
                     QStringLiteral( "yes" ) } );
}

void
ModernNetNm::setWifiRadio( bool on )
{
    run( QStringLiteral( "nmcli" ),
         { QStringLiteral( "radio" ),
           QStringLiteral( "wifi" ),
           on ? QStringLiteral( "on" ) : QStringLiteral( "off" ) } );
    refresh();
}

void
ModernNetNm::forgetSsid( const QString& ssid )
{
    if ( ssid.isEmpty() || m_connecting )
    {
        return;
    }
    const QStringList ids = uuidsForSsid( ssid );
    for ( const QString& id : ids )
    {
        run( QStringLiteral( "nmcli" ),
             { QStringLiteral( "connection" ),
               QStringLiteral( "delete" ),
               QStringLiteral( "uuid" ),
               id } );
    }
    refresh();
}

void
ModernNetNm::stopConnecting()
{
    const QString devices = run( QStringLiteral( "nmcli" ),
                                 { QStringLiteral( "-t" ),
                                   QStringLiteral( "-f" ),
                                   QStringLiteral( "DEVICE,TYPE,STATE" ),
                                   QStringLiteral( "device" ),
                                   QStringLiteral( "status" ) } );
    for ( const QString& line : devices.split( QLatin1Char( '\n' ), Qt::SkipEmptyParts ) )
    {
        const QStringList f = splitNmcli( line );
        if ( f.size() < 3 || f.at( 1 ) != QLatin1String( "wifi" ) )
        {
            continue;
        }
        const QString state = f.at( 2 );
        if ( state != QLatin1String( "connecting" ) && state != QLatin1String( "configuring" )
             && state != QLatin1String( "need-auth" ) )
        {
            continue;
        }
        run( QStringLiteral( "nmcli" ),
             { QStringLiteral( "device" ), QStringLiteral( "disconnect" ), f.at( 0 ) } );
    }
}

void
ModernNetNm::disconnectWifi()
{
    if ( m_connecting )
    {
        return;
    }
    const QString devices = run( QStringLiteral( "nmcli" ),
                                 { QStringLiteral( "-t" ),
                                   QStringLiteral( "-f" ),
                                   QStringLiteral( "DEVICE,TYPE,STATE" ),
                                   QStringLiteral( "device" ),
                                   QStringLiteral( "status" ) } );
    for ( const QString& line : devices.split( QLatin1Char( '\n' ), Qt::SkipEmptyParts ) )
    {
        const QStringList f = splitNmcli( line );
        if ( f.size() < 3 || f.at( 1 ) != QLatin1String( "wifi" )
             || f.at( 2 ) != QLatin1String( "connected" ) )
        {
            continue;
        }
        run( QStringLiteral( "nmcli" ),
             { QStringLiteral( "device" ), QStringLiteral( "disconnect" ), f.at( 0 ) } );
    }
    refresh();
}

void
ModernNetNm::settleJoin( int code )
{
    if ( m_joinSettled )
    {
        return;
    }
    m_joinSettled = true;
    m_connecting = false;
    // The script unlinks this as it reads it. A join that never got that
    // far must not leave the password in /run.
    ::unlink( "/run/modern/wifi-pass" );
    QProcess* proc = m_join;
    m_join = nullptr;
    if ( proc && proc->state() != QProcess::NotRunning )
    {
        groupKill( proc );
    }
    if ( proc )
    {
        proc->deleteLater();
    }
    // The hint changes before any further nmcli. refresh() used to run
    // first and, while the old client was still alive, never returned.
    if ( code != 0 )
    {
        emit connectFinished( false, code );
        QTimer::singleShot( 0, this, [ this ]() {
            stopConnecting();
            refresh();
        } );
        return;
    }
    QTimer::singleShot( 0, this, [ this ]() {
        refresh();
        const bool joined = m_wifiUp || m_hasRoute;
        emit connectFinished( joined, joined ? 0 : 5 );
    } );
}

void
ModernNetNm::connectSsid( const QString& ssid, const QString& password, const QString& security )
{
    if ( m_join || ssid.isEmpty() )
    {
        return;
    }
    m_connecting = true;
    m_joinSettled = false;
    // The list scan holds NetworkManager. Leaving it running makes the
    // password check wait until that scan ends, which on this screen is
    // indistinguishable from a hang. Kill the scan's nmcli too.
    groupKill( m_scan );
    emit changed();
    m_join = new QProcess( this );
    connect( m_join, &QProcess::readyReadStandardOutput, this, [ this ]() {
        const QString text = QString::fromUtf8( m_join->readAllStandardOutput() );
        const QStringList lines = text.split( QLatin1Char( '\n' ), Qt::SkipEmptyParts );
        for ( const QString& line : lines )
        {
            if ( line.startsWith( QLatin1String( "status:" ) ) )
            {
                emit joinProgress( line.mid( 7 ).trimmed() );
            }
        }
    } );
    connect( m_join, &QProcess::readyReadStandardError, this, [ this, password ]() {
        QByteArray chunk = m_join->readAllStandardError();
        if ( !password.isEmpty() )
        {
            chunk.replace( password.toUtf8(), "<redacted>" );
        }
        const QString text = QString::fromUtf8( chunk ).simplified();
        if ( !text.isEmpty() )
        {
            noteJoin( QStringLiteral( "calamares stderr %1" ).arg( text.left( 400 ) ) );
        }
    } );
    connect( m_join,
             QOverload< int, QProcess::ExitStatus >::of( &QProcess::finished ),
             this,
             [ this ]( int code, QProcess::ExitStatus status ) {
                 noteJoin( QStringLiteral( "calamares join exit %1" )
                               .arg( status == QProcess::NormalExit ? code : -1 ) );
                 settleJoin( status == QProcess::NormalExit ? code : 1 );
             } );
    connect( m_join, &QProcess::errorOccurred, this, [ this ]( QProcess::ProcessError error ) {
        if ( error == QProcess::FailedToStart )
        {
            noteJoin( QStringLiteral( "calamares join failed to start: %1" ).arg( m_join->errorString() ) );
            settleJoin( 1 );
        }
    } );
    // A wrong password or a client that never returns used to leave this
    // screen on "Checking the password…". The script has its own limits;
    // this one fires even when those do not, and it kills nmcli as well.
    auto* joinLimit = new QTimer( m_join );
    joinLimit->setSingleShot( true );
    connect( joinLimit, &QTimer::timeout, this, [ this ]() {
        settleJoin( 5 );
    } );
    joinLimit->start( 30000 );
    // The password is a 0600 file, with a second copy on stdin. argv is
    // readable by every process in /proc. wifi-join.sh also drops a
    // profile a failed password created.
    QStringList args { QStringLiteral( "connect" ), ssid };
    if ( !password.isEmpty() )
    {
        args << QStringLiteral( "-" );
    }
    const QString passFile = writePassFile( password );
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    bool customEnv = false;
    if ( !security.isEmpty() )
    {
        env.insert( QStringLiteral( "WIFI_JOIN_SECURITY" ), security );
        customEnv = true;
    }
    if ( !passFile.isEmpty() )
    {
        env.insert( QStringLiteral( "WIFI_JOIN_PASSFILE" ), passFile );
        customEnv = true;
    }
    if ( customEnv )
    {
        m_join->setProcessEnvironment( env );
    }
    noteJoin( QStringLiteral( "calamares join start passfile=%1" )
                  .arg( passFile.isEmpty() ? QStringLiteral( "no" ) : QStringLiteral( "yes" ) ) );
    connect( m_join, &QProcess::started, this, [ this, password ]() {
        if ( password.isEmpty() )
        {
            return;
        }
        m_join->write( password.toUtf8() + '\n' );
        m_join->closeWriteChannel();
    } );
    leadGroup( m_join );
    // bash reads the script. mkarchiso drops the execute bit on any
    // file that profiledef does not list, and QProcess then reports
    // that the script failed to start before it can read the password.
    m_join->setProgram( QStringLiteral( "/bin/bash" ) );
    m_join->setArguments( QStringList{ kWifiJoin } + args );
    m_join->start();
}
