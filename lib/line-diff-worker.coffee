{$, View} = require "atom-space-pen-views"

class LineDiffWorker
    markers: {}

    registerEditor: (@editor) ->
        editorView = atom.views.getView(@editor)
        editorView.onDidChangeScrollTop @update
        @gutter = $(editorView).find ".gutter"
        @editor.onDidStopChanging @update
        @editor.onDidChangeCursorPosition @clearMarkers
        @update()

    update: =>
        @clearMarkers()
        
        statusChangeSelector = ".git-line-modified, .git-line-removed, .git-line-added"
        @gutter.off("click mouseenter mouseleave")

        @gutter.on "mouseenter", statusChangeSelector, ->
            if $(this).hasClass("git-line-modified")
                $(this).addClass("line-diff-modified")
            if $(this).hasClass("git-line-added")
                $(this).addClass("line-diff-added")
            if $(this).hasClass("git-line-removed")
                $(this).addClass("line-diff-removed")

        @gutter.on "mouseleave", statusChangeSelector, ->
            $(this).removeClass("line-diff-modified line-diff-added line-diff-removed")

        @gutter.on "click", statusChangeSelector, (event) =>
            @clearMarkers()
            line = parseInt $(event.target).text()
            return if isNaN(line)
            details = @calculateDiffDetails(line)
            if not details
                @editor.unfoldAll()
            else
                @decorateDiffMarkers(details)

    clearMarkers: ->
        for id, marker of @markers
            marker.destroy()
            delete @markers[id]

    decorateDiffMarkers: (details) ->
        startPoint = [details.newStart - 1, 0]
        newEndBufferRow = details.newStart - 1 + details.newLines - 1
        if newEndBufferRow < 0
            newEndBufferRow = 0
        buffer = @editor.getBuffer()
        newEndBufferRowLength = buffer.lineForRow(newEndBufferRow).length
        endPoint = [newEndBufferRow, newEndBufferRowLength]
        marker = null
        messageBubble = null
        marker = @editor.markBufferRange([startPoint, startPoint])
        if details.isRemoving
            messageBubble = new MessageBubble(details.originalContent, ->
                buffer.insert([details.newStart, 0], details.originalContent)
            )
        else if details.isAdding
            messageBubble = new MessageBubble(details.originalContent, ->
                buffer.deleteRows(details.newStart - 1, newEndBufferRow)
            )
        else
            messageBubble = new MessageBubble(details.originalContent, =>
                @editor.setTextInBufferRange([startPoint, endPoint], details.originalContent.slice(0, -1))
            )
        @editor.decorateMarker(marker, {type: "overlay", item: messageBubble, position: "tail"})
        @markers[marker.id] = marker

    findFileDiffs: ->
        activePath = @editor.getPath()
        if process.platform is 'win32'
            repo = r for r in atom.project.getRepositories() when activePath.indexOf(r?.repo?.workingDirectory?.replace(/\//g, "\\")) != -1
            activePath = activePath.replace(/\\/g, '/')
        else
            repo = r for r in atom.project.getRepositories() when activePath.indexOf(r?.repo.workingDirectory) != -1
        return [] if not repo?
        fileRepo = repo.getRepo(activePath)
        activeEditorText = @editor.getBuffer().getText()
        relativePath = activePath.substring(fileRepo.workingDirectory.length + 1)
        return fileRepo.getLineDiffDetails(relativePath, activeEditorText)

    findDiffForLine: (lineNumber) ->
        fileDiffs = @findFileDiffs()
        for diff in fileDiffs
            if (diff.newLineNumber is lineNumber) or (diff.newLineNumber is -1 and diff.newStart is lineNumber)
                return diff
        return {}

    calculateDiffDetails: (lineNumber) ->
        fileDiffs = @findFileDiffs()
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
            

class MessageBubble extends View
    constructor: (@message, @revert) ->
        super(@message)

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
        @div class: "bubble", =>
            @div class: "action-buttons", =>
                @button click: "removeView", class: "btn diff-button", title: "Close", =>
                    @span class: "text-error icon icon-x"
                @button click: "revertAndClose", class: "btn diff-button", title: "Revert", =>
                    @span class: "text-warning icon icon-history"
                unless isRemoval
                    @button click: "copyToClipboard", class: "btn diff-button", title: "Copy", =>
                        @span class: "text-success icon icon-clippy"
            @div class: "bubble-code", => @span message
module.exports = LineDiffWorker
