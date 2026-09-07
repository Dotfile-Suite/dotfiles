{
  pkgs,
  username,
  ...
}: let
  # TODO: Fix ssh port on server
  push-fs = pkgs.writeShellScriptBin "push-fs" ''
    #!/bin/bash
    rsync -ruqpEXgtUz --delete --safe-links -e "ssh -p 14127" /home/${username}/Desktop/ ${username}@10.0.1.1:/mnt/data/Shared/Desktop/
    rsync -ruqpEXgtUz --delete --safe-links -e "ssh -p 14127" /home/${username}/Documents/ ${username}@10.0.1.1:/mnt/data/Shared/Documents/
    rsync -ruqpEXgtUz --delete --safe-links -e "ssh -p 14127" /home/${username}/Downloads/ ${username}@10.0.1.1:/mnt/data/Shared/Downloads/
    rsync -ruqpEXgtUz --delete --safe-links -e "ssh -p 14127" /home/${username}/Pictures/ ${username}@10.0.1.1:/mnt/data/Shared/Pictures/
    rsync -ruqpEXgtUz --delete --safe-links -e "ssh -p 14127" /home/${username}/Projects/ ${username}@10.0.1.1:/mnt/data/Shared/Projects/
    rsync -ruqpEXgtUz --delete --safe-links -e "ssh -p 14127" /home/${username}/School/ ${username}@10.0.1.1:/mnt/data/Shared/School/
    rsync -ruqpEXgtUz --delete --safe-links -e "ssh -p 14127" /home/${username}/Videos/ ${username}@10.0.1.1:/mnt/data/Shared/Videos/
  '';
  #    push-fs-exec = "${push-fs}/bin/push-fs";

  pull-fs = pkgs.writeShellScriptBin "pull-fs" ''
    #!/bin/bash
    rsync -ruqpEXgtUz --delete --safe-links -e "ssh -p 14127" ${username}@10.0.1.1:/mnt/data/Shared/Desktop/ /home/${username}/Desktop/
    rsync -ruqpEXgtUz --delete --safe-links -e "ssh -p 14127" ${username}@10.0.1.1:/mnt/data/Shared/Documents/ /home/${username}/Documents/
    rsync -ruqpEXgtUz --delete --safe-links -e "ssh -p 14127" ${username}@10.0.1.1:/mnt/data/Shared/Downloads/ /home/${username}/Downloads/
    rsync -ruqpEXgtUz --delete --safe-links -e "ssh -p 14127" ${username}@10.0.1.1:/mnt/data/Shared/Pictures/ /home/${username}/Pictures/
    rsync -ruqpEXgtUz --delete --safe-links -e "ssh -p 14127" ${username}@10.0.1.1:/mnt/data/Shared/Projects/ /home/${username}/Projects/
    rsync -ruqpEXgtUz --delete --safe-links -e "ssh -p 14127" ${username}@10.0.1.1:/mnt/data/Shared/School/ /home/${username}/School/
    rsync -ruqpEXgtUz --delete --safe-links -e "ssh -p 14127" ${username}@10.0.1.1:/mnt/data/Shared/Videos/ /home/${username}/Videos/
  '';
  #    pull-fs-exec = "${pull-fs}/bin/pull-fs";
in {
  # Make the actions user-runnable
  environment.systemPackages = with pkgs; [
    push-fs
    pull-fs
  ];

  #    # Handle power cycling
  #    systemd.services = {
  #        "shared-fs" = {
  #            description = "Pulls on start and pushes on stop";
  #            wantedBy = [ "multi-user.target" ];
  #            serviceConfig = {
  #                User = username;
  #                ExecStart = pull-fs-exec;
  #                ExecStop = push-fs-exec;
  #            };
  #            path = with pkgs; [ rsync openssh ];
  #        };
  #    };
  #
  #    # Handle lid events
  #    services.acpid.handlers = {
  #        "pull-fs" = {
  #            event = "button/lid.open";
  #            action = pull-fs-exec;
  #        };
  #        "push-fs" = {
  #            event = "button/lid.close";
  #            action = push-fs-exec;
  #        };
  #    };
}
