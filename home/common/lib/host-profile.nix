# Small set of machine-specific knobs that the shared desktop modules
# (hyprland, waybar, ghostty, ...) read instead of hardcoding a hostname
# comparison. Nix option declarations merge cleanly across files (lists,
# attrsets, submodules); it's plain bools/strings/ints that conflict if two
# modules both assign them. So the pattern is: a generic module declares the
# option with a sane default, and one specific host's home file (the only
# place that actually knows its own hardware) sets the override -- no
# hostname string matching, no conflict.
#
# None of the generic example-* hosts set any of these, so they all get the
# defaults below (single auto-configured monitor, no HiDPI scaling, idle
# lock on). A real machine overrides what it needs from its own
# home/<hostname>.nix.
{lib, ...}: {
  options.hostProfile = {
    hidpi = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Scale fonts/icons up for a high-DPI display.";
    };

    hasTouchpad = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enables touchpad-oriented Hyprland behavior (gestures).";
    };

    idleLockEnable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether hypridle should dim/lock this host after inactivity. Turn off for kiosk/always-visible displays.";
    };

    hybridGpuDrmDevices = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/dev/dri/card0:/dev/dri/card1";
      description = ''
        "primary:secondary" /dev/dri card pair, only for hybrid-GPU laptops
        (e.g. Intel+Nvidia Optimus). Forcing this on a single-GPU host makes
        wlroots wait on a /dev/dri card that never appears, so leave this
        null unless the host actually has two GPUs.
      '';
    };

    monitors = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          output = lib.mkOption {type = lib.types.str; default = "";};
          mode = lib.mkOption {type = lib.types.str; default = "highres";};
          position = lib.mkOption {type = lib.types.str; default = "auto";};
          scale = lib.mkOption {type = lib.types.numbers.positive; default = 1;};
        };
      });
      default = [{output = ""; mode = "highres"; position = "auto"; scale = 1;}];
      description = "Hyprland monitor layout for this host.";
    };

    waybarOutputs = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      description = "Restrict waybar to these outputs (waybar's own '!name' exclusion syntax works too). null = every output.";
    };
  };
}
