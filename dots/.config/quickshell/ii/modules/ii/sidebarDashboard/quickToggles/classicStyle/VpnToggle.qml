import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs
import QtQuick

QuickToggleButton {
    visible: (Config.options?.vpn?.enabled ?? true) && (Config.options?.vpn?.showInQuickToggles ?? true)
    enabled: (Config.options?.vpn?.enabled ?? true) && VpnService.available
    toggled: VpnService.displayActive
    buttonIcon: VpnService.displayActive ? "key" : (VpnService.errorMessage ? "error" : "vpn_key")
    onClicked: {
        if (Config.options?.vpn?.enabled ?? true)
            VpnService.toggleVpn()
    }
    StyledToolTip {
        text: Translation.tr("VPN: %1 | Right-click for options").arg(VpnService.statusText)
    }
}
