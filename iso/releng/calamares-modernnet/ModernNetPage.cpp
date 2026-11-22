#include "ModernNetPage.h"

#include "ModernNetNm.h"
#include "ModernNetRow.h"

#include <QAbstractItemView>
#include <QHBoxLayout>
#include <QSize>
#include <QIcon>
#include <QLabel>
#include <QLineEdit>
#include <QListWidget>
#include <QPixmap>
#include <QProgressBar>
#include <QPushButton>
#include <QStackedWidget>
#include <QTimer>
#include <QVBoxLayout>

ModernNetPage::ModernNetPage( QWidget* parent )
    : QWidget( parent )
    , m_nm( new ModernNetNm( this ) )
{
    setObjectName( QStringLiteral( "networkPage" ) );

    auto* root = new QVBoxLayout( this );
    root->setContentsMargins( 8, 8, 8, 8 );
    root->setSpacing( 0 );

    m_stack = new QStackedWidget;
    root->addWidget( m_stack, 1 );

    m_okPage = new QWidget;
    m_okPage->setObjectName( QStringLiteral( "networkOkPage" ) );
    auto* ok = new QVBoxLayout( m_okPage );
    ok->setContentsMargins( 24, 24, 24, 24 );
    ok->addStretch( 1 );
    m_okBadge = new QLabel;
    m_okBadge->setObjectName( QStringLiteral( "networkOkBadge" ) );
    m_okBadge->setAlignment( Qt::AlignCenter );
    m_okBadge->setFixedSize( 112, 112 );
    m_okTitle = new QLabel;
    m_okTitle->setObjectName( QStringLiteral( "networkOkTitle" ) );
    m_okTitle->setAlignment( Qt::AlignHCenter );
    m_okTitle->setWordWrap( true );
    m_okHint = new QLabel;
    m_okHint->setObjectName( QStringLiteral( "networkOkHint" ) );
    m_okHint->setAlignment( Qt::AlignHCenter );
    m_okHint->setWordWrap( true );
    ok->addWidget( m_okBadge, 0, Qt::AlignHCenter );
    ok->addSpacing( 24 );
    ok->addWidget( m_okTitle );
    ok->addSpacing( 8 );
    ok->addWidget( m_okHint );
    ok->addSpacing( 16 );
    m_changeWifi = new QPushButton( tr( "Choose another network" ) );
    m_changeWifi->setObjectName( QStringLiteral( "networkChangeWifi" ) );
    m_changeWifi->hide();
    connect( m_changeWifi, &QPushButton::clicked, this, &ModernNetPage::changeWifi );
    ok->addWidget( m_changeWifi, 0, Qt::AlignHCenter );
    ok->addStretch( 1 );
    m_stack->addWidget( m_okPage );

    m_wifiPage = new QWidget;
    m_wifiPage->setObjectName( QStringLiteral( "networkWifiPage" ) );
    auto* wifi = new QVBoxLayout( m_wifiPage );
    wifi->setContentsMargins( 8, 8, 8, 8 );
    wifi->setSpacing( 16 );

    auto* eth = new QWidget;
    eth->setObjectName( QStringLiteral( "networkEthRow" ) );
    auto* ethRow = new QHBoxLayout( eth );
    ethRow->setContentsMargins( 0, 0, 0, 0 );
    ethRow->setSpacing( 12 );
    auto* ethIcon = new QLabel;
    const QPixmap rowPx
        = QIcon::fromTheme( QStringLiteral( "network-wired" ) ).pixmap( 24, 24 );
    if ( rowPx.isNull() )
    {
        ethIcon->hide();
    }
    else
    {
        ethIcon->setPixmap( rowPx );
    }
    auto* ethCol = new QVBoxLayout;
    ethCol->setSpacing( 2 );
    ethCol->addWidget( new QLabel( tr( "Ethernet" ) ) );
    m_ethAddr = new QLabel;
    m_ethAddr->setObjectName( QStringLiteral( "networkHint" ) );
    ethCol->addWidget( m_ethAddr );
    m_ethStatus = new QLabel;
    m_ethStatus->setObjectName( QStringLiteral( "networkHint" ) );
    ethRow->addWidget( ethIcon );
    ethRow->addLayout( ethCol, 1 );
    ethRow->addWidget( m_ethStatus );
    wifi->addWidget( eth );

    auto* near = new QHBoxLayout;
    auto* nearTitle = new QLabel( tr( "Nearby networks" ) );
    nearTitle->setObjectName( QStringLiteral( "networkNearbyTitle" ) );
    near->addWidget( nearTitle, 1 );
    m_refresh = new QPushButton( tr( "Refresh" ) );
    m_refresh->setObjectName( QStringLiteral( "networkRefresh" ) );
    connect( m_refresh, &QPushButton::clicked, this, &ModernNetPage::scanWifi );
    near->addWidget( m_refresh );
    wifi->addLayout( near );

    m_scanBar = new QProgressBar;
    m_scanBar->setObjectName( QStringLiteral( "networkScanBar" ) );
    m_scanBar->setRange( 0, 0 );
    m_scanBar->setTextVisible( false );
    m_scanBar->hide();
    wifi->addWidget( m_scanBar );

    m_list = new QListWidget;
    m_list->setObjectName( QStringLiteral( "wifiList" ) );
    m_list->setSpacing( 4 );
    m_list->setSelectionMode( QAbstractItemView::NoSelection );
    m_list->setFocusPolicy( Qt::NoFocus );
    m_list->setHorizontalScrollBarPolicy( Qt::ScrollBarAlwaysOff );
    wifi->addWidget( m_list, 1 );

    m_passCard = new QWidget;
    m_passCard->setObjectName( QStringLiteral( "networkPasswordCard" ) );
    auto* passCol = new QVBoxLayout( m_passCard );
    passCol->setContentsMargins( 16, 12, 16, 12 );
    passCol->setSpacing( 12 );
    m_passTitle = new QLabel;
    m_password = new QLineEdit;
    m_password->setObjectName( QStringLiteral( "wifiPassword" ) );
    m_password->setEchoMode( QLineEdit::Password );
    m_password->setPlaceholderText( tr( "Password" ) );
    connect( m_password, &QLineEdit::returnPressed, this, &ModernNetPage::connectWifi );
    m_connect = new QPushButton( tr( "Connect" ) );
    m_connect->setObjectName( QStringLiteral( "networkConnect" ) );
    m_connect->setDefault( true );
    connect( m_connect, &QPushButton::clicked, this, &ModernNetPage::connectWifi );
    passCol->addWidget( m_passTitle );
    passCol->addWidget( m_password );
    passCol->addWidget( m_connect, 0, Qt::AlignRight );
    wifi->addWidget( m_passCard );

    m_hint = new QLabel;
    m_hint->setObjectName( QStringLiteral( "networkHint" ) );
    m_hint->setWordWrap( true );
    wifi->addWidget( m_hint );

    m_stack->addWidget( m_wifiPage );
    showPassword( false );

    connect( m_nm, &ModernNetNm::changed, this, &ModernNetPage::syncUi );
    connect( m_nm, &ModernNetNm::connectFinished, this, &ModernNetPage::onConnectFinished );
    connect( m_nm, &ModernNetNm::joinProgress, this, [ this ]( const QString& phase ) {
        const QString name = m_passTitle->text();
        if ( phase == QLatin1String( "lookup" ) )
        {
            m_hint->setText( tr( "Looking for %1…" ).arg( name ) );
        }
        else if ( phase == QLatin1String( "password" ) )
        {
            m_hint->setText( tr( "Checking the password…" ) );
        }
        else if ( phase == QLatin1String( "address" ) )
        {
            m_hint->setText( tr( "Waiting for an address from %1…" ).arg( name ) );
        }
    } );

    auto* tick = new QTimer( this );
    tick->setInterval( 2000 );
    connect( tick, &QTimer::timeout, this, &ModernNetPage::refresh );
    tick->start();
}

