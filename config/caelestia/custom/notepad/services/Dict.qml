pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Offline dictionary lookup via sdcv (StarDict console viewer).
//
// Offline on purpose: lookups are instant, work with no network, and never leave
// the machine. Needs the client and a dictionary:
//   yay -S --needed sdcv stardict-wordnet
//
// `sh -c` with a `command -v` guard rather than running sdcv directly, so a
// missing binary reports cleanly instead of spewing a Process warning -- the same
// trick caelestia uses for its optional asdbctl probe.
Singleton {
    id: root

    property string word
    property string result
    property bool busy
    property bool installed: true

    // Structured form of `result`, for the formatted view:
    //   [{ pos: "noun", senses: [{ n, text, examples: [] }] }]
    property var entries: []

    // WordNet tags parts of speech with a single letter and carries no phonetics,
    // so the [pronunciation] slot stays empty unless a richer dictionary supplies
    // one. Everything else in the reference layout comes straight out of it.
    readonly property var posNames: ({
            n: "noun",
            v: "verb",
            adj: "adjective",
            adv: "adverb",
            a: "adjective",
            s: "adjective",
            r: "adverb"
        })

    function parse(raw: string): void {
        const out = [];
        let group = null;
        let sense = null;

        const flush = () => {
            if (!sense || !group)
                return;
            // Examples are the quoted runs; synonyms are noise here.
            const examples = [];
            let text = sense.text.replace(/\[syn:[^\]]*\]/g, "").replace(/\{|\}/g, "");
            text = text.replace(/"([^"]+)"/g, (m, q) => {
                examples.push(q);
                return "";
            });
            sense.text = text.replace(/\s+/g, " ").replace(/[;,\s]+$/, "").trim();
            sense.examples = examples;
            if (sense.text)
                group.senses.push(sense);
            sense = null;
        };

        for (const line of raw.split("\n")) {
            if (!line.trim() || line.startsWith("-->") || /^Found \d+ items?/i.test(line))
                continue;

            // "  n 1: definition"  or  "  2: definition"
            const m = line.match(/^\s+(?:([a-z]+)\s+)?(\d+):\s*(.*)$/);
            if (m) {
                flush();
                if (m[1]) {
                    group = {
                        pos: root.posNames[m[1]] ?? m[1],
                        senses: []
                    };
                    out.push(group);
                } else if (!group) {
                    group = {
                        pos: "",
                        senses: []
                    };
                    out.push(group);
                }
                sense = {
                    n: parseInt(m[2]),
                    text: m[3],
                    examples: []
                };
            } else if (sense) {
                // Wrapped continuation of the sense above.
                sense.text += " " + line.trim();
            }
        }
        flush();

        root.entries = out.filter(g => g.senses.length);
    }

    // Debounced so typing does not spawn a process per keystroke.
    function lookup(w: string): void {
        root.word = w.trim();
        if (!root.word) {
            root.result = "";
            root.entries = [];
            debounce.stop();
            return;
        }
        debounce.restart();
    }

    Timer {
        id: debounce

        interval: 250
        onTriggered: {
            root.busy = true;
            proc.running = false;
            proc.running = true;
        }
    }

    Process {
        id: proc

        // -n: no interactive prompt. -0/-1 keep output plain.
        command: ["sh", "-c", `command -v sdcv >/dev/null || { echo __NOSDCV__; exit 0; }; sdcv -n --utf8-output ${JSON.stringify(root.word)}`]

        stdout: StdioCollector {
            onStreamFinished: {
                root.busy = false;
                const out = text.trim();
                if (out === "__NOSDCV__") {
                    root.installed = false;
                    root.result = "";
                    return;
                }
                root.installed = true;
                // sdcv prints "Found N items, similar to X." then the entries.
                root.result = out.replace(/^Found \d+ items?, similar to .*?\.\n?/i, "").trim();
                root.parse(root.result);
            }
        }
    }
}
