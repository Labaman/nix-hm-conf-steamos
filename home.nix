{ config, lib, pkgs, inputs, ... }:

# Minimal Home Manager base for SteamOS (non-NixOS).
# Solves only SteamOS-specific issues; add your own programs/options below.

let
  # Keep Flatpak first (set by /etc/profile -> flatpak.sh), append Nix+system.
  xdgDataDirsAppend =
    "\${XDG_DATA_DIRS:+\$XDG_DATA_DIRS:}${lib.concatStringsSep ":" config.xdg.systemDirs.data}";

  # POSIX dedup, keep-first, order preserved (works in zsh/bash and fish via babelfish).
  dedupXdgDataDirs = ''
    XDG_DATA_DIRS="$(printf '%s' "$XDG_DATA_DIRS" | awk -v RS=: -v ORS=: '!a[$0]++' | sed 's/:$//')"
    export XDG_DATA_DIRS
  '';
in
{
  home.username = "deck";
  home.homeDirectory = "/home/deck";
  home.stateVersion = "26.05";

  # Required on non-NixOS.
  targets.genericLinux.enable = true;
  xdg.enable = true;

  # GPU drivers for Nix GUI apps (mesa: OpenGL + Vulkan/RADV) via /run/opengl-driver,
  # like on NixOS — no per-package wrappers needed. The system part (tmpfiles.d in
  # /etc) is installed once with `nix-gpu-setup` (sudo); switch warns when the
  # drivers change and it has to be re-run.
  targets.genericLinux.gpu.enable = true;
  home.file.".local/bin/nix-gpu-setup" = {
    executable = true;
    source = ./scripts/nix-gpu-setup.sh;
  };

  # `nix shell nixpkgs#…` and `nix-shell -p` use the same nixpkgs as this config:
  # no channel re-downloads, and `nix-shell -p` works (the default NIX_PATH points
  # to channels that don't exist).
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
  nix.keepOldNixPath = false;

  # Example: browser via the programs.chromium HM module.
  # The module generates a proper .desktop entry and handles XDG mime types.
  # Swap pkgs.google-chrome for pkgs.chromium / pkgs.ungoogled-chromium etc.
  # programs.chromium = {
  #   enable = true;
  #   package = pkgs.google-chrome;
  #   commandLineArgs = [
  #     "--enable-features=VaapiIgnoreDriverChecks,AcceleratedVideoEncoder,ParallelDownloading"
  #     "--ignore-gpu-blocklist"
  #   ];
  # };

  # XDG_DATA_DIRS order fix: keep Flatpak ahead of the SteamOS "Install Firefox"
  # stub in the KDE menu (HM #8076 / #9356). Overrides prepend -> append.
  home.sessionVariables.XDG_DATA_DIRS = lib.mkForce xdgDataDirsAppend;
  systemd.user.sessionVariables.XDG_DATA_DIRS = lib.mkForce xdgDataDirsAppend;
  # Dedup for all shells via hm-session-vars.sh (zsh, bash, fish via babelfish).
  home.sessionVariablesExtra = lib.mkAfter dedupXdgDataDirs;
  # bash only (genericLinux re-sources nix.sh in .bashrc after the guard) — may be
  # removed when using zsh or fish.
  programs.bash.initExtra = lib.mkAfter dedupXdgDataDirs;

  # After switch, system apps (Konsole etc.) vanish from the KDE launcher and search.
  # Home Manager's activation script overrides PATH to a bare list of Nix store tools —
  # /usr/bin isn't included, so kbuildsycoca6 silently builds an incomplete cache missing
  # system apps. Fix: prepend /usr/bin to PATH before calling it.
  # env -u LD_LIBRARY_PATH avoids a glibc conflict with Nix's own glibc.
  home.activation.refreshPlasmaMenu =
    lib.hm.dag.entryAfter [ "linkGeneration" "onFilesChange" ] ''
      if [ -x /usr/bin/kbuildsycoca6 ]; then
        $DRY_RUN_CMD env -u LD_LIBRARY_PATH PATH="/usr/bin:/usr/local/bin:$PATH" /usr/bin/kbuildsycoca6 --noincremental || true
      fi
    '';

  # Native Wayland for Electron/Chromium apps from nixpkgs.
  # QT_QPA_PLATFORM is not set: Qt already picks wayland;xcb in a Wayland session.
  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  # bash only: pushes NIXOS_OZONE_WL to KDE-launched apps via plasma-workspace/env,
  # since bash misses the non-interactive non-login startup path. Inert for zsh/fish
  # (guarded by lib.mkIf) — may be removed when switching to zsh or fish.
  home.file.".config/plasma-workspace/env/nixos-ozone-wl.sh" =
    lib.mkIf config.programs.bash.enable {
      text = ''
        export NIXOS_OZONE_WL=1
      '';
    };

  # ── Shell (required — uncomment ONE) ─────────────────────────────────────────
  # See README for shell comparison, advantages of zsh/fish, and how to change the
  # default login shell.
  #
  # programs.bash.enable = true;
  #
  # programs.zsh = {
  #   enable = true;
  #   enableCompletion = true;
  #   autosuggestion.enable = true;
  #   syntaxHighlighting.enable = true;
  #   defaultKeymap = "emacs";
  # };
  #
  # programs.fish.enable = true;

  # ~/.local/bin in PATH: pip, cargo, and official installers (Claude Code etc.) put
  # binaries there. Written to hm-session-vars.sh -> works for bash, zsh, and fish.
  home.sessionPath = [ "$HOME/.local/bin" ];

  # genericLinux sets XCURSOR_PATH without the user theme dirs;
  # KDE installs downloaded cursor themes to ~/.icons.
  home.sessionSearchVariables.XCURSOR_PATH = lib.mkBefore [ "$HOME/.local/share/icons" "$HOME/.icons" ];

  # Starship prompt — shell-independent (same toml renders in bash, zsh, and fish).
  # Matches the default SteamOS 3.9 bash style 1:1 (__holo_ps1/__holo_prompt_command
  # in /etc/bash.bashrc): (rc)(user@host dir)$ — rc only on a non-zero exit code with
  # just the number in red, user@host as one green block, dir in blue, parens (not
  # square brackets) and `$` uncolored. Git branch/status is our own addition — the
  # original bash prompt has no git info:
  #   (deck@steamdeck ~)$                outside a repo
  #   (deck@steamdeck myapp) [main]$     inside a repo
  programs.starship = {
    enable = true;
    settings = {
      # No space after $character: the module adds it itself ("$symbol ").
      format = "$status\\($username$hostname $directory\\)( \\[$git_branch$git_status\\])$character";
      add_newline = false;

      status = {
        disabled = false;
        style = "bold red";
        format = "\\([$status]($style)\\)";
      };

      username = {
        show_always = true;
        style_user = "bold green";
        style_root = "bold red";
        format = "[$user@]($style)";
      };

      hostname = {
        ssh_only = false;
        style = "bold green";
        format = "[$hostname]($style)";
      };

      directory = {
        style = "bold blue";
        truncation_length = 1;
        truncate_to_repo = false;
        format = "[$path]($style)";
      };

      git_branch = {
        format = "[$branch]($style)";
        style = "bold yellow";
      };

      git_status = {
        format = "[$all_status]($style)";
        style = "bold red";
        modified   = "*";
        staged     = "+";
        untracked  = "?";
        deleted    = "*";
        renamed    = "";
        conflicted = "!";
        stashed    = "";
        ahead      = "⇡";
        behind     = "⇣";
        diverged   = "⇕";
        up_to_date = "";
      };

      character = {
        success_symbol = "\\$";
        error_symbol   = "\\$";
      };
    };
  };

  # Add your own here, e.g.:
  #   home.packages = with pkgs; [ ripgrep fd ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Uncomment to manage git. Activates ensureMutableGitconfig below automatically.
  # programs.git = {
  #   enable = true;
  #   settings.user = {
  #     name  = "Your Name";
  #     email = "you@example.com";
  #   };
  # };

  # programs.git makes ~/.config/git/config a read-only symlink into the Nix store.
  # Tools that call `git config --global` during setup (EmuDeck, rustup, etc.) fail with
  # "could not lock config file ... Permission denied". Git writes --global to ~/.gitconfig
  # when that file exists, falling back to the XDG path otherwise. Ensuring a writable
  # ~/.gitconfig redirects those writes there; the managed config remains read-only
  # and is still read by git (it checks both files).
  home.activation.ensureMutableGitconfig = lib.mkIf config.programs.git.enable
    (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -e "$HOME/.gitconfig" ]; then
        $DRY_RUN_CMD touch "$HOME/.gitconfig"
      fi
    '');
}
