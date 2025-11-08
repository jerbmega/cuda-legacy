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
    (import ./common.nix (removeAttrs args [ "redistName" ] // { extraOverlays = [ redistOverlay ]; }))
    lib
    releaseLib
    ;

  # NOTE: Assumes redist is stand-alone -- that it does not depend on other redistributables.
  redistOverlay = final: prev: {
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
in
releaseLib.mapTestOn (
  lib.mapAttrs (
    _: cudaPackages:
    let
      redistVersions = lib.attrNames releaseLib.pkgs._cuda.manifests.${redistName};
      versionedRedistNames = lib.map (releaseLib.pkgs._cuda.lib.mkVersionedName redistName) redistVersions;
    in
    # Extract the versioned redist names from each CUDA package set.
    releaseLib.packagePlatforms (lib.recurseIntoAttrs (lib.getAttrs versionedRedistNames cudaPackages))
  ) releaseLib.pkgs.cudaPackagesVersions
)
