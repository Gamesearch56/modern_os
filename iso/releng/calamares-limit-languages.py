#!/usr/bin/env python3
"""Patch Calamares for the live ISO.

Welcome languages, the locale per timezone country, the keyboard layout per
locale and every translated string come from installer-locales.json (next
to this file), which scripts/installer-locales.py generates from
languages.json. Nothing here names a language, so adding one never needs an
edit to this file; a language Calamares does not compile stops the build.
Also: 180px sidebar, stacked zone, hide Location Change…, qApp QSS,
in-window combo list overlay, Summary/partition
object names, hide Keyboard model, hide Cancel during exec,
ViewManager/QML retranslate, Toggle log tr(), Users step titled User,
Summary title() calls tr() so it follows the Welcome language.
Partition legend Boot/root names use palette text (not Qt::black).
Finished success copy drops the live-session offer.
Keyboard layout changes call apply() even when there are no variants.
setxkbmap always passes -option so cage/Xwayland rebuilds the map.
Unattended QEMU: /etc/calamares/unattended auto-next + user modern/modern.
Copies calamares-modernnet/ into src/modules/modernnet (Network step).

Pass TranslationsModel.cpp (AUR prepare) or the unpacked source tree.
"""
from __future__ import annotations

import json
import re
import shutil
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

TRANS_OLD = """TranslationsModel*
availableTranslations()
{
    static TranslationsModel* model = new TranslationsModel( availableLanguageList );
    return model;
}"""

SIDE_OLD = (
    "qBound( 100, Calamares::defaultFontHeight() * 12, "
    "w < windowPreferredWidth ? 100 : 190 )"
)
SIDE_NEW = "qBound( 180, 180, 180 )"

LOCALE_OLD = "    QBoxLayout* zoneAndRegionLayout = new QHBoxLayout;"
LOCALE_NEW = "    QBoxLayout* zoneAndRegionLayout = new QVBoxLayout;"

CHANGE_OLD = """    connect( m_localeChangeButton, &QPushButton::clicked, this, &LocalePage::changeLocale );
    connect( m_formatsChangeButton, &QPushButton::clicked, this, &LocalePage::changeFormats );"""
CHANGE_NEW = """    m_localeChangeButton->hide();
    m_formatsChangeButton->hide();
    connect( m_localeChangeButton, &QPushButton::clicked, this, &LocalePage::changeLocale );
    connect( m_formatsChangeButton, &QPushButton::clicked, this, &LocalePage::changeFormats );"""

STYLE_OLD = "    setStyleSheet( Calamares::Branding::instance()->stylesheet() );"
STYLE_NEW = """    {
        const QString ss = Calamares::Branding::instance()->stylesheet();
        setStyleSheet( ss );
        qApp->setStyleSheet( ss );
    }"""

