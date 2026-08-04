import QtQuick
import qs.services
import qs.modules.common

QuickToggleModel {
    id: root
    name: Translation.tr("VPN")

    available: (Config.options?.vpn?.enabled ?? true) && VpnService.available
    toggled: (Config.options?.vpn?.enabled ?? true) && VpnService.displayActive
    tooltipText: (Config.options?.vpn?.enabled ?? true)
        ? Translation.tr("VPN Connection: %1 | Right-click to manage profiles").arg(statusText)
        : Translation.tr("VPN is disabled in Privacy settings")
    icon: VpnService.displayActive ? "key" : (VpnService.errorMessage ? "error" : "vpn_key")
    hasMenu: true

    mainAction: () => {
        if (Config.options?.vpn?.enabled ?? true)
            VpnService.toggleVpn()
    }
}
