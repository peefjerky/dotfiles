pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The note buffer, its autosave, and the timestamped export.
//
// Lives as a singleton rather than inside the window so it survives the overlay's
// LazyLoader teardown: closing the notepad destroys the UI, and the buffer and any
// in-flight write have to outlive that.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string dataDir: `${home}/.local/share/caelestia-notepad`
    readonly property string scratchPath: `${dataDir}/scratch.md`
    readonly property string exportDir: `${home}/Documents/Notes`

    property string content
    // Guards the autosave so the initial disk read doesn't immediately write back.
    property bool loaded

    // True between our own setText() and its onSaved. FileView.watchChanges fires
    // fileChanged for *our* writes too, and reloading there would re-read the file
    // we just wrote -- which at best is wasted I/O and at worst stomps a newer
    // in-memory edit with stale disk text if the user typed during the round trip.
    // Cleared on saved/saveFailed rather than straight after setText(), because the
    // write is asynchronous and only those signals correspond to it completing.
    property bool writingOwnChange

    property string pendingExportPath

    signal exported(path: string)
    signal exportFailed(reason: string)

    onContentChanged: if (loaded) saveTimer.restart()

    function exportSnapshot(): void {
        root.pendingExportPath = `${root.exportDir}/${Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss")}.md`;
        mkdirExport.running = true;
    }

    // Debounce: settle for 800ms of no typing, then write once.
    Timer {
        id: saveTimer

        interval: 800
        onTriggered: {
            root.writingOwnChange = true;
            scratch.setText(root.content);
        }
    }

    Process {
        running: true
        command: ["mkdir", "-p", root.dataDir]
    }

    FileView {
        id: scratch

        path: root.scratchPath
        watchChanges: true
        atomicWrites: true
        // A missing scratch file on first run is the normal case, not an error.
        printErrors: false

        onLoaded: {
            if (!root.writingOwnChange)
                root.content = text();
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
        onFileChanged: if (!root.writingOwnChange) reload()
        onSaved: root.writingOwnChange = false
        onSaveFailed: root.writingOwnChange = false
    }

    // FileView.setText() does not create parent directories -- it just fails with
    // saveFailed -- so the directory has to exist first. Process (not execDetached)
    // because we need the completion signal to sequence the write after the mkdir;
    // execDetached is fire-and-forget and the write would race it.
    Process {
        id: mkdirExport

        command: ["mkdir", "-p", root.exportDir]
        onExited: code => {
            if (code === 0) {
                exportFile.path = root.pendingExportPath;
                exportFile.setText(root.content);
            } else {
                root.exportFailed(`could not create ${root.exportDir}`);
            }
        }
    }

    FileView {
        id: exportFile

        // Nothing to read -- the path is always a new file.
        preload: false
        printErrors: false
        atomicWrites: true

        onSaved: root.exported(root.pendingExportPath)
        onSaveFailed: root.exportFailed("write failed")
    }
}
