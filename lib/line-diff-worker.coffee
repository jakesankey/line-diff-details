{$, View} = require "atom-space-pen-views"

class LineDiffWorker
    registerEditor: (@editor) ->
        @editor.onDidChangeScrollTop @update
        @editor.onDidStopChanging @update

    update: =>
        @clearMarkers()
        markers = @editor.findMarkers({name: "line-diff"})
        marker.destroy() for marker in markers
        editorView = atom.views.getView(@editor).shadowRoot
        gutter = $(editorView).find ".gutter"
        statusChangeSelector = ".git-line-modified, .git-line-removed, .git-line-added"
        gutter.off("click mouseenter mouseleave")

        gutter.on "mouseenter", statusChangeSelector, ->
            if $(this).hasClass("git-line-modified")
                $(this).addClass("line-diff-modified")
            if $(this).hasClass("git-line-added")
                $(this).addClass("line-diff-added")
            if $(this).hasClass("git-line-removed")
                $(this).addClass("line-diff-removed")

        gutter.on "mouseleave", statusChangeSelector, ->
            $(this).removeClass("line-diff-modified line-diff-added line-diff-removed")

        gutter.on "click", statusChangeSelector, (event) =>
            @clearMarkers()
            line = parseInt $(event.target).text()
            return if isNaN(line)
            details = @calculateDiffDetails(line)
            console.log line
            @decorateDiffMarkers(details)

    clearMarkers: ->
        markers = @editor.findMarkers({name: "line-diff"})
        marker.destroy() for marker in markers

    decorateDiffMarkers: (details) ->
        startPoint = [details.newStart - 1, 0]
        newEndBufferRow = details.newStart - 1 + details.newLines - 1
        buffer = @editor.getBuffer()
        newEndBufferRowLength = buffer.lineForRow(newEndBufferRow).length
        endPoint = [newEndBufferRow, newEndBufferRowLength]
        marker = null
        messageBubble = null
        marker = @editor.markBufferRange([startPoint, startPoint], {name: "line-diff"})
        if details.isRemoving
            messageBubble = new MessageBubble(details.originalContent, ->
                buffer.insert([details.newStart, 0], details.originalContent)
            )
        else if details.isAdding
            messageBubble = new MessageBubble(details.originalContent, ->
                for i in [0...details.newLines]
                    buffer.deleteRow(details.newStart - 1)
            )
        else
            messageBubble = new MessageBubble(details.originalContent, =>
                @editor.setTextInBufferRange([startPoint, endPoint], details.originalContent.slice(0, -1))
            )
        @editor.decorateMarker(marker, {type: "overlay", item: messageBubble, position: "tail"})

    findFileDiffs: ->
        activePath = @editor.getPath()
        if process.platform is 'win32'
            repo = r for r in atom.project.getRepositories() when activePath.indexOf(r?.repo.workingDirectory.replace(/\//g, "\\")) != -1
        else
            repo = r for r in atom.project.getRepositories() when activePath.indexOf(r?.repo.workingDirectory) != -1
        return [] if not repo?
        fileRepo = repo.getRepo(activePath)
        activeEditorText = @editor.getBuffer().getText()
        relativePath = activePath.substring(fileRepo.workingDirectory.length + 1)
        if process.platform is 'win32'
            relativePath = relativePath.replace('\\', '/')
        return fileRepo.getLineDiffDetails(relativePath, activeEditorText)

    findDiffForLine: (lineNumber) ->
        fileDiffs = @findFileDiffs()
        for diff in fileDiffs
            if (diff.newLineNumber is lineNumber) or (diff.newLineNumber is -1 and diff.newStart is lineNumber)
                return diff
        return {}

    calculateDiffDetails: (lineNumber) ->
        fileDiffs = @findFileDiffs()
        console.log fileDiffs
        lineStuff = {}
        index = 0
        newDiff = @findDiffForLine(lineNumber)
        for diff in fileDiffs
            lines = 0
            originalEnd = diff.oldStart + diff.oldLines - 1
            originalEnd = 1 if originalEnd < 1
            newEnd = diff.newStart + diff.newLines - 1
            if diff.oldLineNumber is newDiff.oldStart
                capture = index + diff.oldLines
                content = ""
                for item in [index...capture]
                    thisDiff = fileDiffs[item]
                    content += thisDiff.line
                return {
                    isRemoving: diff.newLines is 0
                    originalStart: diff.oldStart
                    originalEnd: originalEnd
                    newStart: diff.newStart
                    newEnd: newEnd
                    newLines: diff.newLines
                    originalContent: content
                }
            else if diff.oldLineNumber is -1 and diff.newLineNumber is lineNumber
                return {
                    isAdding: yes
                    originalStart: diff.oldStart
                    originalEnd: originalEnd
                    newStart: diff.newStart
                    newEnd: newEnd
                    newLines: diff.newLines
                    originalContent: ""
                }

            index++

        return {}

class MessageBubble extends View
    constructor: (@message, @revert) ->
        super(@message)

    countLeadingSpaces = (str) ->
        count = 0
        for s in str.split("")
            if s is " "
                count++
            else
                break
        return count

    buildStringOfSpaces = (len) ->
        str = ""
        for i in [0...len]
            str += "_"
        return str

    removeView: ->
        @remove()

    revertAndClose: ->
        @revert()
        @removeView()

    copyToClipboard: ->
        atom.clipboard.write @message?.trim()
        atom.notifications.addSuccess "Copied to clipboard"

    @content: (message) ->
        isRemoval = message.length is 0
        message = "(Remove new lines)" if isRemoval
        @div class: "select-list popover-list linter-list", =>
            @ul class: "list-group", =>
                for part in message.split("\n")
                    @li =>
                        @span class: "empty-space", buildStringOfSpaces(countLeadingSpaces(part))
                        @span part
            @div class: "action-buttons", =>
                @button click: "removeView", class: "btn btn-success diff-button", "Close"
                if not isRemoval
                    @button click: "copyToClipboard", class: "btn btn-primary diff-button", "Copy"
                @button click: "revertAndClose", class: "btn btn-warning diff-button", "Revert"

module.exports = LineDiffWorker
