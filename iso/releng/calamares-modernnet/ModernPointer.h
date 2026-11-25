#ifndef MODERNPOINTER_H
#define MODERNPOINTER_H

#include <QObject>

class QWidget;

// Pointing-hand cursor on every enabled button and combo box in the
// installer. A stylesheet cannot set a cursor, and most buttons belong
// to Calamares itself, so one application-wide filter covers them all.
class ModernPointer : public QObject
{
    Q_OBJECT

public:
    static void install();

protected:
    bool eventFilter( QObject* watched, QEvent* event ) override;

private:
    explicit ModernPointer( QObject* parent );
    static void apply( QWidget* widget );
};

#endif
