# SPDX-FileCopyrightText: 2026 ModernOS
# SPDX-License-Identifier: GPL-3.0-or-later

calamares_add_plugin(modernapps
    TYPE viewmodule
    EXPORT_MACRO PLUGINDLLEXPORT_PRO
    SOURCES
        ModernAppsViewStep.cpp
        ModernAppsPage.cpp
    SHARED_LIB
)
