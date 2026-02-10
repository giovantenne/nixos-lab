# Veyon 4.10.0 — classroom management software
# Packaged locally because veyon is not available in nixpkgs.
{ lib
, stdenv
, fetchFromGitHub
, cmake
, pkg-config
, qt6
, qt6Packages
, openssl
, pam
, lzo
, procps
, libjpeg
, zlib
, cyrus_sasl
, openldap
, xorg
, libfakekey
, hicolor-icon-theme
, patchelf
}:

stdenv.mkDerivation rec {
  pname = "veyon";
  version = "4.10.0";

  src = fetchFromGitHub {
    owner = "veyon";
    repo = "veyon";
    rev = "v${version}";
    hash = "sha256-QNPTg/u+UuRhC9LhNyr110Q5F39+GlYmZhmMxjdN/6I=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    qt6.wrapQtAppsHook
    qt6.qttools
    patchelf
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qt5compat
    qt6.qtdeclarative
    qt6Packages.qca
    openssl
    pam
    lzo
    procps
    libjpeg
    zlib
    cyrus_sasl
    openldap
    libfakekey
    hicolor-icon-theme
    xorg.libX11
    xorg.libXtst
    xorg.libXrandr
    xorg.libXinerama
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXcomposite
    xorg.libXfixes
    xorg.libXext
  ];

  cmakeFlags = [
    "-DWITH_QT6=ON"
    "-DWITH_BUILTIN_LIBVNC=ON"
    "-DWITH_LTO=OFF"
    "-DWITH_PCH=OFF"
    "-DWITH_UNITY_BUILD=OFF"
    "-DSYSTEMD_SERVICE_INSTALL_DIR=${placeholder "out"}/lib/systemd/system"
    "-DCMAKE_INSTALL_PREFIX=${placeholder "out"}"
    "-DCMAKE_INSTALL_LIBDIR=lib"
    "-DCMAKE_INSTALL_RPATH=$ORIGIN/../lib/veyon"
    "-DCMAKE_BUILD_RPATH=$ORIGIN/../lib/veyon"
    # Skip git-based version info (build from tarball, no .git directory)
    "-DCMAKE_CXX_FLAGS=-Wno-error=deprecated-declarations"
  ];

  env.NIX_CFLAGS_COMPILE = "-Wno-error=maybe-uninitialized";

  qtWrapperArgs = [
    "--prefix"
    "LD_LIBRARY_PATH"
    ":"
    "${placeholder "out"}/lib/veyon"
  ];

  postPatch = ''
    substituteInPlace plugins/filetransfer/FileCollection.h \
      --replace-fail '#include <QFile>' '#include <QFile>
#include <QUuid>'
    substituteInPlace plugins/filetransfer/FileTransferPlugin.cpp \
      --replace-fail '#include <QCoreApplication>' '#include <QCoreApplication>
#include <QGuiApplication>' \
      --replace-fail 'qApp->setQuitOnLastWindowClosed(false);' 'qGuiApp->setQuitOnLastWindowClosed(false);'
    substituteInPlace plugins/filetransfer/FileCollectDialog.cpp \
      --replace-fail '#include <QDesktopServices>' '#include <QDesktopServices>
#include <QDateTime>
#include <QDir>
#include <QMessageBox>'
    substituteInPlace plugins/platform/linux/auth-helper/CMakeLists.txt \
      --replace-fail 'OWNER_READ OWNER_WRITE OWNER_EXECUTE SETUID GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE' 'OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE'

    # Force Raw-only VNC encoding for both remote access and monitoring.
    # The hardcoded encoding strings put ZRLE/Tight first, causing
    # framebuffer corruption with gnome-remote-desktop on Wayland
    # (especially without GPU acceleration).  Raw encoding eliminates
    # incremental delta artifacts — bandwidth is not a concern on LAN.
    substituteInPlace core/src/VncConnection.cpp \
      --replace-fail \
        '"zrle ultra copyrect hextile zlib corre rre raw"' \
        '"raw"' \
      --replace-fail \
        '"tight zywrle zrle ultra"' \
        '"raw"'
  '';

  postFixup = ''
    for binary in "$out"/bin/.veyon-*-wrapped; do
      existing_rpath="$(patchelf --print-rpath "$binary")"
      patchelf --set-rpath "$existing_rpath:$out/lib/veyon" "$binary"
    done

    for plugin in "$out"/lib/veyon/*.so; do
      existing_rpath="$(patchelf --print-rpath "$plugin")"
      patchelf --set-rpath "$existing_rpath:$out/lib/veyon" "$plugin"
    done
  '';

  # Veyon's CMake tries to run git commands for version info; patch them out
  preConfigure = ''
    # Provide version info without git
    substituteInPlace CMakeLists.txt \
      --replace-fail 'GIT_FOUND' 'FALSE'
  '';

  meta = with lib; {
    description = "Cross-platform computer monitoring and classroom management";
    homepage = "https://veyon.io/";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
    maintainers = [];
  };
}
