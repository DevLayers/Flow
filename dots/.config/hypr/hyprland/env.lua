local home_dir = os.getenv("HOME")

-- Enforce local binary directory precedence for session
hl.env("PATH", home_dir .. "/.local/bin:" .. os.getenv("PATH"))

-- Wayland
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Applications
hl.env("XDG_DATA_DIRS",
    home_dir ..
    "/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share:$XDG_DATA_DIRS")

-- Cursor theme
hl.env("XCURSOR_THEME", "Vimix-cursors")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Vimix-cursors")
hl.env("HYPRCURSOR_SIZE", "24")

-- Themes
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("XDG_MENU_PREFIX", "plasma-")

-- Virtual environment
hl.env("ILLOGICAL_IMPULSE_VIRTUAL_ENV", home_dir .. "/.local/state/quickshell/.venv")
