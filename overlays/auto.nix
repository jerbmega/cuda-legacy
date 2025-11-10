# Adds attributes which do not yet exist to top-level, drawing from
# gccVersions, gccStdenvVersions, and cudaPackagesVersions.
final: prev:
let
  inherit (builtins)
    attrNames
    foldl'
    groupBy
    hasAttr
    mapAttrs
    seq
    tryEval
    ;

  groupBy' =
    op: nul: pred: lst:
    mapAttrs (name: foldl' op nul) (groupBy pred lst);

  getAttrOr =
    attrs: name: value:
    # Attributes may have been aliases since removed and replaced with throws;
    # can't just check for existence, need to catch errors as well.
    # NOTE: .value is false if eval fails, else it is the result of evaluation.
    # NOTE: We must use seq to force accessing the value, ensuring it is not a throw.
    # NOTE: We cannot use deepSeq as the value may be recursive.
    if (tryEval (seq (attrs.${name} or null) (hasAttr name attrs))).value then attrs.${name} else value;

  cudaPackagesMajorVersionAliases =
    groupBy'
      (
        # cudaPackages is the accumulator. Because this is implemented with foldl, it is initially null.
        # After that, it should never be null.
        cudaPackages: name:
        let
          cudaPackages' = prev.cudaPackagesVersions.${name};
        in
        # If current cudaPackages is null or older than the other cudaPackages, use the other cudaPackages
        if cudaPackages == null || cudaPackages.cudaOlder cudaPackages'.cudaMajorMinorPatchVersion then
          cudaPackages'
        else
          cudaPackages
      )
      null
      (name: builtins.head (builtins.match "^(cudaPackages_[[:digit:]]+).*$" name))
      # NOTE: Must use attribute set names instead of values because only the names are strictly evaluated and therefore
      # won't cause infinite recursion.
      (attrNames prev.cudaPackagesVersions);

  # If the attribute exists in `prev` already, pass it through unchanged.
  # Otherwise, use the value provided.
  unchangedIfPresent = mapAttrs (getAttrOr prev);
in
unchangedIfPresent prev.gccVersions
// unchangedIfPresent prev.gccStdenvVersions
// unchangedIfPresent prev.cudaPackagesVersions
// unchangedIfPresent cudaPackagesMajorVersionAliases
