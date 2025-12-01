final: prev: {
  # nlohmann_json breaks with GCC 11 with an error like this:
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
  # Though the nlohmann_json implementation is correct, and this may be a bug in GCC 11 or NVCC's pre-processor or
  # frontend, it's easiest to patch nlohmann_json to work around this issue. The patch just uses a trivially
  # constructed boolean value instead of using declval.
  nlohmann_json =
    let
      # TODO(@connorbaker): Does this impact versions of GCC older than 11?
      isGCC11 = cc: cc.isGNU && final.lib.versions.major cc.version == "11";
    in
    if isGCC11 final.cudaPackages.backendStdenv.cc || isGCC11 final.stdenv.cc then
      prev.nlohmann_json.overrideAttrs (prevAttrs: {
        postPatch = prevAttrs.postPatch or "" + ''
          nixLog "Fixing GCC 11 declval issue by patching $PWD/include/nlohmann/detail/meta/is_sax.hpp"
          substituteInPlace "$PWD/include/nlohmann/detail/meta/is_sax.hpp" \
            --replace-fail \
              'std::declval<bool>()' \
              'bool{}'
        '';
      })
    else
      prev.nlohmann_json;
}
