#ifndef MODERNNETNM_H
#define MODERNNETNM_H

#include <QObject>
#include <QPair>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QVector>

class QProcess;

class ModernNetNm : public QObject
{
    Q_OBJECT
public:
    struct Wifi
    {
        QString ssid;
        QString security;
        int signal = 0;
        bool inUse = false;
        bool known = false;
        bool locked = false;
    };

    explicit ModernNetNm( QObject* parent = nullptr );

    bool ethernetUp() const { return m_ethernetUp; }
    bool wifiUp() const { return m_wifiUp; }
    bool wifiRadio() const { return m_wifiRadio; }
    bool scanning() const { return m_scanning; }
    bool connecting() const { return m_connecting; }
    bool online() const { return m_hasRoute || m_ethernetUp || m_wifiUp; }
    QString ethernetAddr() const { return m_ethernetAddr; }
    QString wifiSsid() const { return m_wifiSsid; }
    // live-wifi-up.sh: ok, off, blocked, "nodriver <vendor:device>", none.
    QString wifiState() const { return m_wifiState; }
    QVector< Wifi > networks() const { return m_networks; }

    void refresh();
    void scan();
    void setWifiRadio( bool on );
    void connectSsid( const QString& ssid, const QString& password );
    void forgetSsid( const QString& ssid );
    void disconnectWifi();

signals:
    void changed();
    void connectFinished( bool ok );

private:
    static QStringList splitNmcli( const QString& line );
    static QString run( const QString& bin, const QStringList& args, int timeoutMs = 8000 );
    QVector< QPair< QString, QString > > wirelessProfiles() const;
    QSet< QString > knownWifi() const;
    QStringList uuidsForSsid( const QString& ssid ) const;
    void loadWifi( const QSet< QString >& known );

    bool m_ethernetUp = false;
    bool m_wifiUp = false;
    bool m_wifiRadio = false;
    bool m_hasRoute = false;
    bool m_scanning = false;
    bool m_connecting = false;
    QString m_ethernetAddr;
    QString m_wifiSsid;
    QString m_wifiState;
    QString m_joinSsid;
    QString m_joinPassword;
    QVector< Wifi > m_networks;
    QProcess* m_scan = nullptr;
    QProcess* m_join = nullptr;
};

#endif
