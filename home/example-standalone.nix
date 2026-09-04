# Home-manager entry point for the example-standalone host (client + server
# roles combined on one machine). Layer on modules and hostProfile.*
# overrides here as this machine gets configured for real -- see
# home/common/lib/host-profile.nix and home/base.nix.
{
  imports = [
    ./base.nix
  ];
}
