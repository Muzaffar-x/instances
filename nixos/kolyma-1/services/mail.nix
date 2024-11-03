{ inputs, config, pkgs, ... }:
let
  secret-management = {
    owner = config.users.users.stalwart-mail.name;
  };
in
{
  disabledModules = [
    "services/mail/stalwart-mail.nix"
  ];

  imports = [
    "${inputs.nixpkgs-unstable}/nixos/modules/services/mail/stalwart-mail.nix"
  ];

  sops.secrets = {
    "mail/acme" = secret-management;
    "mail/admin" = secret-management;
    "mail/users/git" = secret-management;
    "mail/users/sakhib" = secret-management;
    "mail/users/misskey" = secret-management;
  };

  # Broken wasm-bindgen
  nixpkgs.config.packageOverrides = pkgs: {
    stalwart-mail = pkgs.unstable.stalwart-mail.overrideAttrs (old: {
      passthru.webadmin = pkgs.unstable.stalwart-mail.webadmin.override {
        wasm-bindgen-cli = pkgs.unstable.wasm-bindgen-cli.override {
          version = "0.2.93";
          hash = "sha256-DDdu5mM3gneraM85pAepBXWn3TMofarVR4NbjMdz3r0=";
          cargoHash = "sha256-birrg+XABBHHKJxfTKAMSlmTVYLmnmqMDfRnmG6g/YQ=";
        };
      };
    });
  };

  services.stalwart-mail = {
    enable = true;
    package = pkgs.unstable.stalwart-mail;
    openFirewall = true;

    settings = {
      server = {
        hostname = "mail.kolyma.uz";

        tls = {
          enable = true;
          implicit = true;
        };

        listener = {
          smtp = {
            protocol = "smtp";
            bind = "[::]:25";
          };
          submissions = {
            bind = "[::]:465";
            protocol = "smtp";
          };
          imaps = {
            bind = "[::]:993";
            protocol = "imap";
          };
          jmap = {
            bind = "[::]:8080";
            url = "https://mail.kolyma.uz";
            protocol = "jmap";
          };
          management = {
            bind = [ "127.0.0.1:8080" ];
            protocol = "http";
          };
        };
      };

      lookup.default = {
        hostname = "mail.kolyma.uz";
        domain = "kolyma.uz";
      };

      acme."letsencrypt" = {
        directory = "https://acme-v02.api.letsencrypt.org/directory";
        challenge = "dns-01";
        contact = "admin@kolyma.uz";
        domains = [ "kolyma.uz" "mail.kolyma.uz" ];
        provider = "cloudflare";
        secret = "%{file:${config.sops.secrets."mail/acme".path}}%";
      };

      session.auth = {
        mechanisms = "[plain]";
        directory = "'in-memory'";
      };

      storage.directory = "in-memory";
      session.rcpt.directory = "'in-memory'";
      queue.outbound.next-hop = "'local'";
      directory."imap".lookup.domains = [ "kolyma.uz" ];
      directory."in-memory" = {
        type = "memory";
        principals = [
          {
            class = "individual";
            name = "Sokhibjon Orzikulov";
            secret = "%{file:${config.sops.secrets."mail/users/sakhib".path}}%";
            email = [ "orzklv@kolyma.uz" "admin@kolyma.uz" ];
          }
          {
            class = "individual";
            name = "postmaster";
            secret = "%{file:${config.sops.secrets."mail/users/sakhib".path}}%";
            email = [ "postmaster@kolyma.uz" ];
          }
        ];
      };

      authentication.fallback-admin = {
        user = "admin";
        secret = "%{file:${config.sops.secrets."mail/admin".path}}%";
      };
    };
  };

  services.www.hosts = {
    "wm.kolyma.uz" = {
      extraConfig = ''
        reverse_proxy http://127.0.0.1:8080
      '';
      serverAliases = [
        "mta-sts.kolyma.uz"
        "autoconfig.kolyma.uz"
        "autodiscover.kolyma.uz"
        "mail.kolyma.uz"
      ];
    };
  };
}