COMBO_INC_OLD = """#include <QTreeView>

#include <algorithm>"""
COMBO_INC_NEW = """#include <QTreeView>
#include <QComboBox>
#include <QEvent>
#include <QKeyEvent>
#include <QListView>
#include <QPointer>
#include <QTimer>

#include <algorithm>

namespace
{
// cage ignores the X11 ConfigureWindow that Qt sends for a Qt::Popup on
// Xwayland, so a native combo list always maps at the screen origin however
// often it is moved. The list is drawn as an ordinary child of the installer
// window instead, positioned in the window's coordinate space, and the combo's
// own popup is suppressed before Qt ever builds it. The combo's internal view
// stays untouched: reparenting it out of QComboBoxPrivateContainer, and
// building the overlay before a combo is ever used, is what made the first
// in-window attempt SIGSEGV on start.
class ComboOverlay : public QObject
{
public:
    using QObject::QObject;

    bool eventFilter( QObject* obj, QEvent* ev ) override
    {
        const QEvent::Type type = ev->type();
        if ( type == QEvent::Show
             && QLatin1String( obj->metaObject()->className() )
                 == QLatin1String( "QComboBoxPrivateContainer" ) )
        {
            adoptNativePopup( qobject_cast< QWidget* >( obj ) );
            return false;
        }
        auto* widget = qobject_cast< QWidget* >( obj );
        if ( !widget )
        {
            return false;
        }
        if ( m_view && ( widget == m_view || m_view->isAncestorOf( widget ) ) )
        {
            if ( type == QEvent::KeyPress
                 && static_cast< QKeyEvent* >( ev )->key() == Qt::Key_Escape )
            {
                dismiss();
                return true;
            }
            return false;
        }
        auto* combo = qobject_cast< QComboBox* >( widget );
        if ( !combo )
        {
            if ( type == QEvent::MouseButtonPress )
            {
                dismiss();
            }
            return false;
        }
        switch ( type )
        {
        case QEvent::MouseButtonPress:
        case QEvent::MouseButtonDblClick:
        {
            const bool toggling = isOpenFor( combo );
            dismiss();
            if ( !toggling )
            {
                open( combo );
            }
            return true;
        }
        case QEvent::MouseButtonRelease:
            return true;
        case QEvent::KeyPress:
            if ( !opensList( static_cast< QKeyEvent* >( ev ) ) )
            {
                return false;
            }
            dismiss();
            open( combo );
            return true;
        case QEvent::Hide:
            if ( isOpenFor( combo ) )
            {
                dismiss();
            }
            return false;
        default:
            return false;
        }
    }

private:
    static bool opensList( QKeyEvent* key )
    {
        const bool alt = key->modifiers().testFlag( Qt::AltModifier );
        switch ( key->key() )
        {
        case Qt::Key_F4:
            return !alt;
        case Qt::Key_Space:
        case Qt::Key_Select:
            return true;
        case Qt::Key_Up:
        case Qt::Key_Down:
            return alt;
        default:
            return false;
        }
    }

    static QComboBox* comboOf( QWidget* container )
    {
        if ( !container )
        {
            return nullptr;
        }
        for ( QWidget* p = container->parentWidget(); p; p = p->parentWidget() )
        {
            if ( auto* cb = qobject_cast< QComboBox* >( p ) )
            {
                return cb;
            }
        }
        const auto widgets = QApplication::allWidgets();
        for ( QWidget* cand : widgets )
        {
            auto* cb = qobject_cast< QComboBox* >( cand );
            if ( cb && cb->view()
                 && ( cb->view()->window() == container
                      || cb->view()->parentWidget() == container ) )
            {
                return cb;
            }
        }
        return nullptr;
    }

    bool isOpenFor( const QComboBox* combo ) const
    {
        return m_view && m_view->isVisible() && m_combo == combo;
    }

    // Only reached when code calls QComboBox::showPopup() itself; the
    // interactive paths above never let Qt build the container.
    void adoptNativePopup( QWidget* container )
    {
        QPointer< QComboBox > combo = comboOf( container );
        if ( !combo )
        {
            return;
        }
        QTimer::singleShot( 0, combo, [ this, combo ]() {
            if ( combo )
            {
                combo->hidePopup();
                open( combo );
            }
        } );
    }

    void open( QComboBox* combo )
    {
        QWidget* host = combo->window();
        if ( !host || !combo->model() || combo->count() < 1 )
        {
            return;
        }
        if ( m_view && m_view->parentWidget() != host )
        {
            delete m_view.data();
        }
        if ( !m_view )
        {
            m_view = new QListView( host );
            m_view->setObjectName( QStringLiteral( "modernComboOverlay" ) );
            m_view->setUniformItemSizes( true );
            m_view->setHorizontalScrollBarPolicy( Qt::ScrollBarAlwaysOff );
            m_view->setEditTriggers( QAbstractItemView::NoEditTriggers );
            m_view->setSelectionBehavior( QAbstractItemView::SelectRows );
            QListView* view = m_view;
            QObject::connect( view,
                              &QAbstractItemView::clicked,
                              view,
                              [ this ]( const QModelIndex& i ) { choose( i ); } );
            QObject::connect( view,
                              &QAbstractItemView::activated,
                              view,
                              [ this ]( const QModelIndex& i ) { choose( i ); } );
        }
        m_combo = combo;
        m_view->setModel( combo->model() );
        m_view->setModelColumn( combo->modelColumn() );
        m_view->setRootIndex( combo->rootModelIndex() );
        const QModelIndex current = combo->model()->index(
            combo->currentIndex(), combo->modelColumn(), combo->rootModelIndex() );
        if ( current.isValid() )
        {
            m_view->setCurrentIndex( current );
        }
        m_view->ensurePolished();
        place( 2 * m_view->frameWidth() );
        m_view->show();
        m_view->raise();
        // Stylesheet padding lands on the viewport margins, which only exist
        // once the view has a geometry, so the first pass measures them.
        const int chrome = m_view->height() - m_view->viewport()->height();
        if ( chrome != 2 * m_view->frameWidth() )
        {
            place( chrome );
        }
        if ( current.isValid() )
        {
            m_view->scrollTo( current, QAbstractItemView::PositionAtCenter );
        }
        m_view->setFocus( Qt::PopupFocusReason );
    }

    void place( int chrome )
    {
        QWidget* host = m_view->parentWidget();
        const QPoint origin = m_combo->mapTo( host, QPoint( 0, 0 ) );
        const int rowHeight = qMax( 1, m_view->sizeHintForRow( 0 ) );
        const int below = qMax( 0, host->height() - ( origin.y() + m_combo->height() ) );
        const int above = qMax( 0, origin.y() );
        const int wanted = m_combo->count() * rowHeight + chrome;
        const bool drop = wanted <= below || below >= above;
        const int height = qMax( rowHeight + chrome, qMin( wanted, drop ? below : above ) );
        const int width = m_combo->width();
        m_view->setGeometry( qBound( 0, origin.x(), qMax( 0, host->width() - width ) ),
                             drop ? origin.y() + m_combo->height() : qMax( 0, origin.y() - height ),
                             width,
                             height );
    }

    void dismiss()
    {
        if ( !m_view || !m_view->isVisible() )
        {
            m_combo.clear();
            return;
        }
        const bool refocus = m_view->hasFocus();
        QPointer< QComboBox > combo = m_combo;
        QPointer< QListView > view = m_view;
        m_view->hide();
        m_combo.clear();
        // Dropping the shared model has to outlive the event that closed the
        // list, because the view is still unwinding its own mouse handling.
        QTimer::singleShot( 0, view, [ view ]() {
            if ( view && !view->isVisible() )
            {
                view->setModel( nullptr );
            }
        } );
        if ( refocus && combo )
        {
            combo->setFocus( Qt::PopupFocusReason );
        }
    }

    // Picking a region repopulates the zone combo's model, so the combo is
    // told after the list has let go of it.
    void choose( const QModelIndex& index )
    {
        if ( !index.isValid() || !m_view || !m_view->isVisible() )
        {
            return;
        }
        QPointer< QComboBox > combo = m_combo;
        const int row = index.row();
        dismiss();
        if ( !combo )
        {
            return;
        }
        QTimer::singleShot( 0, combo, [ combo, row ]() {
            if ( !combo )
            {
                return;
            }
            combo->setCurrentIndex( row );
            QMetaObject::invokeMethod( combo, "activated", Q_ARG( int, row ) );
            QMetaObject::invokeMethod(
                combo, "textActivated", Q_ARG( QString, combo->itemText( row ) ) );
        } );
    }

    QPointer< QListView > m_view;
    QPointer< QComboBox > m_combo;
};
}"""

COMBO_INSTALL_OLD = "    installEventFilter( Calamares::Retranslator::instance() );"
COMBO_INSTALL_NEW = """    installEventFilter( Calamares::Retranslator::instance() );
    qApp->installEventFilter( new ComboOverlay( qApp ) );"""

