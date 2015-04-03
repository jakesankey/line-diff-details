var LineDiffWorker = require("./line-diff-worker")

class LineDiffDetails {
    activate(): void {
        atom.workspace.observeTextEditors((editor) => {
            var lineDiffWorker = new LineDiffWorker()
            lineDiffWorker.registerEditor(editor)
        })
    }

    deactivate(): void {
        var editors = atom.workspace.getTextEditors()
        editors.forEach((editor) => {
            var markers = editor.findMarkers({name: "line-diff"})
            markers.forEach((marker) => marker.destroy())
            var editorView = atom.views.getView(editor).shadowRoot
            var gutter = $(editorView).find(".gutter")
            gutter.off("click mouseenter mouseleave")
        })
    }
}

module.exports = new LineDiffDetails()
