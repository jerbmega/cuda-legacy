final: prev:
let
  inherit (final.config) cudaSupport;
  stdenvCC = final.stdenv.cc;
  cudaCC = final.cudaPackages.backendStdenv.cc;

  isGCCOlderThan12 =
    let
      test = cc: cc.isGNU && final.lib.versionOlder cc.version "12";
    in
    isGCCOlderThan11 || test stdenvCC || test cudaCC;

  isGCCOlderThan11 =
    let
      test = cc: cc.isGNU && final.lib.versionOlder cc.version "11";
    in
    isGCCOlderThan10 || test stdenvCC || test cudaCC;

  isGCCOlderThan10 =
    let
      test = cc: cc.isGNU && final.lib.versionOlder cc.version "10";
    in
    test stdenvCC || test cudaCC;
in
{
  nlohmann_json =
    if cudaSupport && isGCCOlderThan12 then
      prev.nlohmann_json.overrideAttrs (prevAttrs: {
        postPatch =
          prevAttrs.postPatch or ""
          # nlohmann_json breaks with GCC 10/11 with an error like this:
          #
          # /nix/store/ql0952p3agak5ydjrrqxccq86laiy782-nlohmann_json-3.12.0/include/nlohmann/detail/meta/is_sax.hpp:26:130: error: no matching function for call to 'declval()'
          #    26 | template<typename T>
          #       |                                                                                                                                  ^
          # /nix/store/jxa1m2ggz5cx1pr1f9lvvnbwf0w13ngk-gcc-11.5.0/include/c++/11.5.0/type_traits:2358:1: note: candidate: 'template<class _Tp> decltype (__declval<_Tp>(0)) std::declval()'
          #  2358 |     auto declval() noexcept -> decltype(__declval<_Tp>(0))
          #       | ^   ~~~
          # /nix/store/jxa1m2ggz5cx1pr1f9lvvnbwf0w13ngk-gcc-11.5.0/include/c++/11.5.0/type_traits:2358:1: note:   template argument deduction/substitution failed:
          # /nix/store/ql0952p3agak5ydjrrqxccq86laiy782-nlohmann_json-3.12.0/include/nlohmann/detail/meta/is_sax.hpp:26:130: note:   couldn't deduce template parameter '_Tp'
          #    26 | template<typename T>
          #       |                                                                                                                                  ^
          # /nix/store/ql0952p3agak5ydjrrqxccq86laiy782-nlohmann_json-3.12.0/include/nlohmann/detail/meta/is_sax.hpp:26:130: error: no matching function for call to 'declval()'
          # /nix/store/jxa1m2ggz5cx1pr1f9lvvnbwf0w13ngk-gcc-11.5.0/include/c++/11.5.0/type_traits:2358:1: note: candidate: 'template<class _Tp> decltype (__declval<_Tp>(0)) std::declval()'
          #  2358 |     auto declval() noexcept -> decltype(__declval<_Tp>(0))
          #       | ^   ~~~
          # /nix/store/jxa1m2ggz5cx1pr1f9lvvnbwf0w13ngk-gcc-11.5.0/include/c++/11.5.0/type_traits:2358:1: note:   template argument deduction/substitution failed:
          # /nix/store/ql0952p3agak5ydjrrqxccq86laiy782-nlohmann_json-3.12.0/include/nlohmann/detail/meta/is_sax.hpp:26:130: note:   couldn't deduce template parameter '_Tp'
          #    26 | template<typename T>
          #       |                                                                                                                                  ^
          #
          # Though the nlohmann_json implementation is correct, and this may be a bug in GCC or NVCC's pre-processor or
          # frontend, it's easiest to patch nlohmann_json to work around this issue. The patch just uses a trivially
          # constructed boolean value instead of using declval.
          + ''
            nixLog "Fixing pre-GCC 12 declval issue by patching $PWD/include/nlohmann/detail/meta/is_sax.hpp"
            substituteInPlace "$PWD/include/nlohmann/detail/meta/is_sax.hpp" \
              --replace-fail \
                'std::declval<bool>()' \
                'bool{}'
          '';
      })
    else
      prev.nlohmann_json;

  onnxruntime =
    if cudaSupport && (isGCCOlderThan11 || final.cudaPackages.cudaOlder "11.8") then
      prev.onnxruntime.overrideAttrs (prevAttrs: {
        postPatch =
          prevAttrs.postPatch or ""
          # Enable building with GCC 10.
          # https://github.com/microsoft/onnxruntime/blob/55a38c598f5199f8482c11485e1277799eab3117/cmake/CMakeLists.txt#L255
          + final.lib.optionalString isGCCOlderThan11 ''
            nixLog "Removing requirement for GCC 11.1+ by patching $PWD/cmake/CMakeLists.txt"
            substituteInPlace "$PWD/cmake/CMakeLists.txt" \
              --replace-fail \
                'message(FATAL_ERROR  "GCC version must be greater than or equal to 11.1")' \
                'message(WARNING  "GCC version must be greater than or equal to 11.1")'
          '';

        patches = [
          # CICC fails with LLVM parsing error due to macros in two files:
          # https://github.com/microsoft/onnxruntime/issues/20330
          # I suspect it's because of the template instantiation in the argument to DISPATCH_ANTIALIAS_FILTER_SETUP:
          # https://github.com/microsoft/onnxruntime/blob/2b659e4d1a8a16574b87804c4783e1d36bad7d4d/onnxruntime/core/providers/cuda/tensor/resize_antialias_impl.cu#L762-L764
          # Replacing the variadic argument in DISPATCH_ANTIALIAS_FILTER_SETUP with a single argument yields an error
          # during pre-processing stating DISPATCH_ANTIALIAS_FILTER_SETUP expected two arguments but was provided seven.
          # That roughly lines up with the number of arguments (comma delimited) provided as template parameters.
          ./fixes/onnxruntime/0001-resize_antialias_impl.cu-work-around-NVCC-CUDA-11.4.patch
        ];

        # CUDA versions earlier than 11.8 don't have the necessary definitions for FP8.
        # https://github.com/microsoft/onnxruntime/blob/c156e933b34876c959a4b4c611d2c7dd8e71cafc/onnxruntime/core/providers/cuda/cuda_common.cc#L25-L31
        cmakeFlags =
          prevAttrs.cmakeFlags or [ ]
          # Don't specify unconditionally to avoid overriding defaults.
          ++ final.lib.optionals (final.cudaPackages.cudaOlder "11.8") [
            (final.lib.cmakeBool "onnxruntime_DISABLE_FLOAT8_TYPES" true)
          ];
      })
    else
      prev.onnxruntime;
}