QML_SIDE_OLD = """    w->setSource(
        QUrl( Calamares::searchQmlFile( Calamares::QmlSearch::Both, QStringLiteral( "calamares-sidebar" ) ) ) );
    setDimension( w, o, desiredWidth );
    return w;"""
QML_SIDE_NEW = """    w->setSource(
        QUrl( Calamares::searchQmlFile( Calamares::QmlSearch::Both, QStringLiteral( "calamares-sidebar" ) ) ) );
    CALAMARES_RETRANSLATE_FOR( w, if ( w ) { w->engine()->retranslate(); } );
    setDimension( w, o, desiredWidth );
    return w;"""

VIEW_OLD = "    CALAMARES_RETRANSLATE_SLOT( &ViewManager::updateButtonLabels );"
VIEW_NEW = """    CALAMARES_RETRANSLATE( updateButtonLabels();
                           if ( rowCount() > 0 )
                           {
                               emit dataChanged( index( 0 ), index( rowCount() - 1 ) );
                           } );"""

CANCEL_OLD = """        updateCancelEnabled( !settings->disableCancel() && !( executing && settings->disableCancelDuringExec() ) );
        updateBackAndNextVisibility( !( executing && settings->hideBackAndNextDuringExec() ) );"""
CANCEL_NEW = """        updateCancelEnabled( !settings->disableCancel() && !( executing && settings->disableCancelDuringExec() ) );
        UPDATE_BUTTON_PROPERTY( quitVisible,
                                !settings->disableCancel()
                                    && !( executing && settings->disableCancelDuringExec() ) );
        updateBackAndNextVisibility( !( executing && settings->hideBackAndNextDuringExec() ) );"""

# The confirm is a second X11 window. Cage never maps it, so Cancel looks
# dead. Quit instead; the live session starts Calamares again.
CANCEL_ASK_OLD = """    // Otherwise, confirm cancel/quit.
    QString title = settings->isSetupMode() ? tr( "Cancel Setup?", "@title" ) : tr( "Cancel Installation?", "@title" );
    QString question = settings->isSetupMode() ? tr( "Do you really want to cancel the current setup process?\\n"
                                                     "The setup program will quit and all changes will be lost." )
                                               : tr( "Do you really want to cancel the current install process?\\n"
                                                     "The installer will quit and all changes will be lost." );
    QMessageBox mb( QMessageBox::Question, title, question, QMessageBox::Yes | QMessageBox::No, m_widget );
    mb.setDefaultButton( QMessageBox::No );
    Calamares::fixButtonLabels( &mb );
    int response = mb.exec();
    return ( response == QMessageBox::Yes ) ? Confirmation::CancelInstallation : Confirmation::Continue;"""
CANCEL_ASK_NEW = """    // Otherwise, confirm cancel/quit.
    // A QMessageBox is another X11 window. Cage does not map it, so
    // Cancel looked dead. The live session starts this program again
    // when it exits. The finished page still reboots instead.
    Q_UNUSED( settings )
    return Confirmation::CancelInstallation;"""

TOGGLE_OLD = '        "Toggle log" );'
TOGGLE_NEW = '        tr( "Toggle log" ) );'

VIEW_INC_OLD = """#include <QFile>
#include <QMessageBox>"""
VIEW_INC_NEW = """#include <QFile>
#include <QMessageBox>
#include <QTimer>"""

VIEW_CTOR_OLD = """#ifdef PRESERVE_FOR_TRANSLATION_PURPOSES
    tr( "&Yes" );
    tr( "&No" );
    tr( "&Close" );
#endif
}"""
VIEW_CTOR_NEW = """#ifdef PRESERVE_FOR_TRANSLATION_PURPOSES
    tr( "&Yes" );
    tr( "&No" );
    tr( "&Close" );
#endif
    if ( QFile::exists( QStringLiteral( "/etc/calamares/unattended" ) ) )
    {
        auto* t = new QTimer( this );
        t->setInterval( 750 );
        QObject::connect( t, &QTimer::timeout, this, [ this ]() {
            if ( nextEnabled() )
            {
                next();
            }
        } );
        t->start();
    }
}"""

KB_OLD = """    ui->setupUi( this );

    // Keyboard Preview
    ui->KBPreviewLayout->addWidget( m_keyboardPreview );"""
KB_NEW = """    ui->setupUi( this );
    ui->label->hide();
    ui->physicalModelSelector->hide();
    ui->buttonRestore->hide();

    // Keyboard Preview
    ui->KBPreviewLayout->addWidget( m_keyboardPreview );"""

# live-xkb-filter.py drops every variant, so updateVariants() never calls
# setCurrentIndex and the variant signal that starts apply() never fires.
# Without this, picking German leaves the installer on the Xwayland us map
# and the password typed on Users is not the one the greeter will accept.
KB_APPLY_OLD = """                 m_current.selectedLayout = m_keyboardLayoutsModel->item( index ).first;
                 updateVariants( QPersistentModelIndex( m_keyboardLayoutsModel->index( index ) ) );
                 emit prettyStatusChanged();"""
KB_APPLY_NEW = """                 m_current.selectedLayout = m_keyboardLayoutsModel->item( index ).first;
                 updateVariants( QPersistentModelIndex( m_keyboardLayoutsModel->index( index ) ) );
                 somethingChanged();"""

# The stock timer waits a fraction of a second. The layout the user just
# picked has to be the one the next key uses.
KB_NOW_OLD = """void
Config::somethingChanged()
{
    if ( m_applyTimer.isActive() )
    {
        m_applyTimer.stop();
    }
    m_applyTimer.start( QApplication::keyboardInputInterval() );
    emit prettyStatusChanged();
}"""
KB_NOW_NEW = """void
Config::somethingChanged()
{
    apply();
    emit prettyStatusChanged();
}"""

WELCOME_INC_OLD = """#include <QFutureWatcher>"""
WELCOME_INC_NEW = """#include <QFutureWatcher>
#include <QProcess>"""

