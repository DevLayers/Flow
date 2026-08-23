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
    
    onListChanged: {
        const newList = list;
        const startTime = Date.now();
        root.preparedEntries = newList.map(a => ({
            name: Fuzzy.prepare(`${a}`),
            entry: a
        }));
        console.log(`[Emojis] Prepared ${root.preparedEntries.length} entries in ${Date.now() - startTime}ms`)
    }
    
    function fuzzyQuery(search: string): var {
        if (!search || search.trim() === "") {
            return root.list;
        }
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

        return Fuzzy.go(search, preparedEntries, {
            limit: 100,
            key: "name"
        }).map(r => {
            return r.obj.entry
        });
    }

    function load() {
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
        root.entries = root.list.map(raw => ({
            raw,
            emoji: raw.match(/^\s*(\S+)/)?.[1] ?? "",
            name: raw.replace(/^\s*\S+\s+/, ""),
            category: root.categoryFor(raw)
        }))
        console.log(`[Emojis] Loaded ${root.list.length} emojis`)
    }

    FileView { 
        id: emojiFileView
        path: Qt.resolvedUrl(root.emojiScriptPath)
        onLoadedChanged: {
            const fileContent = emojiFileView.text()
            root.updateEmojis(fileContent)
        }
    }
}
