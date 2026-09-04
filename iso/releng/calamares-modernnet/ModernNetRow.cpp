#include "ModernNetRow.h"

#include <QHBoxLayout>
#include <QIcon>
#include <QLabel>
#include <QPixmap>
#include <QPushButton>
#include <QVBoxLayout>

ModernNetRow::ModernNetRow( const ModernNetNm::Wifi& wifi, QWidget* parent )
    : QWidget( parent )
    , m_ssid( wifi.ssid )
{
    setObjectName( QStringLiteral( "networkWifiRow" ) );
    auto* row = new QHBoxLayout( this );
    row->setContentsMargins( 8, 6, 8, 6 );
    row->setSpacing( 12 );

    auto* icon = new QLabel;
    const QString name = wifi.locked ? QStringLiteral( "network-wireless-encrypted" )
                                     : QStringLiteral( "network-wireless" );
    const QPixmap px = QIcon::fromTheme( name ).pixmap( 24, 24 );
    if ( px.isNull() )
    {
        icon->hide();
    }
    else
    {
        icon->setPixmap( px );
    }
    row->addWidget( icon, 0, Qt::AlignVCenter );

    auto* col = new QVBoxLayout;
    col->setSpacing( 2 );
    auto* title = new QLabel( wifi.ssid );
    title->setObjectName( QStringLiteral( "networkWifiSsid" ) );
    QString status;
    if ( wifi.inUse )
    {
        status = tr( "Connected" );
    }
    else if ( wifi.locked )
    {
        status = tr( "Password required" );
    }
    else
    {
        status = tr( "Open network" );
    }
    auto* sub = new QLabel( status );
    sub->setObjectName( wifi.locked && !wifi.inUse ? QStringLiteral( "networkWifiLocked" )
                                                   : QStringLiteral( "networkHint" ) );
    col->addWidget( title );
    col->addWidget( sub );
    row->addLayout( col, 1 );

    if ( !wifi.inUse )
    {
        auto* btn = new QPushButton( tr( "Connect" ) );
        btn->setObjectName( QStringLiteral( "networkRowConnect" ) );
        btn->setCursor( Qt::PointingHandCursor );
        connect( btn, &QPushButton::clicked, this, &ModernNetRow::connectClicked );
        row->addWidget( btn, 0, Qt::AlignVCenter );
    }
}
