{
  # The name of the redistributable for which to evaluate all combinations.
  redistName,

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
  inherit
    (import ./common.nix (
      removeAttrs args [ "redistName" ]
      // {
        extraOverlays = [ redistOverlay ];
        # Don't use lib.hydraJob; we handle it explicitly with recursiveScrubAndKeepEvaluatable.
        scrubJobs = false;
      }
    ))
    lib
    recursiveScrubAndKeepEvaluatable
    releaseLib
    ;

  manifests = import ../pkgs/development/cuda-modules/_cuda/manifests { inherit lib; };

  redistOverlay =
    final: prev:
    if redistName == "cuda" then
      # CUDA is the only redist which forms the backbone of the package set; we have them directly at the top level.
      lib.genAttrs' (lib.attrNames manifests.cuda) (redistVersion: {
        # Must use prev to avoid infinite recursion. The implementation should not change, so that's fine.
        name = prev._cuda.lib.mkVersionedName redistName redistVersion;
        value = final.callPackage final._cuda.bootstrapData.cudaPackagesPath {
          manifests = final._cuda.lib.selectManifests { cuda = redistVersion; };
        };
      })
    else
      {
        # NOTE: Assumes redist is stand-alone -- that it does not depend on other redistributables.
        _cuda = prev._cuda.extend (
          finalCuda: prevCuda: {
            # Add the overlay to _cuda.extensions so each CUDA package set has it added automatically.
            extensions = prevCuda.extensions ++ [
              (
                finalCudaPackages: _:
                # Add attribute sets to each CUDA package set corresponding to the versioned name of the redist;
                # these contain the unverionsed names of the packages available from that version of the redist,
                # built against the enclosing CUDA package set scope.
                final.lib.mapAttrs' (redistVersion: redistManifest: {
                  name = finalCuda.lib.mkVersionedName redistName redistVersion;
                  value = final.lib.recurseIntoAttrs (
                    final.lib.concatMapAttrs (
                      name: release:
                      # Filter for supported packages and releases
                      final.lib.optionalAttrs (final.lib.hasAttr name finalCudaPackages) {
                        ${name} = finalCudaPackages.${name}.overrideAttrs (prevAttrs: {
                          passthru = prevAttrs.passthru // {
                            inherit release;
                          };
                        });
                      }
                    ) redistManifest
                  );
                }) finalCuda.manifests.${redistName}
              )
            ];
          }
        );
      };

  getRedistSet =
    attrPathRoot: redistName:
    lib.mapAttrs' (
      redistVersion: redistManifest:
      let
        name = releaseLib.pkgs._cuda.lib.mkVersionedName redistName redistVersion;
      in
      {
        inherit name;
        # Get just the attributes present in the manifest.
        value = releaseLib.packagePlatforms (
          lib.intersectAttrs redistManifest (lib.getAttrFromPath (attrPathRoot ++ [ name ]) releaseLib.pkgs)
        );
      }
    ) manifests.${redistName};
in
# Get rid of packages marked broken and scrub all jobs.
recursiveScrubAndKeepEvaluatable (
  releaseLib.mapTestOn (
    if redistName == "cuda" then
      # CUDA redists are in versioned attribute sets at the top level since they are effectively instances of the CUDA
      # package set -- they're not nested within CUDA package sets.
      getRedistSet [ ] redistName
    else
      # All other redistributables are nested within CUDA package sets.
      lib.mapAttrs (
        cudaPackageSetName: lib.const (getRedistSet [ cudaPackageSetName ] redistName)
      ) releaseLib.pkgs.cudaPackagesVersions
  )
)
