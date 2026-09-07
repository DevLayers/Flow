# 45-zsh-edit-select.zsh — Selection, clipboard, undo/redo via zsh-edit-select
# DISABLED. The upstream repo (Michael-Matta1/zsh-edit-select) is a 25-star
# single-maintainer fork with auto-clone-from-fork behaviour that was a
# silent maintenance liability. We removed the auto-clone path entirely.
#
# If you need the features (Shift-select, OSC52 clipboard, undo/redo),
# vendor the source into your plugin snapshot manually and source it here.
# Otherwise rely on:
#   - Terminal-level Shift-Arrow Copy (kitty/foot/wezterm/alacritty)
#   - Ctrl-Shift-C / Ctrl-Shift-V paste in most terminals
#   - `wl-copy` / `xclip` for explicit clipboard ops

return 0