WELCOME_XKB_OLD = """        Calamares::Locale::insertGS( *Calamares::JobQueue::instance()->globalStorage(),
                                     QStringLiteral( "LANG" ),
                                     Calamares::translatorLocaleName().name );
    }
    emit localeIndexChanged( m_localeIndex );
}"""
WELCOME_XKB_NEW = """        Calamares::Locale::insertGS( *Calamares::JobQueue::instance()->globalStorage(),
                                     QStringLiteral( "LANG" ),
                                     Calamares::translatorLocaleName().name );
    }
    const QString layout = modernWelcomeXkb(
        selectedTranslation.locale().name().section( QLatin1Char( '_' ), 1, 1 ) );
    if ( !layout.isEmpty() )
    {
        QProcess::execute( QStringLiteral( "/usr/lib/modern/live-xkb.sh" ), { layout } );
    }
    emit localeIndexChanged( m_localeIndex );
}"""

# cage/Xwayland ignores the first `setxkbmap -layout de`. India works because
# non-ascii-layouts adds `-option grp:…` and that rebuilds the map. ASCII
# layouts (German) never sent -option, so Z still typed Y. A bare -option
# is a missing argument and setxkbmap then keeps the old map; an empty
# option clears it. Two calls back to back are still one burst: the first
# pick of German stays on us until the user leaves and comes back. A query
# finishes that burst, and a later call applies the layout.
KB_XKB_OLD = """        basicArguments.append( xkbmap_layout_args( settings.selectedLayout, settings.selectedVariant ) );
        QProcess::execute( "setxkbmap", basicArguments );
        cDebug() << "xkbmap selection changed to: " << settings.selectedLayout << '-' << settings.selectedVariant;"""
KB_XKB_NEW = """        basicArguments.append( xkbmap_layout_args( settings.selectedLayout, settings.selectedVariant ) );
        basicArguments << QStringLiteral( "-option" ) << QString();
        QProcess::execute( "setxkbmap", basicArguments );
        QProcess::execute( "setxkbmap", { QStringLiteral( "-query" ) } );
        QProcess::execute( QStringLiteral( "/usr/lib/modern/live-xkb.sh" ),
                           { settings.selectedLayout, settings.selectedVariant } );
        cDebug() << "xkbmap selection changed to: " << settings.selectedLayout << '-' << settings.selectedVariant;"""

# setConfigurationMap() detects the layout while Welcome is still the live
# ISO locale. onActivate runs after the language combo has moved. A layout
# the user already picked (state UserSelected) is left alone.
KB_ACTIVATE_OLD = """void
KeyboardViewStep::onActivate()
{
    m_config->guessLocaleKeyboardLayout();
}"""
KB_ACTIVATE_NEW = """void
KeyboardViewStep::onActivate()
{
    m_config->detectCurrentKeyboardLayout();
    m_config->guessLocaleKeyboardLayout();
}"""

KB_LOCALE_INC_OLD = """#include <QGuiApplication>
#include <QProcess>"""
KB_LOCALE_INC_NEW = """#include <QGuiApplication>
#include <QLocale>
#include <QProcess>
#include <QTimer>"""

# Prefer the Welcome language over setxkbmap -print. A fresh Xwayland
# reports pc+us even after the Welcome combo is German, and detect runs
# again from onActivate while the choice is still the initial one.
# The Location step stores LANG before this step opens, so its country
# (de_AT -> at) picks the layout; a LANG left from another language is
# ignored rather than mixing one language's country into another.
KB_DETECT_OLD = """    if ( m_configureLocale1 )
    {
        getCurrentKeyboardLayoutLocale1( currentLayout, currentVariant, currentModel );
    }
    else
    {
        getCurrentKeyboardLayoutXkb( currentLayout, currentVariant, currentModel );
    }"""
KB_DETECT_NEW = """    QString welcomeCountry;
    if ( auto* gs = Calamares::JobQueue::instance()->globalStorage() )
    {
        const QString stored = Calamares::Locale::readGS( *gs, QStringLiteral( "LANG" ) )
                                   .section( QLatin1Char( '.' ), 0, 0 )
                                   .section( QLatin1Char( '@' ), 0, 0 );
        if ( stored.section( QLatin1Char( '_' ), 0, 0 ).toLower()
             == QLocale().name().section( QLatin1Char( '_' ), 0, 0 ).toLower() )
        {
            welcomeCountry = stored.section( QLatin1Char( '_' ), 1, 1 );
        }
    }
    const QString welcomeLayout = modernWelcomeLayout( welcomeCountry );
    cDebug() << "ModernOS: Welcome" << QLocale().name() << "country" << welcomeCountry << "layout" << welcomeLayout;
    if ( !welcomeLayout.isEmpty() )
    {
        currentLayout = welcomeLayout;
    }
    else if ( m_configureLocale1 )
    {
        getCurrentKeyboardLayoutLocale1( currentLayout, currentVariant, currentModel );
    }
    else
    {
        getCurrentKeyboardLayoutXkb( currentLayout, currentVariant, currentModel );
    }"""

# Upstream automaticLocaleConfiguration() prefers a LANG already stored from
# the live ISO. That stays en_US after Welcome moves to German, so the
# Location step installs English and the login screen follows it.
# The timezone country picks the regional locale (Vienna -> de_AT), and
# setCurrentLocation() re-runs this whenever the zone changes.
LOCALE_LANG_OLD = """    auto* gs = Calamares::JobQueue::instance()->globalStorage();
    QString lang = Calamares::Locale::readGS( *gs, QStringLiteral( "LANG" ) );
    if ( lang.isEmpty() )
    {
        lang = QLocale().name();
    }
    return LocaleConfiguration::fromLanguageAndLocation( lang, supportedLocales(), currentLocation()->country() );"""
