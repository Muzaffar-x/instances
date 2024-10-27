{ config
, inputs
, lib
, pkgs
, ...
}:
let
  key = "/home/sakhib/.config/sops/age/keys.txt";
in
{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";

    age = {
      keyFile = key;
    };

    secrets.message = {
      owner = config.users.users.sakhib.name;
    };
  };
}