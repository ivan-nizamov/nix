{ buildNpmPackage
, fetchurl
, lib
, makeWrapper
, nodejs
, python3
}:

buildNpmPackage rec {
  pname = "context-mode";
  version = "1.0.136";

  src = fetchurl {
    url = "https://registry.npmjs.org/context-mode/-/context-mode-${version}.tgz";
    hash = "sha256-ZvyS8blJ8oCfSX9td+51eB4fsxDBJO9hEX8Hcj8LzVg=";
  };

  npmDepsHash = "sha256-WtsRE1k5iqj74/08IRu9NEbOVahOlpHT9KWvDcp03qs=";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  nativeBuildInputs = [
    makeWrapper
    python3
  ];

  npmInstallFlags = [ "--omit=dev" ];
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/node_modules/context-mode $out/bin
    cp -r . $out/lib/node_modules/context-mode/
    makeWrapper ${nodejs}/bin/node $out/bin/context-mode \
      --add-flags "$out/lib/node_modules/context-mode/cli.bundle.mjs"
    runHook postInstall
  '';

  meta = {
    description = "Context continuity and MCP tools for coding agents";
    homepage = "https://github.com/mksglu/context-mode";
    license = lib.licenses.elastic20;
    mainProgram = "context-mode";
  };
}