void
ModernNetPage::setOnline( bool on )
{
    if ( m_online == on )
    {
        return;
    }
    m_online = on;
    emit onlineChanged( on );
}

void
ModernNetPage::refresh()
{
    // A scan or a connect owns nmcli. Another list from this timer waits
    // on that scan, so the bar never clears.
    if ( m_nm->scanning() || m_nm->connecting() )
    {
        return;
    }
    m_nm->refresh();
}

void
ModernNetPage::ensureWifi()
{
    if ( m_nm->wifiRadio() )
    {
        return;
    }
    m_nm->setWifiRadio( true );
}

void
ModernNetPage::scanWifi()
{
    if ( m_nm->ethernetUp() || m_nm->connecting() )
    {
        return;
    }
    ensureWifi();
    m_nm->scan();
}

void
ModernNetPage::showOkPage()
{
    const bool eth = m_nm->ethernetUp();
    const QString iconName = eth ? QStringLiteral( "network-wired" )
                                 : QStringLiteral( "network-wireless" );
    const QPixmap px = QIcon::fromTheme( iconName ).pixmap( 56, 56 );
    if ( px.isNull() )
    {
        m_okBadge->setPixmap( QPixmap() );
        m_okBadge->setText( QStringLiteral( "✓" ) );
    }
    else
    {
        m_okBadge->setText( QString() );
        m_okBadge->setPixmap( px );
    }
    m_okTitle->setText( eth ? tr( "You're connected with Ethernet" )
                            : tr( "You're connected with Wi-Fi" ) );
    m_okHint->setText( tr( "You can continue to the next step." ) );
    m_changeWifi->setVisible( m_nm->wifiUp() && !m_nm->ethernetUp() );
    showPassword( false );
    m_stack->setCurrentWidget( m_okPage );
}

