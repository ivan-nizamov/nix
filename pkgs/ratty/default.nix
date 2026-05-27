{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, fontconfig
, libxkbcommon
, vulkan-loader
, wayland
, xorg
}:

stdenv.mkDerivation rec {
  pname = "ratty";
  version = "0.4.0";

  src = fetchurl {
    url = "https://github.com/orhun/ratty/releases/download/v${version}/ratty-x86_64-unknown-linux-gnu.tar.xz";
    hash = "sha256-BZBd+vxKKMMtrn2VIPcp7VxrwFZn+UL8h9Ky9kcH7tw=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    fontconfig
    libxkbcommon
    stdenv.cc.cc.lib
    wayland
    xorg.libX11
    xorg.libXcursor
    xorg.libXi
    xorg.libXrandr
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 ratty "$out/bin/ratty"
    install -Dm644 LICENSE "$out/share/licenses/ratty/LICENSE"
    install -Dm644 README.md "$out/share/doc/ratty/README.md"
    install -Dm644 CHANGELOG.md "$out/share/doc/ratty/CHANGELOG.md"

    wrapProgram "$out/bin/ratty" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath (buildInputs ++ [ vulkan-loader ])}"

    runHook postInstall
  '';

  meta = {
    description = "GPU-rendered terminal emulator with inline 3D graphics";
    homepage = "https://github.com/orhun/ratty";
    license = lib.licenses.mit;
    mainProgram = "ratty";
    platforms = [ "x86_64-linux" ];
  };
}
