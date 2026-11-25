#include "ModernAppsPage.h"

#include "GlobalStorage.h"
#include "JobQueue.h"

#include <QDir>
#include <QFile>
#include <QLabel>
#include <QListWidget>
#include <QVBoxLayout>

namespace
{
constexpr int PackageRole = Qt::UserRole;
constexpr int RequiredRole = Qt::UserRole + 1;

// NVIDIA's PCI vendor id. The live image may not have lspci.
bool nvidiaCard()
{
    const QDir drm( QStringLiteral( "/sys/class/drm" ) );
    const auto cards = drm.entryList( { QStringLiteral( "card*" ) }, QDir::Dirs | QDir::NoDotAndDotDot );
    for ( const QString& card : cards )
    {
        QFile vendor( drm.filePath( card + QStringLiteral( "/device/vendor" ) ) );
        if ( !vendor.open( QIODevice::ReadOnly ) )
        {
            continue;
        }
        if ( QString::fromUtf8( vendor.readAll() ).trimmed() == QLatin1String( "0x10de" ) )
        {
            return true;
        }
    }
    return false;
}
}  // namespace

ModernAppsPage::ModernAppsPage( QWidget* parent )
    : QWidget( parent )
    , m_list( new QListWidget )
{
    auto* layout = new QVBoxLayout( this );
    auto* intro = new QLabel( tr( "Vivaldi is the browser and is installed with the system. Tick a program to download it during installation. An NVIDIA graphics card needs the proprietary driver." ) );
    intro->setWordWrap( true );
    layout->addWidget( intro );

    m_list->setSelectionMode( QAbstractItemView::NoSelection );
    layout->addWidget( m_list, 1 );

    addRow( QString(), tr( "Vivaldi" ), tr( "Default browser. This stays." ), true, true );
    addRow( QString(), tr( "Drivers" ), tr( "Open graphics and Wi-Fi firmware for this computer. These stay." ), true, true );
    addRow( QString(), tr( "Desktop" ), tr( "The session, sound and network. This stays." ), true, true );
    addRow( QStringLiteral( "nvidia-proprietary" ),
            tr( "NVIDIA driver" ),
            tr( "Proprietary driver. An NVIDIA graphics card needs this. It is downloaded during installation." ),
            false,
            nvidiaCard() );
    addRow( QStringLiteral( "steam" ),
            tr( "Steam" ),
            tr( "Game store. Downloaded during installation if ticked." ),
            false,
            false );
    addRow( QStringLiteral( "spotify-launcher" ),
            tr( "Spotify" ),
            tr( "Music. Downloaded during installation if ticked." ),
            false,
            false );
    addRow( QStringLiteral( "discord" ),
            tr( "Discord" ),
            tr( "Chat. Downloaded during installation if ticked." ),
            false,
            false );
    addRow( QStringLiteral( "proton-vpn-gtk-app" ),
            tr( "Proton VPN" ),
            tr( "VPN client. Downloaded during installation if ticked." ),
            false,
            false );

    connect( m_list, &QListWidget::itemChanged, this, []( QListWidgetItem* item ) {
        if ( item->data( RequiredRole ).toBool() && item->checkState() != Qt::Checked )
        {
            item->setCheckState( Qt::Checked );
        }
    } );
}

void
ModernAppsPage::addRow( const QString& package, const QString& title, const QString& detail, bool required, bool checked )
{
    auto* item = new QListWidgetItem( title + QStringLiteral( " — " ) + detail, m_list );
    item->setFlags( Qt::ItemIsEnabled | Qt::ItemIsUserCheckable );
    item->setCheckState( checked ? Qt::Checked : Qt::Unchecked );
    item->setData( PackageRole, package );
    item->setData( RequiredRole, required );
}

void
ModernAppsPage::save() const
{
    QStringList install;
    for ( int i = 0; i < m_list->count(); ++i )
    {
        const QListWidgetItem* item = m_list->item( i );
        if ( item->data( RequiredRole ).toBool() )
        {
            continue;
        }
        if ( item->checkState() == Qt::Checked )
        {
            install.append( item->data( PackageRole ).toString() );
        }
    }
    Calamares::JobQueue::instance()->globalStorage()->insert( QStringLiteral( "modernappsInstall" ), install );
}
