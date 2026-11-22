#include "ModernNetViewStep.h"

#include "ModernNetPage.h"
#include "ModernPointer.h"

CALAMARES_PLUGIN_FACTORY_DEFINITION( ModernNetViewStepFactory,
                                     registerPlugin< ModernNetViewStep >(); )

ModernNetViewStep::ModernNetViewStep( QObject* parent )
    : Calamares::ViewStep( parent )
    , m_widget( new ModernNetPage )
{
    ModernPointer::install();
    connect( m_widget, &ModernNetPage::onlineChanged, this, [ this ]( bool on ) {
        Q_UNUSED( on )
        emit nextStatusChanged( isNextEnabled() );
    } );
    m_widget->refresh();
}

ModernNetViewStep::~ModernNetViewStep()
{
    if ( m_widget && m_widget->parent() == nullptr )
    {
        m_widget->deleteLater();
    }
}

QString
ModernNetViewStep::prettyName() const
{
    return tr( "Network", "@title" );
}

QWidget*
ModernNetViewStep::widget()
{
    return m_widget;
}

bool
ModernNetViewStep::isNextEnabled() const
{
    return m_widget->isOnline();
}

bool
ModernNetViewStep::isBackEnabled() const
{
    return true;
}

bool
ModernNetViewStep::isAtBeginning() const
{
    return true;
}

bool
ModernNetViewStep::isAtEnd() const
{
    return true;
}

Calamares::JobList
ModernNetViewStep::jobs() const
{
    return Calamares::JobList();
}

void
ModernNetViewStep::onActivate()
{
    m_widget->refresh();
    m_widget->scanWifi();
}
