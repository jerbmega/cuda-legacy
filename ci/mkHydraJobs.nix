# Produces a Hydra job set for an instance of Nixpkgs using the default CUDA package set version.
{ lib, pkgs }:
let
  inherit (builtins)
    seq
    tryEval
    ;
  inherit (lib)
    attrNames
    concatMapAttrs
    filterAttrs
    flip
    genAttrs
    getAttr
    hasAttr
    hydraJob
    isDerivation
    mapAttrs
    mapAttrs'
    optionalAttrs
    optionals
    recurseIntoAttrs
    ;

  inherit (pkgs) _cuda;

  inherit (pkgs.stdenv.hostPlatform) system;

  canEvalDrvPath = drv: (tryEval (seq drv.drvPath drv.drvPath)).success;

  recursiveMapPackages =
    excludeEvalFailures:
    concatMapAttrs (
      name: value:
      if isDerivation value then
        let
          canEval = canEvalDrvPath value;
        in
        # If we can evaluate the drvPath, trim it for hydraJobs, otherwise include it as-is so we get
        # an error when we try to evaluate/build the package.
        {
          ${if canEval || !excludeEvalFailures then name else null} =
            if canEval then hydraJob value else value;
        }
      else if value.recurseForDerivations or false || value.recurseForRelease or false then
        { ${name} = recursiveMapPackages excludeEvalFailures value; }
      else
        { }
    );

  aggregate =
    args: (pkgs.releaseTools.aggregate args).overrideAttrs { _hydraGlobConstituents = true; };

  # NOTE: Not all packages are written to support earlier CUDA versions.
  # For example, cupy needs the CUDA profiler API, which isn't available in early versions.
  # NOTE: Our overlays do not change the major-versioned or unversioned package sets (e.g., cudaPackages_12,
  # cudaPackages).
  # NOTE: We do not build for non-default capabilities (e.g., Jetson devices, non-baseline feature sets, etc.).
  cudaPackageSetNames =
    # Only supported by x86_64-linux
    optionals (system == "x86_64-linux") [
      "cudaPackages_11_4"
      "cudaPackages_11_5"
      "cudaPackages_11_6"
      "cudaPackages_11_7"
    ]
    ++ [
      "cudaPackages_11_8"
      "cudaPackages_12_0"
      "cudaPackages_12_1"
      "cudaPackages_12_2"
      "cudaPackages_12_3" # Not supported by Jetson
      "cudaPackages_12_4"
      "cudaPackages_12_5"
      "cudaPackages_12_6"
      # There is no 12.7 release
      "cudaPackages_12_8"
      "cudaPackages_12_9"
      "cudaPackages_13_0" # Not supported by Jetson prior to Thor
    ];

  # NOTE: Assumes redist is stand-alone -- that it does not depend on other redistributables.
  mkRedistPackages =
    redistName:
    # NOTE: Manifest version is different from the release version of a package.
    let
      mkRedistPackages' =
        cudaPackages:
        mapAttrs' (redistVersion: redistManifest: {
          name = _cuda.lib.mkVersionedName redistName redistVersion;
          value = recurseIntoAttrs (
            concatMapAttrs (
              name: release:
              let
                pkg = cudaPackages.${name}.overrideAttrs (prevAttrs: {
                  # Our src depends on version.
                  __intentionallyOverridingVersion = true;

                  inherit (release) version;

                  passthru = prevAttrs.passthru // {
                    inherit release;
                  };
                });
              in
              # Filter for supported packages and releases
              optionalAttrs (hasAttr name cudaPackages && canEvalDrvPath pkg) {
                ${name} = pkg;
              }
            ) redistManifest
          );
        }) _cuda.manifests.${redistName};
    in
    genAttrs cudaPackageSetNames (
      cudaPackageSetName: recurseIntoAttrs (mkRedistPackages' pkgs.${cudaPackageSetName})
    );

  # NOTE: Not all packages are written to support earlier CUDA versions.
  # For example, cupy needs the CUDA profiler API, which isn't available in early versions.
  # NOTE: Our overlays do not change the major-versioned or unversioned package sets (e.g., cudaPackages_12,
  # cudaPackages).
  mkJobs =
    pkgs:
    recursiveMapPackages false {
      inherit (pkgs)
        blas
        blender
        cctag # Failed in https://github.com/NixOS/nixpkgs/pull/233581
        cholmod-extra
        colmap
        ctranslate2
        faiss
        ffmpeg-full
        gimp
        gpu-screen-recorder
        lapack
        lightgbm
        llama-cpp
        magma
        meshlab
        monado # Failed in https://github.com/NixOS/nixpkgs/pull/233581
        mpich
        noisetorch
        ollama
        onnxruntime
        opencv
        openmpi
        openmvg
        openmvs
        opentrack
        openvino
        pixinsight # Failed in https://github.com/NixOS/nixpkgs/pull/233581
        qgis
        rtabmap
        saga
        suitesparse
        sunshine
        truecrack-cuda
        tts
        ucx
        ueberzugpp # Failed in https://github.com/NixOS/nixpkgs/pull/233581
        wyoming-faster-whisper
        xgboost
        ;

      gst_all_1 = lib.recurseIntoAttrs {
        inherit (pkgs.gst_all_1) gst-plugins-bad;
      };

      obs-studio-plugins = lib.recurseIntoAttrs {
        inherit (pkgs.obs-studio-plugins) obs-backgroundremoval;
      };

      python3Packages = lib.recurseIntoAttrs {
        inherit (pkgs.python3Packages)
          catboost
          cupy
          faiss
          faster-whisper
          flax
          gpt-2-simple
          grad-cam
          jax
          jaxlib
          keras
          kornia
          mmcv
          mxnet
          numpy # Only affected by MKL?
          onnx
          openai-whisper
          opencv4
          opensfm
          pycuda
          pymc
          pyrealsense2WithCuda
          pytorch-lightning
          scikit-image
          scikit-learn # Only affected by MKL?
          scipy # Only affected by MKL?
          spacy-transformers
          tensorflow
          tensorflow-probability
          tesserocr
          tiny-cuda-nn
          torch
          torchaudio
          torchvision
          transformers
          triton
          ttstokenizer
          vidstab
          vllm
          ;
      };
    };
in
{
  aggregates = {
    cudaPackageSets = genAttrs cudaPackageSetNames (
      cudaPackageSetName:
      aggregate {
        name = cudaPackageSetName;
        # Recall that we are rooted in the flake at .#hydraJobs.<system>
        constituents = [ "${system}.cudaPackageSets.${cudaPackageSetName}.*" ];
      }
    );

    # Everything but the CUDA redist, since that is the foundation of the CUDA Package set.
    # redists = genAttrs [ "cudnn" ] (
    #   redistName:
    #   aggregate {
    #     name = redistName;
    #     constituents = [ "redists.${redistName}.*" ];
    #   }
    # );
  };

  # Individual redists multiplexed over dependencies.
  # redists = recursiveMapPackages true (recurseIntoAttrs {
  #   cudnn = recurseIntoAttrs (
  #     genAttrs cudaPackageSetNames (
  #       cudaPackageSetName: recurseIntoAttrs (mkRedistPackages "cudnn" pkgs.${cudaPackageSetName})
  #     )
  #   );
  # });

  # Exclude failing packages when recursing.
  cudaPackageSets = recursiveMapPackages true (
    recurseIntoAttrs (
      genAttrs cudaPackageSetNames (cudaPackageSetName: recurseIntoAttrs pkgs.${cudaPackageSetName})
    )
  );

  # Exclude failing packages when recursing.
  # packageSets = recursiveMapPackages true (
  #   recurseIntoAttrs (
  #     genAttrs cudaPackageSetNames (
  #       cudaPackageSetName: recurseIntoAttrs (mkJobs pkgs.${cudaPackageSetName}.pkgs)
  #     )
  #   )
  # );
}
