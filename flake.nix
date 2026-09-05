{
  description = "NixOS hyprland setup";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    hardware.url = "github:nixos/nixos-hardware";
    nix-colors.url = "github:misterio77/nix-colors";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland = {
      url = "github:hyprwm/hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };

    catppuccin.url = "github:catppuccin/nix";

    # Prebuilt nixpkgs file->package index, kept up to date automatically
    # via `nix flake update`. Backs `comma`/command-not-found so unknown
    # commands can be searched and run sandboxed without ever having to
    # build a local index.
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ghostty = {
      url = "github:ghostty-org/ghostty";
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    catppuccin,
    ghostty,
    ...
    } @ inputs:
    let
      inherit (self) outputs;
      lib = nixpkgs.lib // home-manager.lib;

      # Single source of truth for the primary user's name. Every module
      # that needs it (system user account, home-manager, sops secret
      # paths, autologin, ssh/wireguard paths, ...) reads this via
      # specialArgs/extraSpecialArgs instead of hardcoding the string.
      username = "example";

      systems = ["x86_64-linux"];
      forEachSystem = f: lib.genAttrs systems (system: f pkgsFor.${system});

      pkgsFor = lib.genAttrs systems (system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        }
      );

      # Every host below is built the same way, differing only in which
      # ./hosts/<name> directory gets imported -- see hosts/example-*/default.nix
      # for what actually distinguishes client/server/standalone. Add a new
      # machine by adding one line to nixosConfigurations below (and a
      # matching hosts/<name>/ and home/<name>.nix, see bootstrap.sh).
      mkHost = name:
        lib.nixosSystem {
          specialArgs = {inherit inputs outputs username;};
          modules = [
            ./hosts/${name}

            catppuccin.nixosModules.catppuccin
            home-manager.nixosModules.home-manager

            ({config, ...}: {
              home-manager.backupFileExtension = "bak";
              home-manager.extraSpecialArgs = {
                inherit inputs outputs username;
                inherit (config.networking) hostName;
              };
            })
          ];
        };
    in {
      inherit lib;

      myPkgs = forEachSystem (pkgs: import ./pkgs {inherit pkgs;});

      formatter = forEachSystem (pkgs: pkgs.alejandra);

      devShells = forEachSystem (pkgs: import ./shell.nix { inherit pkgs; });

      nixosConfigurations = lib.genAttrs [
        "example-client"
        "example-server"
        "example-standalone"
      ] mkHost;
    };
}
