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
  # A self-reference to this flake to get overlays
  self = builtins.getFlake (builtins.toString ../.);

  # Lib for later usage
  inherit (self.outputs.inputs.nixpkgs) lib;

  cudaLib =
    (import (
      args.nixpkgs or self.outputs.inputs.nixpkgs.outPath + "/pkgs/development/cuda-modules/_cuda/"
    )).lib;

  inherit (lib)
    attrNames
    mapAttrs'
    recurseIntoAttrs
    concatMapAttrs
    optionalAttrs
    hasAttr
    genAttrs
    genAttrs'
    ;

  # Get the manifests
  manifests = import ../pkgs/development/cuda-modules/_cuda/manifests { inherit lib; };

  # NOTE: Assumes redist is stand-alone -- that it does not depend on other redistributables.
  # TODO: Use the extraOverlays argument to common.nix to add to _cuda.extensions all of the versioned attributes we care about.
  # Then we just need to provide the skeleton with attribute names of the values we want to extract via releaseLib.mapTestOn.
  mkRedistPackages =
    redistName:
    # NOTE: Manifest version is different from the release version of a package.
    let
      redistVersions = attrNames manifests.${redistName};

      redistVersionOverlay =
        finalCudaPackages: prevCudaPackages:
        mapAttrs' (redistVersion: redistManifest: {
          name = cudaLib.mkVersionedName redistName redistVersion;
          value = recurseIntoAttrs (
            concatMapAttrs (
              name: release:
              # Filter for supported packages and releases
              optionalAttrs (hasAttr name prevCudaPackages) {
                ${name} = finalCudaPackages.${name}.overrideAttrs (prevAttrs: {
                  # Our src depends on version.
                  __intentionallyOverridingVersion = true;

                  inherit (release) version;

                  passthru = prevAttrs.passthru // {
                    inherit release;
                  };
                });
              }
            ) redistManifest
          );
        }) manifests.${redistName};

      inherit
        (import ./common.nix (
          args
          // {
            extraOverlays = [ redistVersionOverlay ];
          }
        ))
        cudaPackageSetNames
        releaseLib
        ;
    in
    # TODO: Finish implementation/tidy up attribute paths.
    releaseLib.mapTestOn (genAttrs cudaPackageSetNames (cudaPackageSetName: [ ]));
in
{
  cudnn = mkRedistPackages "cudnn";
}
