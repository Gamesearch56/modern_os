#include "ModernNetRow.h"

#include <QHBoxLayout>
#include <QIcon>
#include <QLabel>
#include <QMouseEvent>
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
    // The list item's own padding left the button high and against the
    // scrollbar. The row owns its insets, with room for that bar.
    row->setContentsMargins( 12, 6, 28, 6 );
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
    // A stylesheet on the window does not reach a button inside the list,
    // so the label stayed dark on the dark row. White is set on the button.
    const auto pin = []( QPushButton* button ) {
        button->setStyleSheet( QStringLiteral( "color: #ffffff; background: transparent; border: none;" ) );
        button->setFixedWidth( button->sizeHint().width() );
        button->setSizePolicy( QSizePolicy::Fixed, QSizePolicy::Fixed );
    };
    // AlignVCenter on the row is not enough: the item is taller than the
    // button and Qt keeps the button at the top of that item.
    const auto place = [ &row, &pin ]( QPushButton* button ) {
        pin( button );
        auto* box = new QWidget;
        box->setStyleSheet( QStringLiteral( "background: transparent;" ) );
        auto* col = new QVBoxLayout( box );
        col->setContentsMargins( 0, 0, 0, 0 );
        col->setSpacing( 0 );
        col->addStretch();
        col->addWidget( button, 0, Qt::AlignRight );
        col->addStretch();
        row->addWidget( box, 0 );
    };

    if ( wifi.inUse )
    {
        auto* btn = new QPushButton( tr( "Disconnect" ) );
        btn->setObjectName( QStringLiteral( "networkRowDisconnect" ) );
        btn->setCursor( Qt::PointingHandCursor );
        connect( btn, &QPushButton::clicked, this, &ModernNetRow::disconnectClicked );
        place( btn );
        return;
    }
    if ( wifi.known )
    {
        auto* forget = new QPushButton( tr( "Forget" ) );
        forget->setObjectName( QStringLiteral( "networkRowForget" ) );
        forget->setCursor( Qt::PointingHandCursor );
        connect( forget, &QPushButton::clicked, this, &ModernNetRow::forgetClicked );
        place( forget );
    }
    auto* btn = new QPushButton( tr( "Connect" ) );
    btn->setObjectName( QStringLiteral( "networkRowConnect" ) );
    btn->setCursor( Qt::PointingHandCursor );
    connect( btn, &QPushButton::clicked, this, &ModernNetRow::connectClicked );
    place( btn );
    setCursor( Qt::PointingHandCursor );
}

void
ModernNetRow::mouseReleaseEvent( QMouseEvent* event )
{
    // The row itself chooses the network. The button already does, and
    // must not do it twice.
    if ( !qobject_cast< QPushButton* >( childAt( event->position().toPoint() ) ) )
    {
        emit connectClicked();
    }
    QWidget::mouseReleaseEvent( event );
}
