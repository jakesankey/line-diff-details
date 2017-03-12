LineDiffWorker = require "../lib/line-diff-worker"

describe "LineDiffWorker Suite", ->
    service = null

    beforeEach ->
        service = new LineDiffWorker()

    it "should provide original content", ->
        service.findFileDiffs = ->
            return [
                {
                    "oldLineNumber": 12,
                    "newLineNumber": -1,
                    "oldStart": 12,
                    "newStart": 12,
                    "oldLines": 2,
                    "newLines": 3,
                    "line": "foo"
                },
                {
                    "oldLineNumber": 13,
                    "newLineNumber": -1,
                    "oldStart": 12,
                    "newStart": 12,
                    "oldLines": 2,
                    "newLines": 3,
                    "line": "bar"
                },
                {
                    "oldLineNumber": -1,
                    "newLineNumber": 12,
                    "oldStart": 12,
                    "newStart": 12,
                    "oldLines": 2,
                    "newLines": 3,
                    "line": "fizz"
                },
                 {
                     "oldLineNumber": -1,
                     "newLineNumber": 13,
                     "oldStart": 12,
                     "newStart": 12,
                     "oldLines": 2,
                     "newLines": 3,
                     "line": "buzz"
                },
                 {
                     "oldLineNumber": -1,
                     "newLineNumber": 14,
                     "oldStart": 12,
                     "newStart": 12,
                     "oldLines": 2,
                     "newLines": 3,
                     "line": "baz"
                }
            ]

        result = service.calculateDiffDetails(13)

        expect(result.originalStart).toEqual 12
        expect(result.originalEnd).toEqual 13
        expect(result.newStart).toEqual 12
        expect(result.newEnd).toEqual 14
        expect(result.originalContent).toEqual "foobar"

    it "should provide empty original content when lines have been added", ->
        service.findFileDiffs = ->
            return [
                {
                    "oldLineNumber": -1,
                    "newLineNumber": 13,
                    "oldStart": 12,
                    "newStart": 12,
                    "oldLines": 2,
                    "newLines": 2,
                    "line": "foo"
                },
                {
                    "oldLineNumber": -1,
                    "newLineNumber": 14,
                    "oldStart": 12,
                    "newStart": 12,
                    "oldLines": 2,
                    "newLines": 2,
                    "line": "bar"
                }
            ]

        result = service.calculateDiffDetails(13)

        expect(result.originalStart).toEqual 12
        expect(result.originalEnd).toEqual 13
        expect(result.newStart).toEqual 12
        expect(result.newEnd).toEqual 13
        expect(result.originalContent).toEqual ""

    it "should subscribe to events for updating", ->
        scrollTopEvent = no
        stopChangingEvent = no
        pathChangeEvent = no
        changeCursorPositionEvent = no
        editor = {
            editorElement: {
                onDidChangeScrollTop: -> scrollTopEvent = yes
            }
            onDidStopChanging: -> stopChangingEvent = yes
            onDidChangeCursorPosition: -> changeCursorPositionEvent = yes
        }

        service.registerEditor(editor)

        expect(scrollTopEvent).toBe yes
        expect(stopChangingEvent).toBe yes
        expect(changeCursorPositionEvent).toBe yes

    it "should decorate the marker", ->
        decorated = no
        editor = {
            getBuffer: ->
                return {
                    lineForRow: -> ""
                }
            markBufferRange: -> { id : 1 }
            decorateMarker: -> decorated = yes
        }
        details = {
            newStart: 1
            newLines: 1
            originalContent: "content"
        }
        service.editor = editor

        service.decorateDiffMarkers(details)

        expect(decorated).toBe yes
