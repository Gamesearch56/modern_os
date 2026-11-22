#include "ModernNetRow.h"

#include <QHBoxLayout>
#include <QIcon>
#include <QLabel>
#include <QPixmap>
#include <QPushButton>
#include <QSizePolicy>
#include <QVBoxLayout>

ModernNetRow::ModernNetRow( const ModernNetNm::Wifi& wifi, QWidget* parent )
    : QWidget( parent )
    , m_ssid( wifi.ssid )
{
    setObjectName( QStringLiteral( "networkWifiRow" ) );
    auto* row = new QHBoxLayout( this );
    // The name must be allowed to shrink. Its minimum width otherwise
    // pushes Connect past the row and the list clips the button.
    setSizePolicy( QSizePolicy::Expanding, QSizePolicy::Preferred );
    row->setContentsMargins( 8, 4, 12, 4 );
    row->setSpacing( 8 );

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
    title->setMinimumWidth( 0 );
    title->setSizePolicy( QSizePolicy::Ignored, QSizePolicy::Preferred );
    QString status;
    if ( wifi.inUse )
    {
        status = tr( "Connected" );
    }
    else if ( wifi.known )
    {
        status = tr( "Saved" );
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
    sub->setMinimumWidth( 0 );
    sub->setSizePolicy( QSizePolicy::Ignored, QSizePolicy::Preferred );
    col->addWidget( title );
    col->addWidget( sub );
    row->addLayout( col, 1 );

    // A click must not change the button's width. A narrower pressed
    // style otherwise slides the button toward the name.
    const auto pin = []( QPushButton* button ) {
        button->setFixedWidth( button->sizeHint().width() );
        button->setSizePolicy( QSizePolicy::Fixed, QSizePolicy::Fixed );
    };

    if ( wifi.inUse )
    {
        auto* btn = new QPushButton( tr( "Disconnect" ) );
        btn->setObjectName( QStringLiteral( "networkRowDisconnect" ) );
        btn->setCursor( Qt::PointingHandCursor );
        connect( btn, &QPushButton::clicked, this, &ModernNetRow::disconnectClicked );
        pin( btn );
        row->addWidget( btn, 0, Qt::AlignRight | Qt::AlignVCenter );
        return;
    }
    if ( wifi.known )
    {
        auto* forget = new QPushButton( tr( "Forget" ) );
        forget->setObjectName( QStringLiteral( "networkRowForget" ) );
        forget->setCursor( Qt::PointingHandCursor );
        connect( forget, &QPushButton::clicked, this, &ModernNetRow::forgetClicked );
        pin( forget );
        row->addWidget( forget, 0, Qt::AlignRight | Qt::AlignVCenter );
    }
    auto* btn = new QPushButton( tr( "Connect" ) );
    btn->setObjectName( QStringLiteral( "networkRowConnect" ) );
    btn->setCursor( Qt::PointingHandCursor );
    connect( btn, &QPushButton::clicked, this, &ModernNetRow::connectClicked );
    pin( btn );
    row->addWidget( btn, 0, Qt::AlignRight | Qt::AlignVCenter );
}
