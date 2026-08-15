# [ Quickshell/II ]

Premium Material 3 / Material You dotfiles for Hyprland, powered by Quickshell.

## System Preview

<img width="1966" height="1137" alt="Frame 178" src="https://github.com/user-attachments/assets/82761533-92bc-4e9a-9805-3d6945d46d36" />

## Overview

This repository is a heavily customized fork of **[ii-vynx](https://github.com/vaguesyntax/ii-vynx)**, which itself is based on **[illogical-impulse](https://github.com/end-4/dots-hyprland)**. **This is my personal customization. It's not focused on performance or stability — if you use it, expect a lot of bugs.** If you find one, please open an issue or report it in the ii-p3drovfx thread inside **[end-4 discord](https://discord.gg/GtdRBXgMwq)**. I also accept PRs.

It aims to provide a state-of-the-art Linux desktop experience by strictly adhering to **Material 3 (Material You)** design principles, featuring dynamic theming via Matugen and a highly modular architecture built on **Quickshell**.

> [!NOTE]
> This repository is a work in progress. Some modules, like the Gmail client, require manual setup of API keys.

## Requirements

- **Hyprland 0.56.1 or newer**
- **Matugen 4.1.0 or newer**

> [!NOTE]
> Matugen **4.1.0+ is the supported/recommended version**. The lightweight scheme-switching path still detects Matugen 3 and avoids the Matugen 4-only `--source-color-index` option so an older installation fails gracefully instead of breaking scheme changes. On Fedora, the installer enables `avengemedia/danklinux` to source the current Matugen package.

## Installation

### Default installation

Use this if you don't have illogical-impulse already installed. It sets up the base
dotfiles and everything they need, then puts my config on top.

```bash
git clone --recurse-submodules https://github.com/P3DROVFX/ii-p3drovfx.git
cd ii-p3drovfx
./setup-ii-p3drovfx.sh install
```

### Minimal installation (only quickshell config)

Use this if illogical-impulse is already working and you only want my Quickshell config.
Nothing else is touched, and your current config is moved to a backup rather than deleted.

```bash
git clone --recurse-submodules https://github.com/P3DROVFX/ii-p3drovfx.git
cd ii-p3drovfx
./setup-ii-p3drovfx.sh
```

## Documentation

Please refer to the **[upstream ii-vynx wiki](https://github.com/vaguesyntax/ii-vynx/wiki)** for detailed component descriptions.

## Credits

- **[end-4](https://github.com/end-4):** Creator of illogical-impulse.
- **[vaguesyntax](https://github.com/vaguesyntax):** Creator of ii-vynx.
- **[pc-trade](https://github.com/pctrade):** Some design and features inspo.
- **[so-do-i-look-like-him](https://github.com/so-do-i-look-like-him):** Installation bug fixes.
- **[asteriau](https://github.com/asteriau):** Cheatsheet keybinds animations.
- **[hnpf](https://github.com/hnpf):** Nothing widgets design
- **[gowall](https://github.com/Achno/gowall):** Dynamic icons theme system.
- **[hyprmon](https://github.com/erans/hyprmon):** Monitor management in settings.
- **[Quickshell](https://quickshell.org/):** Widget system.
- **[Hyprland](https://hypr.land/):** Compositor.

---

<div align="center">
    <p><b>If you like this project, consider giving it a star! ⭐</b></p>
</div>
