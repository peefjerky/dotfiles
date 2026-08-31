pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config

// Git repos under ~/Projects, with their dirty counts.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string dir: `${root.home}/Projects`

    // [{ path, name, group, dirty }]
    property var repos: []
    property bool busy

    function refresh(): void {
        root.busy = true;
        scan.running = false;
        scan.running = true;
    }

    // Follows caelestia's configured terminal (Settings > Apps) rather than
    // hardcoding one -- same spread idiom as launcher/items/CalcItem.qml:81.
    // workingDirectory instead of a `--directory` flag because that flag is
    // kitty-specific; cwd is inherited by every terminal.
    function terminal(path: string): void {
        Quickshell.execDetached({
            command: [...GlobalConfig.general.apps.terminal],
            workingDirectory: path
        });
    }

    function reveal(path: string): void {
        Quickshell.execDetached(["xdg-open", path]);
    }

    Process {
        id: scan

        // One pass: find the repos, then ask each for its porcelain count. 17 repos
        // is a few milliseconds, and it only runs when the tab is opened.
        command: ["sh", "-c", `fd -H -t d -d 5 '^\\.git$' ${JSON.stringify(root.dir)} -x dirname 2>/dev/null | sort | while read -r d; do printf '%s\\t%s\\n' "$d" "$(git -C "$d" status --porcelain 2>/dev/null | wc -l)"; done`]

        stdout: StdioCollector {
            onStreamFinished: {
                root.busy = false;
                root.repos = text.split("\n").filter(l => l.length).map(l => {
                    const tab = l.lastIndexOf("\t");
                    const path = l.slice(0, tab);
                    const rel = path.replace(`${root.dir}/`, "");
                    const cut = rel.lastIndexOf("/");
                    return {
                        path: path,
                        name: cut < 0 ? rel : rel.slice(cut + 1),
                        group: cut < 0 ? "" : rel.slice(0, cut),
                        dirty: parseInt(l.slice(tab + 1)) || 0
                    };
                });
            }
        }
    }
}
