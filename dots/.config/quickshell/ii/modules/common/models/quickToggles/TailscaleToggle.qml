import QtQuick
import qs.services
import qs.modules.common

QuickToggleModel {
    id: root
    name: Translation.tr("Tailscale")

    available: (Config.options?.tailscale?.enabled ?? true) && TailscaleService.available
    toggled: (Config.options?.tailscale?.enabled ?? true) && TailscaleService.active
    statusText: (Config.options?.tailscale?.enabled ?? true) ? TailscaleService.statusText : Translation.tr("Disabled")
    tooltipText: Translation.tr("Tailscale Mesh: %1 | Right-click for network peers & exit nodes").arg(statusText)
    icon: TailscaleService.active ? "hub" : (TailscaleService.backendState === "NeedsLogin" ? "key" : "vpn_lock")
    hasMenu: true

    mainAction: () => {
        if (Config.options?.tailscale?.enabled ?? true)
            TailscaleService.toggleTailscale()
    }
}