void
ModernNetPage::changeWifi()
{
    m_nm->disconnectWifi();
}

void
ModernNetPage::syncUi()
{
    setOnline( m_nm->online() );
    if ( m_nm->ethernetUp() || m_nm->wifiUp() )
    {
        showOkPage();
        return;
    }

    ensureWifi();
    m_ethStatus->setText( tr( "Not connected" ) );
    m_ethAddr->setText( m_nm->ethernetAddr() );
    m_ethAddr->setVisible( !m_nm->ethernetAddr().isEmpty() );
    m_scanBar->setVisible( m_nm->scanning() || m_nm->connecting() );
    m_refresh->setEnabled( !m_nm->scanning() && !m_nm->connecting() );
    m_connect->setEnabled( !m_nm->connecting() );
    fillWifi();
    if ( m_nm->connecting() )
    {
        // joinProgress writes the sentence while a password is being tried.
    }
    else if ( m_passCard->isVisible() )
    {
        // onConnectFinished wrote why the attempt stopped. A refresh in
        // the same moment must not put "Pick a network" back over it.
    }
    else if ( m_nm->scanning() )
    {
        m_hint->setText( tr( "Looking for networks…" ) );
    }
    else if ( m_nm->networks().isEmpty() )
    {
        m_hint->setText( emptyHint() );
    }
    else
    {
        m_hint->setText( tr( "Pick a network to get online." ) );
    }
    m_stack->setCurrentWidget( m_wifiPage );
    if ( !m_askedScan && m_nm->networks().isEmpty() && !m_nm->scanning() )
    {
        m_askedScan = true;
        scanWifi();
    }
}

QString
ModernNetPage::emptyHint() const
{
    const QString state = m_nm->wifiState();
    const QString wired = tr( "Connect an Ethernet cable or share your phone's connection over USB." );
    if ( state == QLatin1String( "blocked" ) )
    {
        return tr( "Wi-Fi is turned off with a switch or key on this computer. "
                   "Turn it on, then choose Refresh." );
    }
    if ( state.startsWith( QLatin1String( "nodriver" ) ) )
    {
        return tr( "This computer's Wi-Fi chip (%1) has no driver in the installer. %2" )
            .arg( state.section( QLatin1Char( ' ' ), 1, 1 ), wired );
    }
    if ( state == QLatin1String( "none" ) )
    {
        return tr( "No Wi-Fi adapter was found. %1" ).arg( wired );
    }
    return tr( "No networks showed up. Move closer to the router, then tap Refresh." );
}

QString
ModernNetPage::currentSsid() const
{
    auto* item = m_list->currentItem();
    return item ? item->data( Qt::UserRole ).toString() : QString();
}

void
ModernNetPage::selectSsid( const QString& ssid )
{
    if ( ssid.isEmpty() )
    {
        return;
    }
    for ( int i = 0; i < m_list->count(); i++ )
    {
        auto* item = m_list->item( i );
        if ( item && item->data( Qt::UserRole ).toString() == ssid )
        {
            m_list->setCurrentItem( item );
            return;
        }
    }
}

