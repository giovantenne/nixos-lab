# Veyon 4.10.0 — classroom management software
# Packaged locally because veyon is not available in nixpkgs.
{ lib
, stdenv
, fetchFromGitHub
, cmake
, pkg-config
, qt6
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
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qt5compat
    qt6.qtdeclarative
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
    # Skip git-based version info (build from tarball, no .git directory)
    "-DCMAKE_CXX_FLAGS=-Wno-error=deprecated-declarations"
  ];

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