LOCALE_LANG_NEW = """    QString lang = modernWelcomeLanguage( currentLocation() ? currentLocation()->country() : QString() );
    cDebug() << "ModernOS: Welcome" << QLocale().name() << "locale" << lang;
    if ( lang.isEmpty() )
    {
        auto* gs = Calamares::JobQueue::instance()->globalStorage();
        lang = Calamares::Locale::readGS( *gs, QStringLiteral( "LANG" ) );
    }
    if ( lang.isEmpty() )
    {
        lang = QLocale().name();
    }
    return LocaleConfiguration::fromLanguageAndLocation( lang, supportedLocales(), currentLocation()->country() );"""

SUMMARY_CONTENT_OLD = """    delete m_contentWidget;  // It might have been created previously
    m_contentWidget = new QWidget;
    m_layout = new QVBoxLayout( m_contentWidget );"""
SUMMARY_CONTENT_NEW = """    delete m_contentWidget;  // It might have been created previously
    m_contentWidget = new QWidget;
    m_contentWidget->setObjectName( "summaryContent" );
    m_contentWidget->setAutoFillBackground( true );
    m_layout = new QVBoxLayout( m_contentWidget );"""

SUMMARY_WRAP_OLD = """    QWidget* w = new QWidget();
    QHBoxLayout* itemBodyLayout = new QHBoxLayout;
    w->setLayout( itemBodyLayout );"""
SUMMARY_WRAP_NEW = """    QWidget* w = new QWidget();
    w->setObjectName( "summaryItemWrap" );
    w->setAutoFillBackground( true );
    QHBoxLayout* itemBodyLayout = new QHBoxLayout;
    w->setLayout( itemBodyLayout );"""

PARTITION_SUM_OLD = """QWidget*
PartitionViewStep::createSummaryWidget() const
{
    QWidget* widget = new QWidget;
    QVBoxLayout* mainLayout = new QVBoxLayout;
    widget->setLayout( mainLayout );"""
PARTITION_SUM_NEW = """QWidget*
PartitionViewStep::createSummaryWidget() const
{
    QWidget* widget = new QWidget;
    widget->setObjectName( "summaryPartition" );
    widget->setAutoFillBackground( true );
    QVBoxLayout* mainLayout = new QVBoxLayout;
    widget->setLayout( mainLayout );"""

# PartitionLabelsView paints with QPainter; QSS never reaches Qt::black.
PARTITION_LABELS_OLD = """    painter->setPen( Qt::black );
    int vertOffset = 0;
    int width = 0;
    for ( const QString& textLine : text )
    {
        QSize textSize = painter->fontMetrics().size( Qt::TextSingleLine, textLine );
        painter->drawText(
            pos.x() + LABEL_PARTITION_SQUARE_MARGIN, pos.y() + vertOffset + textSize.height() / 2, textLine );
        vertOffset += textSize.height();
        painter->setPen( Qt::gray );"""
PARTITION_LABELS_NEW = """    painter->setPen( palette().color( QPalette::WindowText ) );
    int vertOffset = 0;
    int width = 0;
    for ( const QString& textLine : text )
    {
        QSize textSize = painter->fontMetrics().size( Qt::TextSingleLine, textLine );
        painter->drawText(
            pos.x() + LABEL_PARTITION_SQUARE_MARGIN, pos.y() + vertOffset + textSize.height() / 2, textLine );
        vertOffset += textSize.height();
        painter->setPen( palette().color( QPalette::Disabled, QPalette::WindowText ) );"""

USERS_NAME_OLD = """QString
UsersViewStep::prettyName() const
{
    return tr( "Users" );
}"""
USERS_NAME_NEW = """QString
UsersViewStep::prettyName() const
{
    return tr( "User" );
}"""

USERS_CFG_OLD = """    ApplyPresets( *this, configurationMap ) << "fullName"
                                            << "loginName";
}"""
USERS_CFG_NEW = """    ApplyPresets( *this, configurationMap ) << "fullName"
                                            << "loginName";
    if ( QFile::exists( QStringLiteral( "/etc/calamares/unattended" ) ) )
    {
        setFullName( QStringLiteral( "Modern" ) );
        setLoginName( QStringLiteral( "modern" ) );
        setUserPassword( QStringLiteral( "modern" ) );
        setUserPasswordSecondary( QStringLiteral( "modern" ) );
    }
}"""

FINISHED_H_OLD = """    Ui::FinishedPage* ui;
    std::optional< QString > m_failure;"""
FINISHED_H_NEW = """    Ui::FinishedPage* ui;
    QLabel* m_badge = nullptr;
    QPushButton* m_restartButton = nullptr;
    std::optional< QString > m_failure;"""

FINISHED_H_FWD_OLD = """class Config;
namespace Ui"""
FINISHED_H_FWD_NEW = """class Config;
class QLabel;
class QPushButton;
namespace Ui"""

FINISHED_INC_OLD = "#include <QFocusEvent>"
FINISHED_INC_NEW = """#include <QBoxLayout>
#include <QCoreApplication>
#include <QFocusEvent>
#include <QIcon>
#include <QLabel>
#include <QPixmap>
#include <QPushButton>"""

# The checkbox only records intent for the footer Done button, which this
# page no longer has. A filled button that quits (aboutToQuit -> doRestart)
# is both the congratulation and the only way out of the live session.
FINISHED_CTOR_OLD = """    ui->mainText->setAlignment( Qt::AlignCenter );
    ui->mainText->setWordWrap( true );
    ui->mainText->setOpenExternalLinks( true );

    connect( config,
             &Config::restartModeChanged,
             [ this ]( Config::RestartMode mode )
             {
                 using Mode = Config::RestartMode;

                 ui->restartCheckBox->setVisible( mode != Mode::Never );
                 ui->restartCheckBox->setEnabled( mode != Mode::Always );
             } );"""
