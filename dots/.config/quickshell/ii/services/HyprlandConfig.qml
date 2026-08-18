pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root
    signal reloaded()
    readonly property string configuratorScriptPath: Quickshell.shellPath("scripts/hyprland/hyprconfigurator.py")
    readonly property string shellOverridesPath: FileUtils.trimFileProtocol(`${Directories.config}/hypr/hyprland/shellOverrides/main.lua`)

    function set(key: string, value: var) {
        Quickshell.execDetached(["bash", "-c", `${root.configuratorScriptPath} --file ${root.shellOverridesPath} --set "${key}" "${value}"`])
    }
    function setMany(entries: var, extras: var) {
        let args = ""
        for (let key in entries) args += `--set "${key}" "${entries[key]}" `
        args += root._extraArgs(extras)
        Quickshell.execDetached(["bash", "-c", `${root.configuratorScriptPath} --file ${root.shellOverridesPath} ${args}`])
    }
    function reset(key: string) {
        Quickshell.execDetached(["bash", "-c", `${root.configuratorScriptPath} --file ${root.shellOverridesPath} --reset "${key}"`])
    }
    function resetMany(keys: list<string>, extras: var) {
        let args = ""
        for (let i = 0; i < keys.length; i++) args += `--reset "${keys[i]}" `
        args += root._extraArgs(extras)
        Quickshell.execDetached(["bash", "-c", `${root.configuratorScriptPath} --file ${root.shellOverridesPath} ${args}`])
    }
    function _extraArgs(extras: var): string {
        if (!extras) return ""
        let args = ""
        const addLines = extras.addLines ?? []
        const removeMatching = extras.removeMatching ?? []
        for (let i = 0; i < addLines.length; i++)
            args += `--add-line ${root._shellQuote(addLines[i])} `
        for (let i = 0; i < removeMatching.length; i++)
            args += `--remove-matching ${root._shellQuote(removeMatching[i])} `
        return args
    }
    function _shellQuote(value: string): string {
        return `'${String(value).replace(/'/g, `'\\''`)}'`
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) { if (event.name == "configreloaded") root.reloaded() }
    }
}
