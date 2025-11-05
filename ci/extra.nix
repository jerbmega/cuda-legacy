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
    blas = supportedSystems;
    blender = supportedSystems;
    cctag = supportedSystems; # Failed in https://github.com/NixOS/nixpkgs/pull/233581
    cholmod-extra = supportedSystems;
    colmap = supportedSystems;
    ctranslate2 = supportedSystems;
    faiss = supportedSystems;
    ffmpeg-full = supportedSystems;
    gimp = supportedSystems;
    gpu-screen-recorder = supportedSystems;
    lapack = supportedSystems;
    lightgbm = supportedSystems;
    llama-cpp = supportedSystems;
    magma = supportedSystems;
    meshlab = supportedSystems;
    monado = supportedSystems; # Failed in https://github.com/NixOS/nixpkgs/pull/233581
    mpich = supportedSystems;
    noisetorch = supportedSystems;
    ollama = supportedSystems;
    onnxruntime = supportedSystems;
    opencv = supportedSystems;
    openmpi = supportedSystems;
    openmvg = supportedSystems;
    openmvs = supportedSystems;
    opentrack = supportedSystems;
    openvino = supportedSystems;
    pixinsight = supportedSystems; # Failed in https://github.com/NixOS/nixpkgs/pull/233581
    qgis = supportedSystems;
    rtabmap = supportedSystems;
    saga = supportedSystems;
    suitesparse = supportedSystems;
    sunshine = supportedSystems;
    truecrack-cuda = supportedSystems;
    tts = supportedSystems;
    ucx = supportedSystems;
    ueberzugpp = supportedSystems; # Failed in https://github.com/NixOS/nixpkgs/pull/233581
    wyoming-faster-whisper = supportedSystems;
    xgboost = supportedSystems;

    gst_all_1.gst-plugins-bad = supportedSystems;

    obs-studio-plugins.obs-backgroundremoval = supportedSystems;

    python3Packages = {
      catboost = supportedSystems;
      cupy = supportedSystems;
      faiss = supportedSystems;
      faster-whisper = supportedSystems;
      flax = supportedSystems;
      gpt-2-simple = supportedSystems;
      grad-cam = supportedSystems;
      jax = supportedSystems;
      jaxlib = supportedSystems;
      keras = supportedSystems;
      kornia = supportedSystems;
      mmcv = supportedSystems;
      mxnet = supportedSystems;
      numpy = supportedSystems; # Only affected by MKL?
      onnx = supportedSystems;
      openai-whisper = supportedSystems;
      opencv4 = supportedSystems;
      opensfm = supportedSystems;
      pycuda = supportedSystems;
      pymc = supportedSystems;
      pyrealsense2WithCuda = supportedSystems;
      pytorch-lightning = supportedSystems;
      scikit-image = supportedSystems;
      scikit-learn = supportedSystems; # Only affected by MKL?
      scipy = supportedSystems; # Only affected by MKL?
      spacy-transformers = supportedSystems;
      tensorflow = supportedSystems;
      tensorflow-probability = supportedSystems;
      tesserocr = supportedSystems;
      tiny-cuda-nn = supportedSystems;
      torch = supportedSystems;
      torchaudio = supportedSystems;
      torchvision = supportedSystems;
      transformers = supportedSystems;
      triton = supportedSystems;
      ttstokenizer = supportedSystems;
      vidstab = supportedSystems;
      vllm = supportedSystems;
    };
  };
in
releaseLib.mapTestOn (
  lib.genAttrs cudaPackageSetNames (cudaPackageSetName: {
    pkgs = packages;
  })
)
