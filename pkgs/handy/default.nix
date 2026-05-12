{ appimageTools, fetchurl }:
let
  pname = "handy";
  version = "0.8.3";
  src = fetchurl {
    url = "https://github.com/cjpais/Handy/releases/download/v${version}/Handy_${version}_amd64.AppImage";
    sha256 = "1518gs96hs3mywdn1gmhr40sbj7xf23k92sw3bbx5j81j1b0kd7j";
  };
  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/usr/share/applications/Handy.desktop $out/share/applications/handy.desktop
    install -Dm444 ${appimageContents}/usr/share/icons/hicolor/128x128/apps/handy.png $out/share/icons/hicolor/128x128/apps/handy.png
  '';
}
