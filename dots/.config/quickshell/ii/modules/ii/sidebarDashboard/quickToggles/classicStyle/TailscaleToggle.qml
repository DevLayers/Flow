import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs
import QtQuick

QuickToggleButton {
    visible: (Config.options?.tailscale?.enabled ?? true) && (Config.options?.tailscale?.showInQuickToggles ?? true)
    enabled: (Config.options?.tailscale?.enabled ?? true) && TailscaleService.available
    toggled: TailscaleService.active
    buttonIcon: TailscaleService.active ? "hub" : (TailscaleService.backendState === "NeedsLogin" ? "key" : "vpn_lock")
    onClicked: {
        if (Config.options?.tailscale?.enabled ?? true)
            TailscaleService.toggleTailscale()
    }
    StyledToolTip {
        text: Translation.tr("Tailscale: %1 | Right-click for options").arg(TailscaleService.statusText)
    }
}
