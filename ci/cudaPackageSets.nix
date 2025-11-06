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
  inherit (import ./common.nix args) lib releaseLib;
in
releaseLib.mapTestOn (
  lib.mapAttrs (lib.const releaseLib.packagePlatforms) releaseLib.pkgs.cudaPackagesVersions
)
