{pkgs, ...}: {
  virtualisation = {
    docker = {
      enable = true;
      enableOnBoot = false;
      rootless = {
        enable = true;
        setSocketVariable = true;
      };
    };
    libvirtd = {
      enable = true;
      package = with pkgs; libvirt;
      qemu = {
        package = with pkgs; qemu;
        swtpm = {
          enable = false;
          package = with pkgs; swtpm;
        };
      };
    };
    spiceUSBRedirection.enable = true;
  };
  services.spice-vdagentd.enable = true;
  programs.virt-manager.enable = true;
  networking.firewall.trustedInterfaces = ["virbr0"];

  environment.systemPackages = with pkgs; [
    #  pkgs.freerdp
    #bottles
    dnsmasq
  ];
}
