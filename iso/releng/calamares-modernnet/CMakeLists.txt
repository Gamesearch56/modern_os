# SPDX-FileCopyrightText: 2026 ModernOS
# SPDX-License-Identifier: GPL-3.0-or-later

calamares_add_plugin(modernnet
    TYPE viewmodule
    EXPORT_MACRO PLUGINDLLEXPORT_PRO
    SOURCES
        ModernNetViewStep.cpp
        ModernNetPage.cpp
        ModernNetNm.cpp
        ModernNetRow.cpp
    SHARED_LIB
)
