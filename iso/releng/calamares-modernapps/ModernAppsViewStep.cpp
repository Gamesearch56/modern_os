#include "ModernAppsViewStep.h"

#include "ModernAppsPage.h"

CALAMARES_PLUGIN_FACTORY_DEFINITION( ModernAppsViewStepFactory,
                                     registerPlugin< ModernAppsViewStep >(); )

ModernAppsViewStep::ModernAppsViewStep( QObject* parent )
    : Calamares::ViewStep( parent )
    , m_widget( new ModernAppsPage )
{
}

ModernAppsViewStep::~ModernAppsViewStep()
{
    if ( m_widget && m_widget->parent() == nullptr )
    {
        m_widget->deleteLater();
    }
}

QString
ModernAppsViewStep::prettyName() const
{
    return tr( "Programs", "@title" );
}

QWidget*
ModernAppsViewStep::widget()
{
    return m_widget;
}

bool
ModernAppsViewStep::isNextEnabled() const
{
    return true;
}

bool
ModernAppsViewStep::isBackEnabled() const
{
    return true;
}

bool
ModernAppsViewStep::isAtBeginning() const
{
    return true;
}

bool
ModernAppsViewStep::isAtEnd() const
{
    return true;
}

Calamares::JobList
ModernAppsViewStep::jobs() const
{
    return Calamares::JobList();
}

void
ModernAppsViewStep::onLeave()
{
    m_widget->save();
}