FINISHED_CTOR_NEW = """    ui->mainText->setAlignment( Qt::AlignCenter );
    ui->mainText->setWordWrap( true );
    ui->mainText->setOpenExternalLinks( true );
    ui->mainText->setObjectName( QStringLiteral( "finishedMainText" ) );

    m_badge = new QLabel( this );
    m_badge->setObjectName( QStringLiteral( "finishedBadge" ) );
    m_badge->setAlignment( Qt::AlignCenter );
    m_badge->setFixedSize( 112, 112 );
    const QPixmap badgePx = QIcon::fromTheme( QStringLiteral( "checkmark" ) ).pixmap( 56, 56 );
    if ( badgePx.isNull() )
    {
        m_badge->setText( QStringLiteral( "\\u2713" ) );
    }
    else
    {
        m_badge->setPixmap( badgePx );
    }
    ui->verticalLayout->insertWidget( 2, m_badge, 0, Qt::AlignHCenter );

    ui->restartCheckBox->hide();
    m_restartButton = new QPushButton( this );
    m_restartButton->setObjectName( QStringLiteral( "finishedRestart" ) );
    m_restartButton->setCursor( Qt::PointingHandCursor );
    ui->horizontalLayout->insertWidget( 1, m_restartButton );
    connect( m_restartButton,
             &QPushButton::clicked,
             [ config ]()
             {
                 config->setRestartNowWanted( true );
                 QCoreApplication::quit();
             } );

    connect( config,
             &Config::restartModeChanged,
             [ this ]( Config::RestartMode mode )
             {
                 using Mode = Config::RestartMode;

                 ui->restartCheckBox->setVisible( false );
                 m_restartButton->setVisible( mode != Mode::Never );
             } );"""

FINISHED_RETR_OLD = """    ui->retranslateUi( this );
    if ( !m_failure.has_value() )"""
FINISHED_RETR_NEW = """    ui->retranslateUi( this );
    m_restartButton->setText( ui->restartCheckBox->text().remove( QLatin1Char( '&' ) ) );
    m_badge->setVisible( !m_failure.has_value() );
    if ( !m_failure.has_value() )"""

# Upstream offers to stay in the live session and names it from branding
# productName, which is how "ModernOS Live" reached the congratulation. The
# installed system is the only thing this page may talk about, so the offer
# and its %2 both go.
FINISHED_TEXT_OLD = """            ui->mainText->setText( tr( "<h1>All done.</h1><br/>"
                                       "%1 has been installed on your computer.<br/>"
                                       "You may now restart into your new system, or continue "
                                       "using the %2 Live environment.",
                                       "@info" )
                                       .arg( branding->versionedName(), branding->productName() ) );"""
FINISHED_TEXT_NEW = """            ui->mainText->setText( tr( "<h1>All done.</h1><br/>"
                                       "%1 is installed and ready.<br/>"
                                       "Restart to start using your new desktop.",
                                       "@info" )
                                       .arg( branding->versionedName() ) );"""

# A failed install quits from the error dialog and never reaches this page,
# so hiding the footer here cannot strand the user without a way out.
FOOTER_OLD = """        UPDATE_BUTTON_PROPERTY( quitLabel, tr( "&Done", "@button" ) );
        UPDATE_BUTTON_PROPERTY( quitTooltip, quitOnCompleteTooltip );
        UPDATE_BUTTON_PROPERTY( quitVisible, true );
        UPDATE_BUTTON_PROPERTY( quitIcon, "dialog-ok-apply" );
        updateCancelEnabled( true );"""
FOOTER_NEW = """        UPDATE_BUTTON_PROPERTY( quitLabel, tr( "&Done", "@button" ) );
        UPDATE_BUTTON_PROPERTY( quitTooltip, quitOnCompleteTooltip );
        UPDATE_BUTTON_PROPERTY( quitVisible, false );
        UPDATE_BUTTON_PROPERTY( quitIcon, "dialog-ok-apply" );
        updateBackAndNextVisibility( false );
        updateCancelEnabled( true );"""

SUMMARY_TITLE_OLD = "    QString title() const { return m_title; }"
SUMMARY_TITLE_NEW = (
    '    QString title() const { return tr( "Summary", "@label" ); }'
)

def _die(msg: str) -> None:
    print(f"live-calamares: {msg}", file=sys.stderr)
    sys.exit(1)


def installer_data() -> dict:
    here = Path(__file__).resolve().parent
    for path in (
        here / "installer-locales.json",
        Path("/usr/lib/modern/installer-locales.json"),
    ):
        if not path.is_file():
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        rows = [loc for loc in (data.get("locales") or []) if isinstance(loc, dict)]
        if not rows:
            break
        for loc in rows:
            if not loc.get("calamares") or not isinstance(loc.get("countries"), list):
                _die(f"{path} is not generated by scripts/installer-locales.py (no countries)")
        return data
    _die("installer-locales.json missing or empty (run scripts/installer-locales.py)")
    return {}


