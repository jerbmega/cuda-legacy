let
  # Taken and simplified from:
  # https://github.com/NixOS/nixpkgs/blob/d792a6e0cd4ba35c90ea787b717d72410f56dc40/lib/fixed-points.nix#L330-L340
  composeExtensions =
    f: g: final: prev:
    let
      fApplied = f final prev;
    in
    fApplied // g final (prev // fApplied);

  # Composition of extensions is associative, no reason to use foldr.
  composeManyExtensions = builtins.foldl' composeExtensions (final: prev: { });
in
composeManyExtensions [
  # Attribute set which provides the top-level gccVersions and gccStdenvVersions attributes.
  (import ./gccVersions.nix)
  # Attribute set which updates _cuda and provides the top-level cudaPackagesVersions attribute.
  (import ./cudaPackagesVersions.nix)
  # Add attributes which do not exist
  (import ./auto.nix)
]
