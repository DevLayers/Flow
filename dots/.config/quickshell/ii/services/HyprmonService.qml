pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.services

Singleton {
    id: root

    property var profiles: []
    property bool isApplying: applyProfileProc.running || saveProfileProc.running

    signal profilesUpdated()
    signal profileApplied(string name)

    Component.onCompleted: {
        reloadProfiles();
    }

    function reloadProfiles() {
        profilesProc.running = true;
    }

    function buildProfileJson(name, monitorsList) {
        if (!monitorsList || monitorsList.length === 0)
            return "{}";

        const profile = {
            name: name,
            monitors: monitorsList.map(m => ({
                name: m.name,
                make: "",
                model: m.description || "",
                PxW: m.width,
                PxH: m.height,
                Hz: m.refreshRate,
                Scale: m.scale !== undefined ? m.scale : 1.0,
                X: m.x !== undefined ? m.x : 0,
                Y: m.y !== undefined ? m.y : 0,
                Active: !m.disabled,
                BitDepth: m.bitDepth || 8,
                ColorMode: m.colorManagementPreset || "srgb",
                SDRBrightness: m.sdrBrightness !== undefined ? m.sdrBrightness : 1.0,
                SDRSaturation: m.sdrSaturation !== undefined ? m.sdrSaturation : 1.0,
                VRR: m.vrr || 0,
                Transform: m.transform || 0,
                IsMirrored: Boolean(m.mirrorOf && m.mirrorOf !== "none" && m.mirrorOf !== ""),
                MirrorSource: (m.mirrorOf && m.mirrorOf !== "none") ? m.mirrorOf : ""
            })),
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString()
        };
        return JSON.stringify(profile, null, 2);
    }

    function saveProfile(name, monitorsList) {
        if (!name || !monitorsList || monitorsList.length === 0)
            return;
        const jsonStr = buildProfileJson(name, monitorsList);
        saveProfileProc.command = [
            "bash", "-c",
            "mkdir -p ~/.config/hyprmon/profiles && cat << 'EOF' > ~/.config/hyprmon/profiles/\"$1\".json\n" + jsonStr + "\nEOF",
            "--", name
        ];
        saveProfileProc.running = true;
    }

    function saveAndApplyProfile(name, monitorsList) {
        if (!name || !monitorsList || monitorsList.length === 0)
            return;
        const jsonStr = buildProfileJson(name, monitorsList);
        saveAndApplyProc.command = [
            "bash", "-c",
            "mkdir -p ~/.config/hyprmon/profiles && cat << 'EOF' > ~/.config/hyprmon/profiles/\"$1\".json\n" + jsonStr + "\nEOF\nhyprmon -profile \"$1\" && mkdir -p ~/.config/hypr/hyprmon_backups && mv ~/.config/hypr/*.bak.* ~/.config/hypr/hyprmon_backups/ 2>/dev/null || true; ls -t ~/.config/hypr/hyprmon_backups/*.bak.* 2>/dev/null | tail -n +21 | xargs rm -f 2>/dev/null || true",
            "--", name
        ];
        saveAndApplyProc.running = true;
    }

    function applyProfile(name) {
        if (!name)
            return;
        applyProfileProc.command = [
            "bash", "-c",
            "hyprmon -profile \"$1\" && mkdir -p ~/.config/hypr/hyprmon_backups && mv ~/.config/hypr/*.bak.* ~/.config/hypr/hyprmon_backups/ 2>/dev/null || true; ls -t ~/.config/hypr/hyprmon_backups/*.bak.* 2>/dev/null | tail -n +21 | xargs rm -f 2>/dev/null || true",
            "--", name
        ];
        applyProfileProc.running = true;
    }

    function deleteProfile(name) {
        if (!name)
            return;
        deleteProfileProc.command = [
            "bash", "-c",
            "rm -f ~/.config/hyprmon/profiles/\"$1\".json",
            "--", name
        ];
        deleteProfileProc.running = true;
    }

    function profileExists(name) {
        if (!root.profiles || root.profiles.length === 0)
            return false;
        return root.profiles.some(p => p.name === name);
    }

    // ── Processes ───────────────────────────────────────────────────────────
    Process {
        id: profilesProc
        command: ["hyprmon", "-list-profiles"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let lines = text.trim().split("\n").filter(l => l.length > 0);
                    let plist = lines.map(line => {
                        let isA = line.endsWith(" *");
                        let name = isA ? line.substring(0, line.length - 2) : line;
                        return {
                            name: name,
                            isActive: isA
                        };
                    }).filter(p => p.name !== "__quickshell_live__");
                    root.profiles = plist;
                    root.profilesUpdated();
                } catch (e) {
                    console.log("[HyprmonService] Error reading profiles:", e);
                }
            }
        }
    }

    Process {
        id: applyProfileProc
        onRunningChanged: if (!running) {
            root.reloadProfiles();
        }
    }

    Process {
        id: saveProfileProc
        onRunningChanged: if (!running) {
            root.reloadProfiles();
        }
    }

    Process {
        id: saveAndApplyProc
        onRunningChanged: if (!running) {
            root.reloadProfiles();
        }
    }

    Process {
        id: deleteProfileProc
        onRunningChanged: if (!running) {
            root.reloadProfiles();
        }
    }
}
