{
  # The platforms supported by the NixOS-CUDA Hydra instance
  supportedSystems ? [
    "x86_64-linux"
    "aarch64-linux"
  ],

  # The system evaluating this expression
  evalSystem ? builtins.currentSystem or "x86_64-linux",

  # Whether to apply hydraJob to each derivation.
  scrubJobs ? true,

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

  inherit (self.outputs.inputs.nixpkgs) lib;
in
{
  inherit nixpkgs self;

  inherit lib;

  recursiveScrubAndKeepEvaluatable =
    let
      isNotDerivation = x: !lib.isDerivation x;
      canDeepEval = expr: (builtins.tryEval (builtins.deepSeq expr expr)).success;
    in
    lib.mapAttrsRecursiveCond isNotDerivation (
      _: drv:
      let
        scrubbed = lib.hydraJob drv;
      in
      lib.optionalAttrs (canDeepEval scrubbed) scrubbed
    );

  releaseLib = import (nixpkgs + "/pkgs/top-level/release-lib.nix") {
    inherit scrubJobs supportedSystems;
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
      overlays = [
        self.outputs.overlays.default
        # Always make our CUDA package sets top-level instead of upstream's ones.
        (_: prev: prev.cudaPackagesVersions)
      ]
      ++ args.extraOverlays or [ ];
    };
  };
}
