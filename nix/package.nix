{
  lib,
  stdenvNoCC,
  makeWrapper,
  python3,
  qt6,
  libpulseaudio,
  xinput,
}:

let
  python = python3.withPackages (ps: [ ps.pyqt6 ]);
in
stdenvNoCC.mkDerivation {
  pname = "freealien";
  version = "0.1.0";
  src = lib.cleanSource ../.;

  strictDeps = true;
  dontBuild = true;

  nativeBuildInputs = [
    makeWrapper
    qt6.wrapQtAppsHook
  ];
  buildInputs = [ qt6.qtbase ];

  installPhase = ''
    runHook preInstall

    app="$out/share/freealien"
    mkdir -p "$app" "$out/bin" "$out/share/applications" \
      "$out/share/icons/hicolor/scalable/apps" "$out/lib/udev/rules.d" \
      "$out/share/doc/freealien"

    cp -R awcfree_lib packaging "$app/"
    install -m755 freealien "$app/freealien"
    install -m644 README.md CREDITS.md LICENSE "$out/share/doc/freealien/"
    cp -R docs "$out/share/doc/freealien/docs"

    makeWrapper ${python}/bin/python3 "$out/bin/freealien" \
      --add-flags "$app/freealien" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libpulseaudio ]} \
      --prefix PATH : ${lib.makeBinPath [ xinput ]}
    ln -s freealien "$out/bin/awcfree"

    install -m644 packaging/freealien.desktop "$out/share/applications/freealien.desktop"
    install -m644 packaging/freealien.svg \
      "$out/share/icons/hicolor/scalable/apps/freealien.svg"
    install -m644 awcfree_lib/data/70-awcfree.rules \
      "$out/lib/udev/rules.d/70-awcfree.rules"

    runHook postInstall
  '';

  meta = {
    description = "Alienware lighting, cooling, keyboard sounds, and games";
    homepage = "https://github.com/JafarAkhondali/FreeAlien";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "freealien";
  };
}
