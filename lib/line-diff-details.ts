import $ = require("jquery")

import LineDiffWorker = require("./line-diff-worker")

class LineDiffDetails {
    lineDiffWorkers: LineDiffWorker[] = []

    activate(): void {
        atom.workspace.observeTextEditors((editor) => {
            var lineDiffWorker = new LineDiffWorker()
            lineDiffWorker.registerEditor(editor)
            this.lineDiffWorkers.push(lineDiffWorker)
        })
    }

    deactivate(): void {
        this.lineDiffWorkers.forEach((lineDiffWorker) => {
            lineDiffWorker.clearMarkers()
        })
        this.lineDiffWorkers = []
        var editors = atom.workspace.getTextEditors()
        editors.forEach((editor) => {
            var editorView = atom.views.getView(editor)
            var gutter = $(editorView).find(".gutter")
            gutter.off("click mouseenter mouseleave")
        })
    }
}

module.exports = new LineDiffDetails()
