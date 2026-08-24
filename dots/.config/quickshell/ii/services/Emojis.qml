pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Emojis.
 */
Singleton {
    id: root
    property string emojiScriptPath: `${Directories.config}/hypr/hyprland/scripts/fuzzel-emoji.sh`
	property string lineBeforeData: "### DATA ###"
    property bool levenshteinSearch: (Config.options?.search.levenshtein ?? false) || (Config.options?.search.algorithm === "levenshtein")
    property list<var> list
    // Keep the legacy string list for existing fuzzy consumers, and expose
    // structured entries for the Search panel's category grid.
    property list<var> entries
    property var preparedEntries: []
    property bool loaded: false
    property bool loading: false
    property bool entriesPrepared: false
    property bool entriesPreparing: false
    property int preparationIndex: 0
    property var preparationBuffer: []
    property int structureIndex: 0
    property var structureBuffer: []
    
    onListChanged: {
        preparationTimer.stop();
        root.entriesPrepared = false;
        // Building the fuzzy index is much more expensive than displaying a
        // virtualized grid. Keep opening the panel cheap and start indexing
        // only after the user actually types a query.
        root.entriesPreparing = false;
        root.preparationIndex = 0;
        root.preparationBuffer = [];
    }

    function ensurePrepared(): void {
        if (root.entriesPrepared || root.entriesPreparing || root.list.length === 0)
            return;
        root.entriesPreparing = true;
        root.preparationIndex = 0;
        root.preparationBuffer = [];
        preparationTimer.restart();
    }
    
    function fuzzyQuery(search: string): var {
        if (!search || search.trim() === "") {
            return root.list;
        }
        root.ensurePrepared();
        if (root.levenshteinSearch) {
            const threshold = Config.options?.search.scoreThreshold ?? 0.2;
            const results = root.list.slice(0, 100).map(str => ({
                entry: str,
                score: Levendist.computeTextMatchScore(str.toLowerCase(), search.toLowerCase())
            })).filter(item => item.score > threshold)
                .sort((a, b) => b.score - a.score)
            return results
                .map(item => item.entry)
        }

        // The panel remains immediately usable while the fuzzy index is built
        // in short event-loop batches. This fallback is deliberately bounded
        // and is replaced by the ranked matcher as soon as it is ready.
        if (!root.entriesPrepared) {
            const normalized = search.toLocaleLowerCase();
            return root.list.filter(entry => String(entry).toLocaleLowerCase().includes(normalized))
                .slice(0, 100);
        }

        return Fuzzy.go(search, preparedEntries, {
            limit: 100,
            key: "name"
        }).map(r => {
            return r.obj.entry
        });
    }

    function load() {
        if (root.loaded || root.loading)
            return;
        root.loading = true;
        emojiFileView.reload()
    }

    function categoryFor(entry: string): string {
        const text = String(entry ?? "").toLowerCase();
        if (/(face|heart|emotion|kiss|cat|monkey|skull|ghost|alien|robot)/.test(text)) return "people";
        if (/(hand|person|woman|man|baby|body|gesture|thumb|fist|leg|ear|eye|mouth)/.test(text)) return "people";
        if (/(animal|plant|flower|tree|nature|weather|moon|sun|earth|water|fire)/.test(text)) return "nature";
        if (/(food|drink|fruit|vegetable|meat|bread|cake|coffee|beer|wine)/.test(text)) return "food";
        if (/(symbol|arrow|number|letter|sign|flag|keycap|button|warning|check)/.test(text)) return "symbols";
        return "objects";
    }

    function entryFor(raw: string): var {
        return root.entries.find(entry => entry.raw === raw) ?? null;
    }

    function updateEmojis(fileContent) {
        const lines = fileContent.split("\n")
        const dataIndex = lines.indexOf(root.lineBeforeData)
        if (dataIndex === -1) {
            console.warn("No data section found in emoji script file.")
            return
        }
        const emojis = lines.slice(dataIndex + 1).filter(line => line.trim() !== "")
        root.list = emojis.map(line => line.trim())
        root.entries = [];
        root.structureIndex = 0;
        root.structureBuffer = [];
        structureTimer.restart();
    }

    FileView { 
        id: emojiFileView
        path: Qt.resolvedUrl(root.emojiScriptPath)
        onLoaded: {
            const fileContent = emojiFileView.text()
            root.updateEmojis(fileContent)
        }
    }

    Timer {
        id: structureTimer
        interval: 0
        repeat: false
        onTriggered: {
            const batchSize = 96;
            const end = Math.min(root.list.length, root.structureIndex + batchSize);
            for (let index = root.structureIndex; index < end; index++) {
                const raw = root.list[index];
                root.structureBuffer.push({
                    raw: raw,
                    emoji: raw.match(/^\s*(\S+)/)?.[1] ?? "",
                    name: raw.replace(/^\s*\S+\s+/, ""),
                    category: root.categoryFor(raw)
                });
            }
            root.structureIndex = end;
            if (root.structureIndex < root.list.length) {
                structureTimer.restart();
                return;
            }
            root.entries = root.structureBuffer;
            root.structureBuffer = [];
            root.loaded = true;
            root.loading = false;
            console.log(`[Emojis] Loaded ${root.entries.length} emojis incrementally`);
        }
    }

    Timer {
        id: preparationTimer
        interval: 16
        repeat: false
        onTriggered: {
            if (!root.entriesPreparing)
                return;

            const batchSize = 48;
            const end = Math.min(root.list.length, root.preparationIndex + batchSize);
            for (let index = root.preparationIndex; index < end; index++) {
                const entry = root.list[index];
                root.preparationBuffer.push({
                    name: Fuzzy.prepare(`${entry}`),
                    entry: entry
                });
            }
            root.preparationIndex = end;

            if (root.preparationIndex >= root.list.length) {
                root.preparedEntries = root.preparationBuffer;
                root.preparationBuffer = [];
                root.entriesPreparing = false;
                root.entriesPrepared = true;
                console.log(`[Emojis] Prepared ${root.preparedEntries.length} entries incrementally`);
                return;
            }
            preparationTimer.restart();
        }
    }
}
