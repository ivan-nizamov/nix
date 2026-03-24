{ lib
, stdenv
, autoPatchelfHook
, fetchurl
, libarchive
, makeWrapper
, dbus
, e2fsprogs
, fontconfig
, freetype
, glib
, libdrm
, libglvnd
, libgpg-error
, libxkbcommon
, openssl
, qt6
, wayland
, xkeyboard_config
, xorg
, zlib
, sourceArchive ? fetchurl {
    url = "file:///tmp/happ-install/Happ.linux.x64.pkg.tar.zst";
    hash = "sha256-Z30tdy8QM1cbNaoQgedpZIBv5CF7LVWP7RDPNKbJIuM=";
  }
}:
let
  runtimeLibraries = [
    stdenv.cc.cc.lib
    dbus
    e2fsprogs
    fontconfig
    freetype
    glib
    libdrm
    libglvnd
    libgpg-error
    libxkbcommon
    openssl
    qt6.qtwayland
    wayland
    xorg.libICE
    xorg.libSM
    xorg.libX11
    xorg.libXau
    xorg.libXcomposite
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXdmcp
    xorg.libXext
    xorg.libXfixes
    xorg.libXi
    xorg.libXinerama
    xorg.libXrandr
    xorg.libXrender
    xorg.libXtst
    xorg.libxcb
    xorg.xcbutilcursor
    xorg.libxkbfile
    xorg.libxshmfence
    zlib
  ];
  runtimeLibraryPath =
    lib.makeLibraryPath runtimeLibraries
    + ":$out/opt/happ/lib:$out/opt/happ/bin/tun2";
in
stdenv.mkDerivation rec {
  pname = "happ";
  version = "2.6.0-259";

  src = sourceArchive;

  nativeBuildInputs = [
    autoPatchelfHook
    libarchive
    makeWrapper
  ];

  buildInputs = runtimeLibraries;

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  dontWrapQtApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    bsdtar -xf "$src" -C "$out"

    mkdir -p "$out/bin"

    makeWrapper "$out/opt/happ/bin/Happ" "$out/bin/happ" \
      --argv0 Happ \
      --prefix LD_LIBRARY_PATH : "${runtimeLibraryPath}" \
      --set QT_PLUGIN_PATH "$out/opt/happ/lib/plugins" \
      --set QML2_IMPORT_PATH "$out/opt/happ/lib/qml" \
      --set QT_XKB_CONFIG_ROOT "${xkeyboard_config}/share/X11/xkb"

    substituteInPlace "$out/usr/share/applications/Happ.desktop" \
      --replace-fail 'Exec=/opt/happ/bin/Happ %f' 'Exec=happ %f'

    runHook postInstall
  '';

  preFixup = ''
    while IFS= read -r -d "" dir; do
      addAutoPatchelfSearchPath "$dir"
    done < <(
      find "$out/opt/happ" -type f \
        \( -name '*.so' -o -name '*.so.*' \) \
        -printf '%h\0' | sort -zu
    )
  '';

  meta = with lib; {
    description = "Happ desktop client packaged from the vendor Arch Linux bundle";
    homepage = "https://happ.su";
    license = licenses.unfreeRedistributable;
    mainProgram = "happ";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
  };
}
