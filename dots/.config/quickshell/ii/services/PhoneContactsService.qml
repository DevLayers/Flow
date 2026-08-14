pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions
import qs.services

Singleton {
    id: root

    property bool available: false
    property bool ready: false
    property string sourcePath: ""
    property string lastError: ""

    Connections {
        target: KdeConnectService
        ignoreUnknownSignals: true
        function onActiveDeviceIdChanged() {
            root.refresh()
        }
    }

    property var contacts: []
    property string searchQuery: ""
    property var filteredContacts: []

    readonly property int count: contacts ? contacts.length : 0
    // Contacts dropped by the nameless filter, so the UI can say why the list is short
    property int hiddenCount: 0

    readonly property bool hideUnnamed: Config.options?.phone?.contacts?.hideUnnamed ?? true
    onHideUnnamedChanged: root._updateFilteredContacts()

    function refresh(): void {
        if (monitorProcess.running) {
            monitorProcess.running = false
            monitorProcess.running = true
        }
    }

    function setSearchQuery(query: string): void {
        root.searchQuery = query
        root._updateFilteredContacts()
    }

    function contactById(id: string): var {
        if (!contacts) return null
        for (let i = 0; i < contacts.length; i++) {
            if (contacts[i].id === id) return contacts[i]
        }
        return null
    }

    function copyPhone(number: string): void {
        if (!number) return
        Quickshell.clipboardText = number
        KdeConnectService.dispatchActionFeedback(Translation.tr("Phone number copied"), true)
    }

    function openDialer(number: string): void {
        if (!number) return
        if (!KdeConnectService.activeReachable) {
            KdeConnectService.dispatchActionFeedback(Translation.tr("Phone is not connected or reachable"), false)
            return
        }
        if (!KdeConnectService.adbReachable) {
            KdeConnectService.dispatchActionFeedback(Translation.tr("ADB is not reachable. Enable Wireless Debugging / USB Debugging."), false)
            return
        }
        const encoded = encodeURIComponent(number)
        const targetSerial = KdeConnectService.resolvedAdbSerial || ""
        let cmd = ["adb"]
        if (targetSerial) {
            cmd.push("-s", targetSerial)
        }
        cmd.push("shell", "am", "start", "-a", "android.intent.action.DIAL", "-d", "tel:" + encoded)
        Quickshell.execDetached(cmd)
        KdeConnectService.dispatchActionFeedback(Translation.tr("Opening dialer for %1…").arg(number), true)
    }

    function composeSms(number: string): void {
        if (!number) return
        if (!KdeConnectService.activeReachable) {
            KdeConnectService.dispatchActionFeedback(Translation.tr("Phone is not connected or reachable"), false)
            return
        }
        if (!KdeConnectService.adbReachable) {
            KdeConnectService.dispatchActionFeedback(Translation.tr("ADB is not reachable. Enable Wireless Debugging / USB Debugging."), false)
            return
        }
        const encoded = encodeURIComponent(number)
        const targetSerial = KdeConnectService.resolvedAdbSerial || ""
        let cmd = ["adb"]
        if (targetSerial) {
            cmd.push("-s", targetSerial)
        }
        cmd.push("shell", "am", "start", "-a", "android.intent.action.SENDTO", "-d", "sms:" + encoded)
        Quickshell.execDetached(cmd)
        KdeConnectService.dispatchActionFeedback(Translation.tr("Opening SMS for %1…").arg(number), true)
    }

    function toggleFavorite(contactId: string): void {
        if (!contactId) return
        let currentFavs = (Config.options?.phone?.contacts?.favoriteIds || []).slice()
        const idx = currentFavs.indexOf(contactId)
        if (idx >= 0) {
            currentFavs.splice(idx, 1)
        } else {
            currentFavs.push(contactId)
        }
        Config.options.phone.contacts.favoriteIds = currentFavs
        root._updateFilteredContacts()
    }

    function isFavorite(contactId: string): bool {
        if (!contactId) return false
        const favs = Config.options?.phone?.contacts?.favoriteIds || []
        return favs.indexOf(contactId) >= 0
    }

    // A contact is nameless when the vCard had no name, organization, or any
    // other human-readable field — only a number. Favorites are always kept:
    // starring one is an explicit statement that it matters.
    function _isNameless(contact: var): bool {
        if (!contact || contact.nameless !== true) return false
        return !root.isFavorite(contact.id)
    }

    function _updateFilteredContacts(): void {
        if (!contacts) {
            filteredContacts = []
            root.hiddenCount = 0
            return
        }
        const base = root.hideUnnamed ? contacts.filter(c => !root._isNameless(c)) : contacts
        root.hiddenCount = contacts.length - base.length

        const q = searchQuery.trim().toLowerCase()
        if (!q) {
            filteredContacts = base
            return
        }
        const cleanQ = q.replace(/[\s\-\(\)\.]/g, "")
        filteredContacts = base.filter(c => {
            if (!c) return false
            if (c.displayName && c.displayName.toLowerCase().includes(q)) return true
            if (c.organization && c.organization.toLowerCase().includes(q)) return true

            if (c.phones) {
                for (let i = 0; i < c.phones.length; i++) {
                    const p = c.phones[i]
                    if (p.value && p.value.toLowerCase().includes(q)) return true
                    if (p.normalized && cleanQ && p.normalized.includes(cleanQ)) return true
                }
            }
            if (c.emails) {
                for (let i = 0; i < c.emails.length; i++) {
                    if (c.emails[i].value && c.emails[i].value.toLowerCase().includes(q)) return true
                }
            }
            return false
        })
    }

    onContactsChanged: root._updateFilteredContacts()

    IpcHandler {
        target: "phoneContacts"
        function refresh() {
            root.refresh()
        }
        function search(query: string) {
            root.setSearchQuery(query)
        }
    }

    Process {
        id: monitorProcess
        command: ProcUtils.pdeath([
            "python3",
            Quickshell.shellPath("scripts/kdeconnect/contacts_monitor.py"),
            "--device", KdeConnectService.activeDeviceId || ""
        ])
        running: Config.options?.phone?.contacts?.enabled ?? true

        stdout: SplitParser {
            onRead: data => {
                try {
                    const msg = JSON.parse(data)
                    if (msg.event === "ready") {
                        root.available = true
                        root.ready = true
                        root.sourcePath = msg.sourcePath || ""
                        root.lastError = ""
                    } else if (msg.event === "snapshot") {
                        root.contacts = msg.contacts || []
                    } else if (msg.event === "error") {
                        root.lastError = msg.message || "Unknown contacts error"
                        if (msg.code === "no_contact_source") {
                            root.ready = false
                        }
                    }
                } catch (e) {
                    console.warn("[PhoneContactsService] JSON parse error:", e, "Line:", data)
                }
            }
        }

        stderr: SplitParser {
            onRead: data => {
                if (data.trim().length > 0) {
                    console.warn("[PhoneContactsService stderr]", data)
                }
            }
        }
    }
}
