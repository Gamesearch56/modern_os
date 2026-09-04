import QtQuick

// Quickshell.Services.Greetd (`import Quickshell.Services.Greetd`) is the
// real login path once greetd is enabled. Importing it here would fail
// the desktop shell on machines where the greetd QML plugin is absent
// (docs/ISOLATION.md), so this file stays a compile-safe stub.
// The login instance lives in stow/greeter/.config/quickshell/greeter/.
Item {
}
