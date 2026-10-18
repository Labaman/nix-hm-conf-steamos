# Nix Home Manager Config for SteamOS

**English** | [Русский](README.ru.md)

Nix is one of the officially supported ways to install additional software on SteamOS (available since version 3.5). Packages and settings installed via Nix survive SteamOS updates — making it a solid alternative to Flatpak, Distrobox, and Homebrew.

This repository is a minimal [Home Manager](https://github.com/nix-community/home-manager) base config for SteamOS. It accounts for the quirks of running Nix on SteamOS and includes fixes for the main issues that can break the system or apps installed outside of Nix.

## Features

| Fix / Feature | Notes |
|---------------|-------|
| XDG_DATA_DIRS order | Keeps the original `XDG_DATA_DIRS` order (Flatpak first). Otherwise Flatpak apps may be missing from the menu or fail to open, and read-only SteamOS stubs (e.g. "Install Firefox") launch instead (HM [#8076](https://github.com/nix-community/home-manager/issues/8076) / [#9356](https://github.com/nix-community/home-manager/pull/9356)) |
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

If a file Home Manager wants to manage already exists (for example `~/.bashrc` when you enable bash), it is renamed to `<file>.hm-backup` instead of failing. If that backup already exists, `switch` stops: remove or rename the old backup and run it again.

Then open a new terminal window: the current one was started before `switch`, so `~/.local/bin` (where `nix-gpu-setup` is installed) isn't in its `PATH` yet.

Set up GPU drivers for Nix GUI apps (asks for the sudo password; re-run it when `switch` warns that GPU drivers require an update):

```bash
nix-gpu-setup
```

Add your own packages and programs to `home.nix`, below the `# Add your own packages here` comment.

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

Home Manager writes session variables (including `~/.local/bin` in `PATH`) to `hm-session-vars.sh`, which only a Home Manager-managed shell loads. The SteamOS login shell is bash, so `programs.bash` is enabled in `home.nix` by default — open a new terminal after the first `switch`. Your existing `~/.bashrc` and `~/.bash_profile` are renamed to `*.hm-backup`; move your settings into the `programs.bash` options or the slot for your own lines in `programs.bash.initExtra`.

| Shell | Session env coverage | Notes |
|-------|----------------------|-------|
| **bash** | login + interactive shells | SteamOS default; no need to change the login shell. The two `# bash only` entries in `home.nix` cover what bash alone misses: `XDG_DATA_DIRS` duplicates in `.bashrc` and `NIXOS_OZONE_WL` for apps launched from the KDE menu. |
| **zsh** | login, interactive & non-interactive | Session vars load in every zsh — login shells via `.zprofile`, others via `.zshenv`. Does not touch bash dotfiles. |
| **fish** | login, interactive & non-interactive | Autocompletion, command suggestions, and syntax highlighting work out of the box without extra config. Does not touch bash dotfiles. Note: fish syntax is not POSIX/bash-compatible — bash scripts won't run directly inside fish. |

### Using zsh or fish instead (optional)

bash works out of the box, so switching is a matter of taste: the fixes in `home.nix` work the same in every shell, and the two bash-only entries do nothing once bash is off.

1. Uncomment the block for your shell in `home.nix` and run `home-manager switch`.
2. Change the login shell. Use the **system-provided** binary, not the Nix-managed one: login keeps working even if Nix is later removed (both shells ship with SteamOS).

   For **zsh**:

   ```bash
   chsh -s /bin/zsh
   ```

   For **fish**:

   ```bash
   chsh -s /bin/fish
   ```

3. Log out and back in: SteamOS starts the desktop session and new Konsole windows with your login shell.

The bash block can stay enabled for bash sessions, or you can comment it out.
