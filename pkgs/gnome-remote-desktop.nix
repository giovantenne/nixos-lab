# Overlay for gnome-remote-desktop: enable VNC backend and allow multiple
# concurrent VNC sessions (upstream only allows one).
#
# Veyon's "External VNC Server" plugin connects to grd's VNC port (5900)
# each time the master requests a screen view.  The upstream code in
# grd-vnc-server.c refuses a second connection.  We patch that guard out
# so Veyon can reconnect freely.
{ prev }:

prev.gnome-remote-desktop.overrideAttrs (oldAttrs: {
  buildInputs = (oldAttrs.buildInputs or []) ++ [
    prev.libvncserver
  ];

  mesonFlags = (oldAttrs.mesonFlags or []) ++ [
    "-Dvnc=true"
  ];

  postPatch = (oldAttrs.postPatch or "") + ''
    # Remove the single-session guard in the VNC server.
    # The original code refuses any new connection when one already exists.
    # We use sed to remove the if-block that rejects new connections,
    # replacing it with a debug log.
    sed -i '/if (vnc_server->sessions)/{
      N; N; N; N; N; N
      s|if (vnc_server->sessions)\n    {\n      /\* TODO: Add the rfbScreen instance to GrdVncServer to support multiple\n       \* sessions\. \*/\n      g_message ("Refusing new VNC connection: already an active session");\n      return TRUE;\n    }|/* Multi-session patch: allow reconnections */\n  if (vnc_server->sessions)\n    g_debug ("New VNC connection while session active; allowing reconnect");|
    }' src/grd-vnc-server.c

    # Verify the patch was applied
    if grep -q "Refusing new VNC connection" src/grd-vnc-server.c; then
      echo "ERROR: Failed to patch out VNC single-session limit"
      exit 1
    fi
  '';
})
