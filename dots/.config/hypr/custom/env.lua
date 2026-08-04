-- Nvidia Environment Variables
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

-- Electron applications fix
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Cursor theme
hl.env("XCURSOR_THEME", "Vimix-cursors")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Vimix-cursors")
hl.env("HYPRCURSOR_SIZE", "24")

-- QT Platform Theme
-- hl.env("QT_QPA_PLATFORMTHEME", "qt5ct") -- Must be "kde" for Dolphin and KDE Matugen colors