void
ModernNetPage::fillWifi()
{
    const QString selected = currentSsid();
    const bool keepPass = m_passCard->isVisible();
    const QString passSsid = m_passTitle->text();
    const QString passText = m_password->text();
    m_list->clear();
    const auto nets = m_nm->networks();
    if ( nets.isEmpty() )
    {
        auto* empty = new QListWidgetItem(
            m_nm->scanning() ? tr( "Looking for networks…" ) : tr( "No networks found." ) );
        empty->setFlags( Qt::NoItemFlags );
        m_list->addItem( empty );
        if ( !keepPass )
        {
            showPassword( false );
        }
        return;
    }
    for ( const auto& w : nets )
    {
        auto* item = new QListWidgetItem;
        item->setData( Qt::UserRole, w.ssid );
        item->setData( Qt::UserRole + 1, QVariant( w.locked && !w.inUse ) );
        item->setData( Qt::UserRole + 2, QVariant( w.inUse ) );
        item->setData( Qt::UserRole + 3, QVariant( w.known ) );
        item->setData( Qt::UserRole + 4, w.security );
        auto* row = new ModernNetRow( w );
        connect( row, &ModernNetRow::connectClicked, this, [ this, ssid = w.ssid ]() {
            selectSsid( ssid );
            connectWifi();
        } );
        connect( row, &ModernNetRow::forgetClicked, this, [ this, ssid = w.ssid ]() {
            m_nm->forgetSsid( ssid );
        } );
        connect( row, &ModernNetRow::disconnectClicked, this, [ this ]() {
            m_nm->disconnectWifi();
        } );
        m_list->addItem( item );
        m_list->setItemWidget( item, row );
        const int wide = qMax( 1, m_list->viewport()->width() );
        row->setMinimumWidth( wide );
        item->setSizeHint( QSize( wide, row->sizeHint().height() ) );
        if ( w.ssid == selected || w.ssid == passSsid || w.inUse )
        {
            m_list->setCurrentItem( item );
        }
    }
    if ( keepPass && !passSsid.isEmpty() )
    {
        selectSsid( passSsid );
        m_passTitle->setText( passSsid );
        m_passCard->setVisible( true );
        m_password->setText( passText );
        return;
    }
    if ( !m_list->currentItem() || m_list->currentItem()->data( Qt::UserRole + 2 ).toBool() )
    {
        showPassword( false );
    }
}

void
ModernNetPage::showPassword( bool on )
{
    m_passCard->setVisible( on );
    if ( !on )
    {
        m_password->clear();
        m_passTitle->clear();
    }
}

void
ModernNetPage::connectWifi()
{
    auto* item = m_list->currentItem();
    if ( !item || m_nm->connecting() )
    {
        return;
    }
    const QString ssid = item->data( Qt::UserRole ).toString();
    if ( ssid.isEmpty() )
    {
        return;
    }
    const bool locked = item->data( Qt::UserRole + 1 ).toBool();
    const bool known = item->data( Qt::UserRole + 3 ).toBool();
    if ( item->data( Qt::UserRole + 2 ).toBool() )
    {
        showPassword( false );
        return;
    }
    if ( locked && !known && !m_passCard->isVisible() )
    {
        m_passTitle->setText( ssid );
        showPassword( true );
        m_password->setFocus();
        return;
    }
    if ( locked && !known && m_passCard->isVisible() && m_password->text().isEmpty() )
    {
        m_hint->setText( tr( "Enter the password to connect." ) );
        m_password->setFocus();
        return;
    }
    const QString password = m_passCard->isVisible() ? m_password->text() : QString();
    const QString security = item->data( Qt::UserRole + 4 ).toString();
    m_connect->setEnabled( false );
    m_refresh->setEnabled( false );
    m_hint->setText( tr( "Looking for %1…" ).arg( ssid ) );
    m_nm->connectSsid( ssid, password, security );
}

void
ModernNetPage::onConnectFinished( bool ok, int code )
{
    m_connect->setEnabled( true );
    m_refresh->setEnabled( true );
    if ( ok )
    {
        showPassword( false );
        return;
    }
    QString hint;
    bool again = false;
    switch ( code )
    {
    case 4:
        hint = tr( "Can't see that network from here. Move closer, then tap Refresh." );
        break;
    case 6:
        hint = tr( "This network needs a sign-in the installer cannot enter. Choose another network." );
        break;
    case 5:
        hint = tr( "The router didn't answer. You can try again." );
        again = true;
        break;
    case 3:
        hint = tr( "That password didn't work. Type it again." );
        again = true;
        break;
    default:
        hint = tr( "Couldn't join. Check the password and try again." );
        again = true;
        break;
    }
    m_hint->setText( hint );
    auto* item = m_list->currentItem();
    if ( again && item && item->data( Qt::UserRole + 1 ).toBool() )
    {
        m_passTitle->setText( currentSsid() );
        showPassword( true );
        m_password->clear();
        m_password->setFocus();
    }
}
