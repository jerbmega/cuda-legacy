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
  inherit (import ./common.nix args) cudaPackageSetNames lib releaseLib;

  # NOTE: Not all packages are written to support earlier CUDA versions.
  # For example, cupy needs the CUDA profiler API, which isn't available in early versions.
  # NOTE: Our overlays do not change the major-versioned or unversioned package sets (e.g., cudaPackages_12,
  # cudaPackages).
  packages = {
    ffmpeg-full = supportedSystems;
    onnxruntime = supportedSystems;
    opencv = supportedSystems;

    gst_all_1.gst-plugins-bad = supportedSystems;

    # TODO: onnx/onnxruntime/onnx-tensorrt Python and CPP versions.

    python3Packages = {
      onnx = supportedSystems;
      onnxruntime = supportedSystems;
      opencv4 = supportedSystems;
      torch = supportedSystems;
      torchaudio = supportedSystems;
      torchvision = supportedSystems;
      triton = supportedSystems;
    };
  };
in
releaseLib.mapTestOn (
  lib.genAttrs cudaPackageSetNames (cudaPackageSetName: {
    pkgs = packages;
  })
)
