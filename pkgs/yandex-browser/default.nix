{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, wrapGAppsHook3
, makeWrapper
, flac
, gnome2
, harfbuzzFull
, nss
, snappy
, xdg-utils
, xorg
, alsa-lib
, atk
, cairo
, cups
, curl
, dbus
, expat
, fontconfig
, freetype
, gdk-pixbuf
, glib
, gtk3
, libGL
, libGLU
, libX11
, libxcb
, libXScrnSaver
, libXcomposite
, libXcursor
, libXdamage
, libXext
, libXfixes
, libXi
, libXrandr
, libXrender
, libXtst
, libcap
, libdrm
, libnotify
, libopus
, libpulseaudio
, libuuid
, libva
, libxshmfence
, vulkan-loader
, pciutils
, mesa
, nspr
, pango
, systemd
, at-spi2-atk
, at-spi2-core
, wayland
}:

let
  srcPname = "yandex-browser-stable";
  version = "26.3.1.1088-1";
  browserName = "yandex-browser";
  folderName = "browser";
in
stdenv.mkDerivation rec {
  pname = browserName;
  inherit version;

  src = fetchurl {
    url = "https://repo.yandex.ru/yandex-browser/deb/pool/main/y/${srcPname}/${srcPname}_${version}_amd64.deb";
    hash = "sha256-ivVrWIxI8pZThohvmK6flbmMi18cIIR7BvfLLNKTK6A=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    wrapGAppsHook3
    makeWrapper
  ];

  buildInputs = [
    flac
    harfbuzzFull
    nss
    snappy
    xdg-utils
    xorg.libxkbfile
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    curl
    dbus
    expat
    fontconfig.lib
    freetype
    gdk-pixbuf
    glib
    gnome2.GConf
    gtk3
    libGL
    libGLU
    libX11
    libXScrnSaver
    libXcomposite
    libXcursor
    libXdamage
    libXext
    libXfixes
    libXi
    libXrandr
    libXrender
    libXtst
    libcap
    libdrm
    libnotify
    libopus
    libuuid
    libva
    libxcb
    libxshmfence
    pciutils
    mesa
    nspr
    pango
    wayland
    stdenv.cc.cc.lib
  ];

  autoPatchelfIgnoreMissingDeps = [
    "libQt5Core.so.5"
    "libQt5Gui.so.5"
    "libQt5Widgets.so.5"
    "libQt6Core.so.6"
    "libQt6Gui.so.6"
    "libQt6Widgets.so.6"
  ];

  unpackPhase = ''
    runHook preUnpack
    mkdir -p "$TMPDIR/ya" "$out/bin"
    ar vx "$src"
    tar --no-overwrite-dir -xvf data.tar.xz -C "$TMPDIR/ya"
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    cp -R "$TMPDIR/ya/usr/share" "$out/"
    cp -R "$TMPDIR/ya/opt" "$out/"

    substituteInPlace "$out/share/applications/${browserName}.desktop" \
      --replace /usr/ "$out/"

    chmod +x "$out/opt/yandex/${folderName}/${browserName}"

    makeWrapper "$out/opt/yandex/${folderName}/${browserName}" "$out/bin/${browserName}" \
      --set LD_LIBRARY_PATH "${lib.concatStringsSep ":" runtimeDependencies}" \
      --add-flags ${lib.escapeShellArg "--gl=egl-angle --angle=opengl --use-angle=vulkan --enable-features=Vulkan,VulkanFromANGLE,DefaultANGLEVulkan,VaapiVideoDecoder,VaapiVideoEncoder,UseMultiPlaneFormatForHardwareVideo"}

    ln -s "${browserName}" "$out/bin/${srcPname}"

    runHook postInstall
  '';

  postFixup = ''
    for binary in "$out/opt/yandex/${folderName}/yandex_browser" "$out/opt/yandex/${folderName}/libGLESv2.so"; do
      patchelf --set-rpath "${lib.makeLibraryPath [ libGL vulkan-loader pciutils ]}:$(patchelf --print-rpath "$binary")" "$binary"
    done

    rm -f "$out/opt/yandex/${folderName}/libvulkan.so.1"
    ln -s "${lib.getLib vulkan-loader}/lib/libvulkan.so.1" "$out/opt/yandex/${folderName}/libvulkan.so.1"
  '';

  runtimeDependencies = map lib.getLib [
    libpulseaudio
    curl
    systemd
  ] ++ buildInputs;

  meta = with lib; {
    description = "Yandex Browser";
    homepage = "https://browser.yandex.ru/";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    knownVulnerabilities = [
      ''
        Trusts a Russian government issued CA certificate for some websites.
        See https://habr.com/en/company/yandex/blog/655185/ for details.
      ''
    ];
    mainProgram = browserName;
  };
}
