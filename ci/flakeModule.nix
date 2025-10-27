{ inputs, ... }:
{
  systems = [
    "aarch64-linux"
    "x86_64-linux"
  ];

  transposition.hydraJobs.adHoc = true;

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

      hydraJobs =
        let
          # NOTE: Not all packages are written to support earlier CUDA versions.
          # For example, cupy needs the CUDA profiler API, which isn't available in early versions.
          # NOTE: Our overlays do not change the major-versioned or unversioned package sets (e.g., cudaPackages_12,
          # cudaPackages).
          # NOTE: We do not build for non-default capabilities (e.g., Jetson devices, non-baseline feature sets, etc.).
          cudaPackageSetNames =
            # Only supported by x86_64-linux
            lib.optionals (system == "x86_64-linux") [
              "cudaPackages_11_4"
              "cudaPackages_11_5"
              "cudaPackages_11_6"
              "cudaPackages_11_7"
            ]
            ++ [
              "cudaPackages_11_8"
              "cudaPackages_12_0"
              "cudaPackages_12_1"
              "cudaPackages_12_2"
              "cudaPackages_12_3" # Not supported by Jetson
              "cudaPackages_12_4"
              "cudaPackages_12_5"
              "cudaPackages_12_6"
              # There is no 12.7 release
              "cudaPackages_12_8"
              "cudaPackages_12_9"
              "cudaPackages_13_0" # Not supported by Jetson prior to Thor
            ];
        in
        lib.genAttrs cudaPackageSetNames (
          cudaPackageSetName:
          import ./mkHydraJobs.nix {
            inherit lib;
            inherit (pkgs.${cudaPackageSetName}) pkgs;
          }
        );

      legacyPackages = pkgs;
    };
}
