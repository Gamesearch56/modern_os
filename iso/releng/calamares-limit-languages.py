#!/usr/bin/env python3
"""Patch Calamares for the live ISO.

Welcome languages come from installer-locales.json (next to this file).
Also: 180px sidebar, stacked zone, hide Location Change…, qApp QSS,
combo popup remap (in-window overlay SIGSEGV'd), Summary/partition
object names, hide Keyboard model, hide Cancel during exec,
ViewManager/QML retranslate, Toggle log tr(), Users step titled User,
Summary German title Übersicht (English stays Summary; title() calls tr()).
Partition legend Boot/root names use palette text (not Qt::black).
Unattended QEMU: /etc/calamares/unattended auto-next + user modern/modern.
Copies calamares-modernnet/ into src/modules/modernnet (Network step).

Pass TranslationsModel.cpp (AUR prepare) or the unpacked source tree.
"""
from __future__ import annotations

import json
import shutil
import sys
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
#include <QTimer>

#include <algorithm>

namespace
{
class ComboPopupFilter : public QObject
{
public:
    using QObject::QObject;
    bool eventFilter( QObject* obj, QEvent* ev ) override
    {
        if ( QLatin1String( obj->metaObject()->className() )
             != QLatin1String( "QComboBoxPrivateContainer" ) )
        {
            return false;
        }
        auto* w = qobject_cast< QWidget* >( obj );
        if ( !w )
        {
            return false;
        }
        if ( ev->type() == QEvent::Hide )
        {
            if ( !w->property( "modernRemapping" ).toBool() )
            {
                w->setProperty( "modernMoved", false );
            }
            return false;
        }
        if ( ev->type() != QEvent::Show )
        {
            return false;
        }
        if ( w->property( "modernRemapping" ).toBool() )
        {
            w->setProperty( "modernRemapping", false );
            return false;
        }
        QComboBox* cb = nullptr;
        for ( QWidget* p = w->parentWidget(); p; p = p->parentWidget() )
        {
            cb = qobject_cast< QComboBox* >( p );
            if ( cb )
            {
                break;
            }
        }
        if ( !cb )
        {
            const auto widgets = QApplication::allWidgets();
            for ( QWidget* cand : widgets )
            {
                auto* c = qobject_cast< QComboBox* >( cand );
                if ( c && c->view()
                     && ( c->view()->window() == w || c->view()->parentWidget() == w ) )
                {
                    cb = c;
                    break;
                }
            }
        }
        if ( !cb )
        {
            return false;
        }
        const QPoint pos = cb->mapToGlobal( QPoint( 0, cb->height() ) );
        w->setProperty( "modernRemapping", true );
        QTimer::singleShot( 0, w, [ w, pos ]() {
            w->hide();
            w->move( pos );
            w->show();
        } );
        return false;
    }
};
}"""

COMBO_INSTALL_OLD = "    installEventFilter( Calamares::Retranslator::instance() );"
COMBO_INSTALL_NEW = """    installEventFilter( Calamares::Retranslator::instance() );
    qApp->installEventFilter( new ComboPopupFilter( qApp ) );"""

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

USERS_TS_OLD = """  <context>
    <name>UsersViewStep</name>
    <message>
      <location filename="../src/modules/users/UsersViewStep.cpp" line="48"/>
      <source>Users</source>
      <translation>Benutzer</translation>
    </message>
  </context>"""
USERS_TS_NEW = """  <context>
    <name>UsersViewStep</name>
    <message>
      <location filename="../src/modules/users/UsersViewStep.cpp" line="48"/>
      <source>User</source>
      <translation>Benutzer</translation>
    </message>
  </context>"""

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

SUMMARY_TS_OLD = """      <location filename="../src/modules/summary/Config.cpp" line="35"/>
      <source>Summary</source>
      <comment>@label</comment>
      <translation>Zusammenfassung</translation>"""
SUMMARY_TS_NEW = """      <location filename="../src/modules/summary/Config.cpp" line="35"/>
      <source>Summary</source>
      <comment>@label</comment>
      <translation>Übersicht</translation>"""

MODERNNET_TS = """
  <context>
    <name>ModernNetViewStep</name>
    <message>
      <source>Network</source>
      <comment>@title</comment>
      <translation>Netzwerk</translation>
    </message>
  </context>
  <context>
    <name>ModernNetPage</name>
    <message>
      <source>Ethernet</source>
      <translation>Ethernet</translation>
    </message>
    <message>
      <source>Nearby networks</source>
      <translation>Netzwerke in der Nähe</translation>
    </message>
    <message>
      <source>Refresh</source>
      <translation>Aktualisieren</translation>
    </message>
    <message>
      <source>Password</source>
      <translation>Passwort</translation>
    </message>
    <message>
      <source>Connect</source>
      <translation>Verbinden</translation>
    </message>
    <message>
      <source>Connected</source>
      <translation>Verbunden</translation>
    </message>
    <message>
      <source>Not connected</source>
      <translation>Nicht verbunden</translation>
    </message>
    <message>
      <source>You're connected with Ethernet</source>
      <translation>Du bist per Ethernet verbunden</translation>
    </message>
    <message>
      <source>You can continue to the next step.</source>
      <translation>Du kannst mit dem nächsten Schritt fortfahren.</translation>
    </message>
    <message>
      <source>Wi-Fi is connected.</source>
      <translation>WLAN ist verbunden.</translation>
    </message>
    <message>
      <source>Connect to Wi-Fi to continue.</source>
      <translation>Verbinde dich mit WLAN, um fortzufahren.</translation>
    </message>
    <message>
      <source>%1 — Connected</source>
      <translation>%1 — Verbunden</translation>
    </message>
    <message>
      <source>%1 — Saved</source>
      <translation>%1 — Gespeichert</translation>
    </message>
    <message>
      <source>Searching for networks…</source>
      <translation>Suche nach Netzwerken…</translation>
    </message>
    <message>
      <source>No networks found.</source>
      <translation>Keine Netzwerke gefunden.</translation>
    </message>
    <message>
      <source>Could not connect. Check the password.</source>
      <translation>Verbinden fehlgeschlagen. Passwort prüfen.</translation>
    </message>
  </context>
