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

  # The path to Nixpkgs -- resolved inputs are made available in outputs.
  nixpkgs ? null,
}@args:
let
  # We must scrub the jobs ourselves given we want to ignore packages marked as broken within the package set;
  # they are known to be broken.
  inherit (import ./common.nix (args // { scrubJobs = false; }))
    lib
    recursiveScrubAndKeepEvaluatable
    releaseLib
    ;
in
# Ignore packages which are marked as broken and scrub all packages.
recursiveScrubAndKeepEvaluatable (
  releaseLib.mapTestOn (
    lib.mapAttrs (lib.const releaseLib.packagePlatforms) releaseLib.pkgs.cudaPackagesVersions
  )
)
