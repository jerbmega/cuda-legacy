{ inputs, ... }:
{
  systems = [
    "aarch64-linux"
    "x86_64-linux"
  ];

  imports = [
    (
      { flake-parts-lib, lib, ... }:
      flake-parts-lib.mkTransposedPerSystemModule {
        name = "hydraJobs";
        option = lib.mkOption {
          type = lib.types.attrsWith {
            elemType = lib.types.raw;
            lazy = true;
            placeholder = "hydraJobs";
          };
          default = { };
        };
        file = ./flakeModule.nix;
      }
    )
  ];

  perSystem =
    {
      lib,
      pkgs,
      system,
      ...
    }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        config =
          { pkgs }:
          {
            allowUnfreePredicate = pkgs._cuda.lib.allowUnfreeCudaPredicate;
            cudaSupport = true;
          };
        localSystem = { inherit system; };
        overlays = [ inputs.self.overlays.default ];
      };

      hydraJobs = import ./mkHydraJobs.nix {
        inherit lib pkgs;
      };

      legacyPackages = pkgs;
    };
}
