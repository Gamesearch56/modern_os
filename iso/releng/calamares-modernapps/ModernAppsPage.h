#ifndef MODERNAPPSPAGE_H
#define MODERNAPPSPAGE_H

#include <QWidget>

class QListWidget;

class ModernAppsPage : public QWidget
{
    Q_OBJECT

public:
    explicit ModernAppsPage( QWidget* parent = nullptr );

    // Writes the package names the next step should remove.
    void save() const;

private:
    void addRow( const QString& package, const QString& title, const QString& detail, bool required, bool checked );
    QListWidget* m_list;
};

#endif
