#ifndef MODERNNETROW_H
#define MODERNNETROW_H

#include "ModernNetNm.h"

#include <QWidget>

class QEnterEvent;
class QEvent;
class QMouseEvent;
class QPushButton;

class ModernNetRow : public QWidget
{
    Q_OBJECT

public:
    explicit ModernNetRow( const ModernNetNm::Wifi& wifi, QWidget* parent = nullptr );
    QString ssid() const { return m_ssid; }

signals:
    void connectClicked();
    void forgetClicked();
    void disconnectClicked();

protected:
    void enterEvent( QEnterEvent* event ) override;
    void leaveEvent( QEvent* event ) override;
    void mouseReleaseEvent( QMouseEvent* event ) override;

private:
    QString m_ssid;
};

#endif
