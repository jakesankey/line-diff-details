var spacePen = require("atom-space-pen-views")
var $ = spacePen.$
var View = spacePen.View

class LineDiffWorker {
    private editor

    registerEditor(editor): void {
        this.editor = editor
        this.editor.onDidChangeScrollTop(() => this.update())
        this.editor.onDidStopChanging(() => this.update())
    }

    private update(): void {
        var markers = this.editor.findMarkers({name: "line-diff"})
        markers.forEach( (item) => item.destroy() )
        var editorView = atom.views.getView(this.editor).shadowRoot
        var gutter = $(editorView).find(".gutter")
        var statusChangeSelector = ".git-line-modified, .git-line-removed, .git-line-added"
        gutter.off("click mouseenter mouseleave")

        gutter.on("mouseenter", statusChangeSelector, (event) => {
            if ($(event.target).hasClass("git-line-modified")) {
                $(event.target).addClass("line-diff-modified")
            }
            if ($(event.target).hasClass("git-line-added")) {
                $(event.target).addClass("line-diff-added")
            }
            if ($(event.target).hasClass("git-line-removed")) {
                $(event.target).addClass("line-diff-removed")
            }
        })

        gutter.on("mouseleave", statusChangeSelector, (event) =>
            $(event.target).removeClass("line-diff-modified line-diff-added line-diff-removed")
        )

        gutter.on("click", statusChangeSelector, (event) => {
            var line = parseInt($(event.target).text())
            if (isNaN(line)) {
                return
            }
            var details = this.calculateDiffDetails(line)
            this.decorateDiffMarkers(details)
		})
    }

    private decorateDiffMarkers(details): void {
        var startPoint = [details.newStart - 1, 0]
        var newEndBufferRow = details.newStart - 1 + details.newLines - 1
        var buffer = this.editor.getBuffer()
        var newEndBufferRowLength = buffer.lineForRow(newEndBufferRow).length
        var endPoint = [newEndBufferRow, newEndBufferRowLength]
        var marker = null
        var messageBubble = null
        var marker = this.editor.markBufferRange([startPoint, endPoint], {name: "line-diff"})
        if (details.isRemoving) {
            messageBubble = new MessageBubble(details.originalContent, () =>
                buffer.insert([details.newStart, 0], details.originalContent)
            )
        } else if (details.isAdding) {
            messageBubble = new MessageBubble(details.originalContent, () => {
                for (var i = 0; i < details.newLines; i++) {
                    buffer.deleteRow(details.newStart - 1)
                }
			})
        } else {
            messageBubble = new MessageBubble(details.originalContent, () =>
                this.editor.setTextInBufferRange([startPoint, endPoint], details.originalContent.slice(0, -1))
            )
        }
        this.editor.decorateMarker(marker, {type: "overlay", item: messageBubble, position: "tail"})
    }

    findFileDiffs() {
        var repo = atom.project.getRepo()
        var activePath = atom.workspace.getActiveEditor().getPath()
        var fileRepo = repo.getRepo(activePath)
        var activeEditorText = atom.workspace.getActiveEditor().getBuffer().getText()
        return fileRepo.getLineDiffDetails(repo.relativize(activePath), activeEditorText)
    }

    private findDiffForLine(lineNumber) {
        var fileDiffs = this.findFileDiffs()
        var lineDiff = {}
        fileDiffs.forEach((diff) => {
            if ((diff.newLineNumber === lineNumber) || (diff.newLineNumber === -1 && diff.oldLineNumber === (lineNumber + 1))) {
                lineDiff = diff
            }
        })
        return lineDiff
    }

    calculateDiffDetails(lineNumber) {
        var fileDiffs = this.findFileDiffs()
        var index = 0
        var newDiff = this.findDiffForLine(lineNumber)
        for (var c = 0; c < fileDiffs.length; c++) {
            var diff = fileDiffs[c]
            var lines = 0
            var originalEnd = diff.oldStart + diff.oldLines - 1
            originalEnd = originalEnd < 1 ? 1 : originalEnd
            var newEnd = diff.newStart + diff.newLines - 1
            var content = ""
            if (diff.oldLineNumber === newDiff.oldStart) {
                var capture = index + diff.oldLines
                for (var i = index; i < capture; i++) {
                    var thisDiff = fileDiffs[i]
                    content += thisDiff.line
                }
                return {
                    isRemoving: diff.newLines === 0,
                    originalStart: diff.oldStart,
                    originalEnd: originalEnd,
                    newStart: diff.newStart,
                    newEnd: newEnd,
                    newLines: diff.newLines,
                    originalContent: content
                }
            } else if (diff.oldLineNumber === -1 && diff.newLineNumber === lineNumber) {
                return {
                    isAdding: true,
                    originalStart: diff.oldStart,
                    originalEnd: originalEnd,
                    newStart: diff.newStart,
                    newEnd: newEnd,
                    newLines: diff.newLines,
                    originalContent: content
                }
            }

            index++
        }

        return {}
    }
}

class MessageBubble extends View {
    private message: string
    private revert: () => void

    constructor(message, revert) {
		super(message)
        this.message = message
        this.revert = revert
    }

    private countLeadingSpaces(str): number {
        var count = 0
        var chars = str.split("")
        for (var i = 0; i < chars.length; i++) {
            if (chars[i] === " ") {
                count++
            } else {
                break
            }
        }
        return count
    }

    private buildStringOfSpaces(len): string {
        var str = ""
        for (var i = 0; i < len; i++) {
            str += "_"
        }
        return str
    }

    private removeView(): void {
        this.remove()
    }

    private revertAndClose(): void {
        this.revert()
        this.removeView()
    }

    private copyToClipboard(): void {
        atom.clipboard.write(this.message.trim())
        atom.notifications.addSuccess("Copied to clipboard")
    }

    static content(message): void {
        var isRemoval = message.length === 0
        if (isRemoval) {
            message = "(Remove new lines)"
        }
        this.div({class: "select-list popover-list linter-list"}, () => {
            this.ul({class: "list-group"}, () => {
                var lines = message.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    this.li(() => {
                        this.span({class: "empty-space"}, "foo bar")
                        this.span(lines[i])
                    })
                }
            })
            this.div({class: "action-buttons"}, () => {
                this.button({click: "removeView", class: "btn btn-success diff-button"}, "Close")
                if (!isRemoval) {
                    this.button({click: "copyToClipboard", class: "btn btn-primary diff-button"}, "Copy")
                }
                this.button({click: "revertAndClose", class: "btn btn-warning diff-button"}, "Revert")
            })
        })
    }
}

module.exports = LineDiffWorker
