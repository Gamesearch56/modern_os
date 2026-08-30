// Hairline separator. Color from outlineVariant so it tracks the
// wallpaper seed instead of a hardcoded grey.
import QtQuick
import "../Commons"

Rectangle {
    implicitHeight: 1
    implicitWidth: Tokens.spacing.xxl
    color: Colors.color.outlineVariant
}
