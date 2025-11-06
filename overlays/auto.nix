# Adds attributes which do not yet exist to top-level, drawing from
# gccVersions, gccStdenvVersions, and cudaPackagesVersions.
final: prev:
let
  getAttrOr =
    attrs: name: value:
    attrs.${name} or value;

  # If the attribute exists in `prev` already, pass it through unchanged.
  # Otherwise, use the value provided.
  unchangedIfPresent = builtins.mapAttrs (getAttrOr prev);
in
unchangedIfPresent prev.gccVersions
// unchangedIfPresent prev.gccStdenvVersions
// unchangedIfPresent prev.cudaPackagesVersions
// {
  # TODO(@connorbaker): Find a better way to do this, perhaps via groupBy, sorting versions,
  # and choosing the latest for a major release if there isn't one.
  cudaPackages_11 = prev.cudaPackages_11 or prev.cudaPackagesVersions.cudaPackages_11_8;
}