def _cpp_literal(value: str) -> str:
    if not value or any(c not in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-" for c in value):
        _die(f"refusing locale value {value!r}")
    return value


def _country_arm(cond: str, loc: dict, field: str) -> str:
    default = _cpp_literal(str(loc.get(field) or ""))
    lines = [f"    if ( {cond} )", "    {"]
    for c in loc["countries"]:
        value = _cpp_literal(str(c.get(field) or ""))
        if value == default:
            continue
        cc = _cpp_literal(str(c.get("country") or ""))
        lines += [
            f'        if ( country == QLatin1String( "{cc}" ) )',
            "        {",
            f'            return QStringLiteral( "{value}" );',
            "        }",
        ]
    lines += [f'        return QStringLiteral( "{default}" );', "    }"]
    return "\n".join(lines)


def welcome_cpp_fn(name: str, field: str, data: dict) -> str:
    """Map Welcome language + country onto one installer-locales.json column.

    Codes with a region (pt_BR) match the full QLocale name first, so pt_BR
    and pt can both ship; the bare language is a last resort for them.
    """
    rows = data["locales"]
    regional = [r for r in rows if "_" in r["calamares"]]
    plain = [r for r in rows if "_" not in r["calamares"]]
    plain_codes = {r["calamares"] for r in plain}
    arms = [_country_arm(f'name == QLatin1String( "{_cpp_literal(r["calamares"])}" )', r, field) for r in regional]
    arms += [_country_arm(f'lang == QLatin1String( "{_cpp_literal(r["calamares"])}" )', r, field) for r in plain]
    for r in regional:
        base = r["calamares"].split("_", 1)[0]
        if base not in plain_codes:
            plain_codes.add(base)
            arms.append(_country_arm(f'lang == QLatin1String( "{_cpp_literal(base)}" )', r, field))
    return (
        "static QString\n"
        + name
        + "( const QString& country )\n"
        "{\n"
        "    const QString name = QLocale().name();\n"
        "    const QString lang = name.section( QLatin1Char( '_' ), 0, 0 ).toLower();\n"
        + "\n".join(arms)
        + "\n"
        "    return QString();\n"
        "}\n\n"
    )


def check_compiled_translations(top: Path, codes: list[str]) -> None:
    """Fail the build for a language this Calamares release does not compile.

    A code outside _tx_complete/_tx_good/_tx_ok has no .qm in a release
    build: Welcome would list it and then show English everywhere.
    """
    cmake = top / "CMakeLists.txt"
    if not cmake.is_file():
        _die(f"missing {cmake}; cannot check Calamares translations")
    compiled = {"en"}
    for m in re.finditer(r"set\(\s*_tx_(complete|good|ok)\s+([^)]*)\)", cmake.read_text(encoding="utf-8")):
        compiled.update(m.group(2).split())
    missing = [c for c in codes if c not in compiled]
    if missing:
        _die(
            f"Calamares does not compile translations {missing}; "
            "set \"calamares\" in languages.json to one of: " + " ".join(sorted(compiled))
        )


def apply_ts_strings(lang_dir: Path, strings: dict) -> None:
    """Set each translation in lang/calamares_<code>.ts, adding missing messages."""
    for code, entries in sorted((strings or {}).items()):
        if not entries:
            continue
        ts = lang_dir / f"calamares_{code}.ts"
        if not ts.is_file():
            _die(f"missing {ts} for language {code}")
        root = ET.parse(ts).getroot()
        for e in entries:
            source, comment = e["source"], e.get("comment") or ""
            contexts = [c for c in root.findall("context") if c.findtext("name") == e["context"]]
            if not contexts:
                ctx = ET.SubElement(root, "context")
                ET.SubElement(ctx, "name").text = e["context"]
                contexts = [ctx]
            hits = [
                m
                for c in contexts
                for m in c.findall("message")
                if m.findtext("source") == source and (m.findtext("comment") or "") == comment
            ]
            if not hits:
                msg = ET.SubElement(contexts[0], "message")
                ET.SubElement(msg, "source").text = source
                if comment:
                    ET.SubElement(msg, "comment").text = comment
                hits = [msg]
            for msg in hits:
                tr = msg.find("translation")
                if tr is None:
                    tr = ET.SubElement(msg, "translation")
                tr.text = e["translation"]
                tr.attrib.pop("type", None)
        body = ET.tostring(root, encoding="unicode")
        ts.write_text('<?xml version="1.0" encoding="utf-8"?>\n<!DOCTYPE TS>\n' + body + "\n", encoding="utf-8")


def translations_new(codes: list[str]) -> str:
    inner = ", ".join(f'QStringLiteral( "{c}" )' for c in codes)
    return f"""TranslationsModel*
availableTranslations()
{{
    static const QStringList limited{{ {inner} }};
    static TranslationsModel* model = new TranslationsModel( limited );
    return model;
}}"""


def patch(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    # Several insertions keep the anchor (old) inside new, so a re-run
    # must look for new first or it inserts a second copy.
    if new in text:
        return
    if old not in text:
        print(f"live-calamares: {label} not found in {path}", file=sys.stderr)
        sys.exit(1)
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def src_root_from(arg: Path) -> Path:
    if arg.is_dir():
        return arg / "src" if (arg / "src").is_dir() else arg
    return arg.parents[2]


def install_modernnet(src: Path) -> None:
    incoming = Path(__file__).resolve().parent / "calamares-modernnet"
    dest = src / "modules" / "modernnet"
    if not incoming.is_dir():
        print(f"live-calamares: missing {incoming}", file=sys.stderr)
        sys.exit(1)
    if dest.exists():
        shutil.rmtree(dest)
    shutil.copytree(incoming, dest)
    cmake = dest / "CMakeLists.txt"
    if not cmake.is_file():
        print(f"live-calamares: missing {cmake}", file=sys.stderr)
        sys.exit(1)


def main() -> int:
    if len(sys.argv) != 2:
        print(
            "usage: calamares-limit-languages.py TranslationsModel.cpp|SRCROOT",
            file=sys.stderr,
        )
        return 2
    src = src_root_from(Path(sys.argv[1]))
    install_modernnet(src)
    trans = src / "libcalamares" / "locale" / "TranslationsModel.cpp"
    window = src / "calamares" / "CalamaresWindow.cpp"
    locale = src / "modules" / "locale" / "LocalePage.cpp"
    viewman = src / "libcalamaresui" / "ViewManager.cpp"
    execstep = src / "libcalamaresui" / "viewpages" / "ExecutionViewStep.cpp"
    keyboard = src / "modules" / "keyboard" / "KeyboardPage.cpp"
    keyboard_cfg = src / "modules" / "keyboard" / "Config.cpp"
    keyboard_step = src / "modules" / "keyboard" / "KeyboardViewStep.cpp"
    welcome_cfg = src / "modules" / "welcome" / "Config.cpp"
    locale_cfg = src / "modules" / "locale" / "Config.cpp"
    summary = src / "modules" / "summary" / "SummaryPage.cpp"
    summary_cfg = src / "modules" / "summary" / "Config.h"
    partition = src / "modules" / "partition" / "PartitionViewStep.cpp"
    labels = src / "modules" / "partition" / "gui" / "PartitionLabelsView.cpp"
    finished = src / "modules" / "finished" / "FinishedPage.cpp"
    finished_h = src / "modules" / "finished" / "FinishedPage.h"
    users = src / "modules" / "users" / "UsersViewStep.cpp"
    users_cfg = src / "modules" / "users" / "Config.cpp"
    top = src.parent if src.name == "src" else src
    data = installer_data()
    codes = [str(loc["calamares"]) for loc in data["locales"]]
    check_compiled_translations(top, codes)
    patch(trans, TRANS_OLD, translations_new(codes), "availableTranslations()")
    patch(window, SIDE_OLD, SIDE_NEW, "sidebar width qBound")
    patch(window, STYLE_OLD, STYLE_NEW, "qApp stylesheet for combo popups")
    patch(window, COMBO_INC_OLD, COMBO_INC_NEW, "in-window combo list overlay")
    patch(window, COMBO_INSTALL_OLD, COMBO_INSTALL_NEW, "install combo list overlay")
    patch(window, QML_SIDE_OLD, QML_SIDE_NEW, "QML sidebar retranslate")
    patch(locale, LOCALE_OLD, LOCALE_NEW, "locale zoneAndRegionLayout")
    patch(locale, CHANGE_OLD, CHANGE_NEW, "hide locale Change buttons")
    patch(viewman, VIEW_OLD, VIEW_NEW, "ViewManager dataChanged on language")
    patch(viewman, CANCEL_OLD, CANCEL_NEW, "hide Cancel during exec")
    patch(viewman, CANCEL_ASK_OLD, CANCEL_ASK_NEW, "Cancel restarts instead of a hidden dialog")
    patch(viewman, VIEW_INC_OLD, VIEW_INC_NEW, "ViewManager QTimer include")
    patch(viewman, VIEW_CTOR_OLD, VIEW_CTOR_NEW, "unattended auto-next")
    patch(viewman, FOOTER_OLD, FOOTER_NEW, "hide footer buttons on the finished page")
    patch(finished_h, FINISHED_H_FWD_OLD, FINISHED_H_FWD_NEW, "FinishedPage forward decls")
    patch(finished_h, FINISHED_H_OLD, FINISHED_H_NEW, "FinishedPage badge and restart members")
    patch(finished, FINISHED_INC_OLD, FINISHED_INC_NEW, "FinishedPage includes")
    patch(finished, FINISHED_CTOR_OLD, FINISHED_CTOR_NEW, "finished badge and restart button")
    patch(finished, FINISHED_RETR_OLD, FINISHED_RETR_NEW, "finished restart button text")
    patch(finished, FINISHED_TEXT_OLD, FINISHED_TEXT_NEW, "finished success copy")
    patch(execstep, TOGGLE_OLD, TOGGLE_NEW, "Toggle log tr()")
    patch(keyboard, KB_OLD, KB_NEW, "hide Keyboard model row")
    patch(keyboard_cfg, KB_APPLY_OLD, KB_APPLY_NEW, "apply layout when variants are empty")
    patch(keyboard_cfg, KB_NOW_OLD, KB_NOW_NEW, "apply the layout as soon as it is picked")
    patch(keyboard_cfg, KB_XKB_OLD, KB_XKB_NEW, "setxkbmap -option so Xwayland rebuilds")
    patch(keyboard_cfg, KB_LOCALE_INC_OLD, KB_LOCALE_INC_NEW, "QLocale include for Welcome layout")
    patch(
        keyboard_cfg,
        "void\nConfig::detectCurrentKeyboardLayout()\n",
        welcome_cpp_fn("modernWelcomeLayout", "xkb", data) + "void\nConfig::detectCurrentKeyboardLayout()\n",
        "Welcome language keyboard layout",
    )
    patch(keyboard_cfg, KB_DETECT_OLD, KB_DETECT_NEW, "detect Welcome layout instead of setxkbmap")
    patch(keyboard_step, KB_ACTIVATE_OLD, KB_ACTIVATE_NEW, "re-detect layout after Welcome")
    patch(welcome_cfg, WELCOME_INC_OLD, WELCOME_INC_NEW, "Welcome keyboard includes QProcess")
    patch(
        welcome_cfg,
        "void\nConfig::setLocaleIndex( int index )\n",
        welcome_cpp_fn("modernWelcomeXkb", "xkb", data) + "void\nConfig::setLocaleIndex( int index )\n",
        "Welcome language keyboard map",
    )
    patch(welcome_cfg, WELCOME_XKB_OLD, WELCOME_XKB_NEW, "Welcome language applies the keyboard now")
    patch(
        locale_cfg,
        "LocaleConfiguration\nConfig::automaticLocaleConfiguration() const\n",
        welcome_cpp_fn("modernWelcomeLanguage", "glibc", data)
        + "LocaleConfiguration\nConfig::automaticLocaleConfiguration() const\n",
        "Welcome language glibc locale",
    )
    patch(locale_cfg, LOCALE_LANG_OLD, LOCALE_LANG_NEW, "prefer Welcome language over stored LANG")
    patch(summary, SUMMARY_CONTENT_OLD, SUMMARY_CONTENT_NEW, "summary content object name")
    patch(summary, SUMMARY_WRAP_OLD, SUMMARY_WRAP_NEW, "summary item wrap object name")
    patch(summary_cfg, SUMMARY_TITLE_OLD, SUMMARY_TITLE_NEW, "Summary title live tr()")
    patch(partition, PARTITION_SUM_OLD, PARTITION_SUM_NEW, "partition summary object name")
    patch(labels, PARTITION_LABELS_OLD, PARTITION_LABELS_NEW, "partition legend palette text")
    patch(users, USERS_NAME_OLD, USERS_NAME_NEW, "Users step prettyName")
    patch(users_cfg, USERS_CFG_OLD, USERS_CFG_NEW, "unattended user presets")
    apply_ts_strings(top / "lang", data.get("strings") or {})
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
