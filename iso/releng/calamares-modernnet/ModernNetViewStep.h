#ifndef MODERNNETVIEWSTEP_H
#define MODERNNETVIEWSTEP_H

#include "DllMacro.h"
#include "utils/PluginFactory.h"
#include "viewpages/ViewStep.h"

class ModernNetPage;

class PLUGINDLLEXPORT ModernNetViewStep : public Calamares::ViewStep
{
    Q_OBJECT

public:
    explicit ModernNetViewStep( QObject* parent = nullptr );
    ~ModernNetViewStep() override;

    QString prettyName() const override;
    QWidget* widget() override;
    bool isNextEnabled() const override;
    bool isBackEnabled() const override;
    bool isAtBeginning() const override;
    bool isAtEnd() const override;
    Calamares::JobList jobs() const override;
    void onActivate() override;

private:
    ModernNetPage* m_widget;
};

CALAMARES_PLUGIN_FACTORY_DECLARATION( ModernNetViewStepFactory )

#endif
