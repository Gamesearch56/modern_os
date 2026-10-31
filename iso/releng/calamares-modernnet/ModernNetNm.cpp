#include "ModernNetNm.h"

#include <QProcess>
#include <QSet>

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
    if ( !p.waitForFinished( timeoutMs ) )
    {
        p.kill();
        p.waitForFinished( 1000 );
        return {};
    }
    return QString::fromUtf8( p.readAllStandardOutput() );
}

QVector< QPair< QString, QString > >
ModernNetNm::wirelessProfiles() const
{
    QVector< QPair< QString, QString > > out;
    const QString text = run( QStringLiteral( "nmcli" ),
                              { QStringLiteral( "-t" ),
                                QStringLiteral( "-f" ),
                                QStringLiteral( "UUID,TYPE" ),
                                QStringLiteral( "connection" ),
                                QStringLiteral( "show" ) } );
    for ( const QString& line : text.split( QLatin1Char( '\n' ), Qt::SkipEmptyParts ) )
    {
        const QStringList f = splitNmcli( line );
        if ( f.size() < 2 || f.at( 1 ) != QLatin1String( "802-11-wireless" ) )
        {
            continue;
        }
        const QString ssid = run( QStringLiteral( "nmcli" ),
                                  { QStringLiteral( "-g" ),
                                    QStringLiteral( "802-11-wireless.ssid" ),
                                    QStringLiteral( "connection" ),
                                    QStringLiteral( "show" ),
                                    f.at( 0 ) } )
                                  .trimmed();
        if ( !ssid.isEmpty() )
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
    const QString wifi = run( QStringLiteral( "nmcli" ),
                              { QStringLiteral( "-t" ),
                                QStringLiteral( "-f" ),
                                QStringLiteral( "IN-USE,SSID,SECURITY,SIGNAL" ),
                                QStringLiteral( "device" ),
                                QStringLiteral( "wifi" ),
                                QStringLiteral( "list" ) } );
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
        const bool up = state == QLatin1String( "connected" );
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
    connect( m_scan,
             QOverload< int, QProcess::ExitStatus >::of( &QProcess::finished ),
             this,
             [ this ]() {
                 m_scan->deleteLater();
                 m_scan = nullptr;
                 m_scanning = false;
                 refresh();
             } );
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
ModernNetNm::connectSsid( const QString& ssid, const QString& password )
{
    if ( m_join || ssid.isEmpty() )
    {
        return;
    }
    m_joinSsid = ssid;
    m_joinPassword = password;
    QStringList args;
    if ( !password.isEmpty() )
    {
        const QStringList ids = uuidsForSsid( ssid );
        for ( const QString& id : ids )
        {
            run( QStringLiteral( "nmcli" ),
                 { QStringLiteral( "connection" ),
                   QStringLiteral( "delete" ),
                   QStringLiteral( "uuid" ),
                   id } );
        }
        args = { QStringLiteral( "-w" ),
                 QStringLiteral( "25" ),
                 QStringLiteral( "device" ),
                 QStringLiteral( "wifi" ),
                 QStringLiteral( "connect" ),
                 ssid,
                 QStringLiteral( "password" ),
                 password };
    }
    else
    {
        const QStringList ids = uuidsForSsid( ssid );
        if ( ids.isEmpty() )
        {
            args = { QStringLiteral( "-w" ),
                     QStringLiteral( "25" ),
                     QStringLiteral( "device" ),
                     QStringLiteral( "wifi" ),
                     QStringLiteral( "connect" ),
                     ssid };
        }
        else
        {
            args = { QStringLiteral( "-w" ),
                     QStringLiteral( "25" ),
                     QStringLiteral( "connection" ),
                     QStringLiteral( "up" ),
                     QStringLiteral( "uuid" ),
                     ids.first() };
        }
    }
    m_connecting = true;
    emit changed();
    m_join = new QProcess( this );
    connect( m_join,
             QOverload< int, QProcess::ExitStatus >::of( &QProcess::finished ),
             this,
             [ this ]( int code, QProcess::ExitStatus status ) {
                 const bool ok = status == QProcess::NormalExit && code == 0;
                 const QString ssid = m_joinSsid;
                 const QString password = m_joinPassword;
                 m_join->deleteLater();
                 m_join = nullptr;
                 m_connecting = false;
                 m_joinSsid.clear();
                 m_joinPassword.clear();
                 if ( !ok && !password.isEmpty() )
                 {
                     const QStringList ids = uuidsForSsid( ssid );
                     for ( const QString& id : ids )
                     {
                         run( QStringLiteral( "nmcli" ),
                              { QStringLiteral( "connection" ),
                                QStringLiteral( "delete" ),
                                QStringLiteral( "uuid" ),
                                id } );
                     }
                 }
                 refresh();
                 emit connectFinished( ok && m_wifiUp );
             } );
    m_join->start( QStringLiteral( "nmcli" ), args );
}
