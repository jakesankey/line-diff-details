LineDiffWorker = require "./line-diff-worker"

class LineDiffDetails
    activate: ->
        atom.workspace.observeTextEditors (editor) ->
            lineDiffWorker = new LineDiffWorker()
            lineDiffWorker.registerEditor(editor)

    deactivate: ->

    serialize: ->

module.exports = new LineDiffDetails()
