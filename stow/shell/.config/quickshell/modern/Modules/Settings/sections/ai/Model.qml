import QtQuick
import "../../../../Commons"

QtObject {
    readonly property string provider: Config.accounts?.ai?.provider ?? "ollama"
    readonly property string ollamaModel: Config.accounts?.ai?.ollamaModel ?? "llama3"
}
