{ inputs, lib }:
{
  networking = import ./networking.nix { inherit lib; };

  username = "krino";
  domain = inputs.nix-secrets.domain;
  userFullName = inputs.nix-secrets.full-name;
  handle = "giovanni-nappi";
  userEmail = inputs.nix-secrets.user-email;
  gitHubEmail = "giovanni.nappi@gmail.com"; # FIXME
  workEmail = inputs.nix-secrets.work-email;
  persistFolder = "/persist";
  isMinimal = false; # Used to indicate nixos-installer build
}
