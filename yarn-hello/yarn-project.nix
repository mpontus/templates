# This file is generated by running "yarn install" inside your project.
# Manual changes might be lost - proceed with caution!

{ lib, nodejs, stdenv, fetchurl, writeText, git, cacert }:
{ src, overrideAttrs ? null, ... } @ args:

let

  yarnPath = ./.yarn/releases/yarn-3.2.1.cjs;
  lockfile = ./yarn.lock;
  cacheFolder = ".yarn/cache";

  # Call overrideAttrs on a derivation if a function is provided.
  optionalOverride = fn: drv:
    if fn == null then drv else drv.overrideAttrs fn;

  # Common attributes between Yarn derivations.
  drvCommon = {
    # Make sure the build uses the right Node.js version everywhere.
    buildInputs = [ nodejs ];
    # Tell node-gyp to use the provided Node.js headers for native code builds.
    npm_config_nodedir = nodejs;
    # Tell node-pre-gyp to never fetch binaries / always build from source.
    npm_config_build_from_source = "true";
    # Defines the shell alias to run Yarn.
    postHook = ''
      yarn() {
        CI=1 node "${yarnPath}" "$@"
      }
    '';
  };

  # Create derivations for fetching dependencies.
  cacheDrvs = let
    builder = builtins.toFile "builder.sh" ''
      source $stdenv/setup
      cd "$src"
      HOME="$TMP" yarn_cache_folder="$TMP" CI=1 \
        node '${yarnPath}' nixify fetch-one $locator
      # Because we change the cache dir, Yarn may generate a different name.
      mv "$TMP/$(sed 's/-[^-]*\.[^-]*$//' <<< "$outputFilename")"-* $out
    '';
  in lib.mapAttrs (locator: { filename, sha512 }: stdenv.mkDerivation {
    inherit src builder locator;
    name = lib.strings.sanitizeDerivationName locator;
    buildInputs = [ nodejs git cacert ];
    outputFilename = filename;
    outputHashMode = "flat";
    outputHashAlgo = "sha512";
    outputHash = sha512;
  }) cacheEntries;

  # Create a shell snippet to copy dependencies from a list of derivations.
  mkCacheBuilderForDrvs = drvs:
    writeText "collect-cache.sh" (lib.concatMapStrings (drv: ''
      cp ${drv} '${drv.outputFilename}'
    '') drvs);


  # Main project derivation.
  project = stdenv.mkDerivation (drvCommon // {
    inherit src;
    name = "yarn-hello";
    # Disable Nixify plugin to save on some unnecessary processing.
    yarn_enable_nixify = "false";

    configurePhase = ''
      # Copy over the Yarn cache.
      rm -fr '${cacheFolder}'
      mkdir -p '${cacheFolder}'
      pushd '${cacheFolder}' > /dev/null
      source ${mkCacheBuilderForDrvs (lib.attrValues cacheDrvs)}
      popd > /dev/null

      # Yarn may need a writable home directory.
      export yarn_global_folder="$TMP"

      # Some node-gyp calls may call out to npm, which could fail due to an
      # read-only home dir.
      export HOME="$TMP"

      # running preConfigure after the cache is populated allows for
      # preConfigure to contain substituteInPlace for dependencies as well as the
      # main project. This is necessary for native bindings that maybe have
      # hardcoded values.
      runHook preConfigure



      # Run normal Yarn install to complete dependency installation.
      yarn install --immutable --immutable-cache

      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/libexec $out/bin

      # Move the entire project to the output directory.
      mv $PWD "$out/libexec/$sourceRoot"
      cd "$out/libexec/$sourceRoot"

      # Invoke a plugin internal command to setup binaries.
      yarn nixify install-bin $out/bin

      runHook postInstall
    '';

    passthru = {
      inherit nodejs;
    };
  });

cacheEntries = {
};

in optionalOverride overrideAttrs project