"""


def load_calamares_codes() -> list[str]:
    here = Path(__file__).resolve().parent
    for path in (
        here / "installer-locales.json",
        Path("/usr/lib/modern/installer-locales.json"),
    ):
        if not path.is_file():
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        codes = [str(loc["calamares"]) for loc in data.get("locales") or [] if loc.get("calamares")]
        if codes:
            return codes
    print("live-calamares: installer-locales.json missing or empty", file=sys.stderr)
    sys.exit(1)


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
    if old not in text:
        if new in text:
            return
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


def patch_modernnet_ts(ts: Path) -> None:
    text = ts.read_text(encoding="utf-8")
    if "ModernNetViewStep" in text:
        return
    if "</TS>" in text:
        text = text.replace("</TS>", MODERNNET_TS + "</TS>", 1)
    else:
        text += MODERNNET_TS
    ts.write_text(text, encoding="utf-8")


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
    summary = src / "modules" / "summary" / "SummaryPage.cpp"
    summary_cfg = src / "modules" / "summary" / "Config.h"
    partition = src / "modules" / "partition" / "PartitionViewStep.cpp"
    labels = src / "modules" / "partition" / "gui" / "PartitionLabelsView.cpp"
    finished = src / "modules" / "finished" / "FinishedPage.cpp"
    finished_h = src / "modules" / "finished" / "FinishedPage.h"
    users = src / "modules" / "users" / "UsersViewStep.cpp"
    users_cfg = src / "modules" / "users" / "Config.cpp"
    users_ts = (src.parent if src.name == "src" else src) / "lang" / "calamares_de.ts"
    patch(trans, TRANS_OLD, translations_new(load_calamares_codes()), "availableTranslations()")
    patch(window, SIDE_OLD, SIDE_NEW, "sidebar width qBound")
    patch(window, STYLE_OLD, STYLE_NEW, "qApp stylesheet for combo popups")
    patch(window, COMBO_INC_OLD, COMBO_INC_NEW, "combo popup event filter")
    patch(window, COMBO_INSTALL_OLD, COMBO_INSTALL_NEW, "install combo popup filter")
    patch(window, QML_SIDE_OLD, QML_SIDE_NEW, "QML sidebar retranslate")
    patch(locale, LOCALE_OLD, LOCALE_NEW, "locale zoneAndRegionLayout")
    patch(locale, CHANGE_OLD, CHANGE_NEW, "hide locale Change buttons")
    patch(viewman, VIEW_OLD, VIEW_NEW, "ViewManager dataChanged on language")
    patch(viewman, CANCEL_OLD, CANCEL_NEW, "hide Cancel during exec")
    patch(viewman, VIEW_INC_OLD, VIEW_INC_NEW, "ViewManager QTimer include")
    patch(viewman, VIEW_CTOR_OLD, VIEW_CTOR_NEW, "unattended auto-next")
    patch(viewman, FOOTER_OLD, FOOTER_NEW, "hide footer buttons on the finished page")
    patch(finished_h, FINISHED_H_FWD_OLD, FINISHED_H_FWD_NEW, "FinishedPage forward decls")
    patch(finished_h, FINISHED_H_OLD, FINISHED_H_NEW, "FinishedPage badge and restart members")
    patch(finished, FINISHED_INC_OLD, FINISHED_INC_NEW, "FinishedPage includes")
    patch(finished, FINISHED_CTOR_OLD, FINISHED_CTOR_NEW, "finished badge and restart button")
    patch(finished, FINISHED_RETR_OLD, FINISHED_RETR_NEW, "finished restart button text")
    patch(execstep, TOGGLE_OLD, TOGGLE_NEW, "Toggle log tr()")
    patch(keyboard, KB_OLD, KB_NEW, "hide Keyboard model row")
    patch(summary, SUMMARY_CONTENT_OLD, SUMMARY_CONTENT_NEW, "summary content object name")
    patch(summary, SUMMARY_WRAP_OLD, SUMMARY_WRAP_NEW, "summary item wrap object name")
    patch(summary_cfg, SUMMARY_TITLE_OLD, SUMMARY_TITLE_NEW, "Summary title live tr()")
    patch(partition, PARTITION_SUM_OLD, PARTITION_SUM_NEW, "partition summary object name")
    patch(labels, PARTITION_LABELS_OLD, PARTITION_LABELS_NEW, "partition legend palette text")
    patch(users, USERS_NAME_OLD, USERS_NAME_NEW, "Users step prettyName")
    patch(users_cfg, USERS_CFG_OLD, USERS_CFG_NEW, "unattended user presets")
    patch(users_ts, USERS_TS_OLD, USERS_TS_NEW, "Users step German source")
    patch(users_ts, SUMMARY_TS_OLD, SUMMARY_TS_NEW, "Summary step German title")
    patch_modernnet_ts(users_ts)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
