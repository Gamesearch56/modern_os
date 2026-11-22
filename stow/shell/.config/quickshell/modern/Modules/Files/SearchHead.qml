// Heading above search results: the query and how many matches it found.
import QtQuick
import "../../Commons"
import "../../Widgets"
import "../../Services"

Row {
    id: root
    height: FilesSearch.active ? implicitHeight : 0
    opacity: FilesSearch.active ? 1 : 0
    spacing: Tokens.spacing.md

    MText {
        width: Math.max(0, root.width - found.implicitWidth - root.spacing)
        key: "files.search.heading"
        params: ({ query: FilesSearch.query })
        styleName: "titleSmall"
        color: Colors.color.onSurfaceVariant
        elide: Text.ElideRight
    }
    MText {
        id: found
        key: "files.search.found"
        params: ({ count: (FilesSearch.results || []).length })
        styleName: "titleSmall"
    }
}
