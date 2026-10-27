#ifndef MODERNNETPAGE_H
#define MODERNNETPAGE_H

#include <QWidget>

class ModernNetNm;
class QLabel;
class QLineEdit;
class QListWidget;
class QProgressBar;
class QPushButton;
class QStackedWidget;

class ModernNetPage : public QWidget
{
    Q_OBJECT

public:
    explicit ModernNetPage( QWidget* parent = nullptr );
    bool isOnline() const { return m_online; }

public slots:
    void refresh();
    void scanWifi();

signals:
    void onlineChanged( bool online );

private slots:
    void syncUi();
    void connectWifi();
    void changeWifi();
    void onConnectFinished( bool ok );

private:
    void setOnline( bool on );
    void fillWifi();
    void showPassword( bool on );
    void ensureWifi();
    void showOkPage();
    void selectSsid( const QString& ssid );
    QString currentSsid() const;

    bool m_online = false;
    ModernNetNm* m_nm = nullptr;
    QStackedWidget* m_stack = nullptr;
    QWidget* m_okPage = nullptr;
    QWidget* m_wifiPage = nullptr;
    QLabel* m_okBadge = nullptr;
    QLabel* m_okTitle = nullptr;
    QLabel* m_okHint = nullptr;
    QPushButton* m_changeWifi = nullptr;
    QLabel* m_ethStatus = nullptr;
    QLabel* m_ethAddr = nullptr;
    QProgressBar* m_scanBar = nullptr;
    QPushButton* m_refresh = nullptr;
    QListWidget* m_list = nullptr;
    QWidget* m_passCard = nullptr;
    QLabel* m_passTitle = nullptr;
    QLineEdit* m_password = nullptr;
    QPushButton* m_connect = nullptr;
    QLabel* m_hint = nullptr;
};

#endif
