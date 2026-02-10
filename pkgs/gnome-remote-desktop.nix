# Overlay for gnome-remote-desktop: enable VNC backend and allow Veyon
# reconnections by tearing down the previous session cleanly.
#
# Veyon's "External VNC Server" plugin connects to grd's VNC port (5900)
# each time the master requests a screen view.  The upstream code in
# grd-vnc-server.c refuses a second connection while one already exists.
#
# Simply allowing the new connection through (without stopping the old
# session) causes framebuffer corruption: two rfbScreen instances and two
# PipeWire capture streams run simultaneously, resulting in overlapping
# frames and rendering artifacts.
#
# The correct fix: when a new VNC client connects and there is already an
# active session, stop the existing session first (destroying its
# rfbScreen, framebuffer, and PipeWire stream), then accept the new one.
# This mirrors the pattern used in grd_vnc_server_stop().
{ prev }:

prev.gnome-remote-desktop.overrideAttrs (oldAttrs: {
  buildInputs = (oldAttrs.buildInputs or []) ++ [
    prev.libvncserver
  ];

  mesonFlags = (oldAttrs.mesonFlags or []) ++ [
    "-Dvnc=true"
  ];

  postPatch = (oldAttrs.postPatch or "") + ''
    # Replace the single-session guard with code that stops existing sessions
    # before accepting the new connection.
    #
    # Original code pattern (upstream):
    #   if (vnc_server->sessions)
    #     {
    #       /* TODO: ... */
    #       g_message ("Refusing new VNC connection: ...");
    #       return TRUE;
    #     }
    #
    # Replacement: stop all existing sessions, clean them up, then continue
    # to accept the new connection normally.
    sed -i '/if (vnc_server->sessions)/{
      # Read the next lines that form the if-block body
      :loop
      N
      /return TRUE;/!b loop
      # Now we have the full if-block; also grab the closing brace
      N
      # Replace the entire block
      c\  /* Veyon reconnect patch: stop existing sessions before accepting new */\
      while (vnc_server->sessions)\
        {\
          GrdSession *existing = vnc_server->sessions->data;\
          g_debug ("Stopping existing VNC session for reconnect");\
          grd_session_stop (existing);\
        }
    }' src/grd-vnc-server.c

    # Verify the patch was applied: the refuse message should be gone
    if grep -q "Refusing new VNC connection" src/grd-vnc-server.c; then
      echo "ERROR: Failed to patch out VNC single-session limit"
      echo "=== Relevant section of grd-vnc-server.c ==="
      grep -n -A5 -B5 "vnc_server->sessions" src/grd-vnc-server.c
      exit 1
    fi

    # Verify grd_session_stop was injected
    if ! grep -q "Stopping existing VNC session for reconnect" src/grd-vnc-server.c; then
      echo "ERROR: Reconnect patch not found in grd-vnc-server.c"
      exit 1
    fi

    # Ensure grd-session.h is included (for grd_session_stop prototype)
    if ! grep -q '#include "grd-session.h"' src/grd-vnc-server.c; then
      sed -i '/#include "grd-vnc-server.h"/a #include "grd-session.h"' src/grd-vnc-server.c
    fi
  '';
})
