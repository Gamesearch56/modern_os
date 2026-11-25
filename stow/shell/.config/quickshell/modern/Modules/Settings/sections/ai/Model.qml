import QtQuick
import "../../../../Commons"

QtObject {
    readonly property string provider: Config.accounts?.ai?.provider ?? "none"
    readonly property string ollamaModel: Config.accounts?.ai?.ollamaModel ?? "llama3"
    readonly property string geminiModel: Config.accounts?.ai?.geminiModel ?? ""
    readonly property string chatgptModel: Config.accounts?.ai?.chatgptModel ?? ""
}
