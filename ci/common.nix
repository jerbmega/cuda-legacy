{
  # The platforms supported by the NixOS-CUDA Hydra instance
  supportedSystems ? [
    "x86_64-linux"
    "aarch64-linux"
  ],

  # The system evaluating this expression
  evalSystem ? builtins.currentSystem or "x86_64-linux",

  # Specific CUDA capabilities to set.
  cudaCapabilities ? null,

  # Additional overlays to apply to the package set.
  extraOverlays ? null,

  # The path to Nixpkgs -- resolved inputs are made available in outputs.
  nixpkgs ? null,
}@args:
let
  # A self-reference to this flake to get overlays
  self = builtins.getFlake (builtins.toString ../.);

  # Default values won't make unsupplied arguments present; they just make the variable available in the scope.
  nixpkgs = args.nixpkgs or self.outputs.inputs.nixpkgs.outPath;
in
{
  inherit nixpkgs self;

  inherit (self.outputs.inputs.nixpkgs) lib;

  cudaPackageSetNames = [
    "cudaPackages_11_4"
    "cudaPackages_11_5"
    "cudaPackages_11_6"
    "cudaPackages_11_7"
    "cudaPackages_11_8"

    "cudaPackages_12_0"
    "cudaPackages_12_1"
    "cudaPackages_12_2"
    "cudaPackages_12_3"
    "cudaPackages_12_4"
    "cudaPackages_12_5"
    "cudaPackages_12_6"
    "cudaPackages_12_8"
    "cudaPackages_12_9"

    "cudaPackages_13_0"
  ];

  releaseLib = import (nixpkgs + "/pkgs/top-level/release-lib.nix") {
    inherit supportedSystems;
    system = evalSystem;
    nixpkgsArgs = {
      __allowFileset = false;
      config = {
        # By default, Nixpkgs allows aliases. Setting them to false allows us to detect breakages sooner rather
        # than later.
        allowAliases = false;
        allowUnfreePredicate =
          (import (nixpkgs + "/pkgs/development/cuda-modules/_cuda")).lib.allowUnfreeCudaPredicate;
        cudaSupport = true;
        # Exclude cudaCapabilities if unset to allow selection of default capabilities.
        ${if cudaCapabilities != null then "cudaCapabilities" else null} = cudaCapabilities;
        inHydra = true;
      };
      overlays = [ self.outputs.overlays.default ] ++ args.extraOverlays or [ ];
    };
  };
}
