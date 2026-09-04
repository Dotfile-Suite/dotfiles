{
  config,
  outputs,
  username,
  ...
}: {
  imports = [
    ./common/core
    #./common/optional/code.nix
    ./common/optional/apps
    ./common/optional/desktops/hyprland
    ./common/optional/desktops/waybar
    ./common/optional/desktops/gtk.nix
    ./common/optional/desktops/qt5.nix
    ./common/optional/desktops/xdg.nix
  ];

  home = {
    inherit username;
    homeDirectory = "/home/${config.home.username}";
    stateVersion = "26.05";
  };
}
