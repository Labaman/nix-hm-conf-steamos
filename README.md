# Nix Home Manager Config for SteamOS

**English** | [Русский](README.ru.md)

Nix is one of the officially supported ways to install additional software on SteamOS (available since version 3.5). Packages and settings installed via Nix survive SteamOS updates — making it a solid alternative to Flatpak, Distrobox, and Homebrew.

This repository is a minimal [Home Manager](https://github.com/nix-community/home-manager) base config for SteamOS. It accounts for the quirks of running Nix on SteamOS and includes fixes for the main issues that can break the system or apps installed outside of Nix.

## Features

| Fix / Feature | Notes |
|---------------|-------|
| XDG_DATA_DIRS order | Keeps Flatpak ahead of system stubs in the KDE menu (HM [#8076](https://github.com/nix-community/home-manager/issues/8076) / [#9356](https://github.com/nix-community/home-manager/pull/9356)) |
| KDE app menu update | Nix app icons appear in the launcher right after `switch` without a relogin (icons may be blank on first switch, but are present). Also prevents system apps from vanishing after switch. |
| GPU for Nix GUI apps | `targets.genericLinux.gpu`: mesa drivers (OpenGL + Vulkan/RADV) via `/run/opengl-driver`, no per-app wrappers; `nix-gpu-setup` keeps it across SteamOS updates |
| Native Wayland for Nix GUI apps | `NIXOS_OZONE_WL` for Electron/Chromium apps (Qt picks Wayland itself) |
| Pinned `nixpkgs` | `nix shell nixpkgs#…` and `nix-shell -p` use the same nixpkgs as the config |
| EmuDeck / rustup | Writable `~/.gitconfig` alongside HM-managed git config |
| Shell prompt (Starship) | Consistent SteamOS-style prompt across bash, zsh, and fish: `(user@host dir) [branch*]$` |

## Usage

If Nix isn't installed yet, install it. The official installer [NixOS/nix-installer](https://github.com/NixOS/nix-installer) is recommended: it detects SteamOS automatically and handles the initial setup:

```bash
curl -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install --enable-flakes
```

Then:

```bash
git clone https://github.com/Labaman/nix-hm-conf-steamos ~/.config/home-manager
nix run home-manager/master -- switch
```

For the initial activation, Home Manager is run directly from its flake with `nix run`, so there's no need to install it separately. Once that has completed successfully, the `home-manager` command is available in your profile, and applying any later config change is as simple as `home-manager switch`.

Set up GPU drivers for Nix GUI apps (asks for the sudo password; re-run it when `switch` warns that GPU drivers require an update):

```bash
nix-gpu-setup
```

Add your own packages and programs below the comment at the bottom of `home.nix`.

## Updating & maintenance

**Updating programs.** All packages come from the flake inputs (nixpkgs and Home Manager) pinned in `flake.lock`. To update your apps, update those inputs and apply the config again:

```bash
cd ~/.config/home-manager
nix flake update      # bump nixpkgs + home-manager to the latest commit
home-manager switch   # rebuild and activate the updated programs
```

List generations (to roll back, activate an earlier one):

```bash
home-manager generations
```

Free up disk space. Old generations are kept until you remove them, and each `switch` adds a new one:

```bash
home-manager expire-generations "-7 days"   # drop Home Manager generations older than 7 days
nix-collect-garbage --delete-older-than 7d   # remove old profile generations + unreferenced store paths
nix store optimise                           # deduplicate the store with hard links
```

To remove all old generations at once and keep only the current one, use `nix-collect-garbage -d`.

### Uninstalling

Remove Home Manager first — the files it manages in your home directory are symlinks into the Nix store and would be left dangling otherwise:

```bash
home-manager uninstall
```

Then uninstall Nix itself with nix-installer — see [NixOS/nix-installer → Uninstalling](https://github.com/NixOS/nix-installer#uninstalling):

```bash
/nix/nix-installer uninstall
```

`nix-gpu-setup` also left two files in `/etc`; remove them too:

```bash
sudo rm /etc/tmpfiles.d/non-nixos-gpu.conf /etc/atomic-update.conf.d/non-nixos-gpu.conf
```

If you switched the login shell to zsh or fish, it keeps working — those are system binaries.

## Shell

A managed shell is required to source session variables into the graphical session.
Uncomment one of the shell blocks in `home.nix`.

| Shell | Session env coverage | Notes |
|-------|----------------------|-------|
| **bash** | login + interactive shells | SteamOS default; simplest to start with. The two `# bash only` entries in `home.nix` cover the non-interactive startup gap. |
| **zsh** | login, interactive & non-interactive | `.zshenv` is sourced for every zsh invocation, so session vars always load without any workarounds. Does not touch bash dotfiles. The `# bash only` entries in `home.nix` may be removed. |
| **fish** | login, interactive & non-interactive | Autocompletion, command suggestions, and syntax highlighting work out of the box without extra config. Does not touch bash dotfiles. The `# bash only` entries may be removed. Note: fish syntax is not POSIX/bash-compatible — bash scripts won't run directly inside fish. |

### Changing the default login shell (optional)

Switching from the default bash to zsh or fish is recommended — their HM modules are more actively developed, and the bash-specific workarounds become unnecessary.

To use zsh or fish, switch to the **system-provided** binary — not the Nix-managed one.
This keeps login working even if Nix is later removed (both shells ship with SteamOS):

Switch to **zsh**:
```bash
chsh -s /bin/zsh
```

Switch to **fish**:
```bash
chsh -s /bin/fish
```

Do this **before** running `home-manager switch` with the shell module enabled.
After re-login, uncomment the corresponding shell block in `home.nix`.
