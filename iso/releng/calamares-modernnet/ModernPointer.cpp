#include "ModernPointer.h"

#include <QAbstractButton>
#include <QApplication>
#include <QComboBox>
#include <QEvent>
#include <QWidget>

ModernPointer::ModernPointer( QObject* parent )
    : QObject( parent )
{
}

void
ModernPointer::install()
{
    if ( !qApp || qApp->findChild< ModernPointer* >( QString(), Qt::FindDirectChildrenOnly ) )
    {
        return;
    }
    qApp->installEventFilter( new ModernPointer( qApp ) );
    // The window and its navigation buttons can exist before this module loads.
    const auto widgets = QApplication::allWidgets();
    for ( QWidget* w : widgets )
    {
        apply( w );
    }
}

bool
ModernPointer::eventFilter( QObject* watched, QEvent* event )
{
    if ( event->type() == QEvent::Polish )
    {
        apply( qobject_cast< QWidget* >( watched ) );
    }
    return QObject::eventFilter( watched, event );
}

void
ModernPointer::apply( QWidget* widget )
{
    if ( !widget || !( qobject_cast< QAbstractButton* >( widget ) || qobject_cast< QComboBox* >( widget ) ) )
    {
        return;
    }
    // A widget that chose its own cursor keeps it. A disabled one shows
    // its parent's cursor; Qt clears the widget's own while disabled.
    if ( widget->testAttribute( Qt::WA_SetCursor ) )
    {
        return;
    }
    widget->setCursor( Qt::PointingHandCursor );
}
