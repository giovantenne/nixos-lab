# Overlay for gnome-remote-desktop: enable VNC backend, allow Veyon
# reconnections, and fix framebuffer corruption.
#
# Three patches applied:
#
# 1) VNC backend: enable -Dvnc=true meson flag + libvncserver dependency.
#
# 2) Reconnect: upstream refuses a second VNC connection while one exists.
#    Veyon reconnects frequently.  We replace the guard with code that
#    stops the existing session (destroying rfbScreen, framebuffer, and
#    PipeWire stream) before accepting the new connection.
#
# 3) Encoding: grd sets deferUpdateTime=0 (send immediately) and lets the
#    client pick any encoding (Tight, ZRLE, etc.).  Compressed incremental
#    encodings corrupt on rapid frame delivery, especially without GPU
#    acceleration.  We force Raw encoding via displayHook and set
#    deferUpdateTime=40ms (25fps) for frame coalescing.  On a LAN the
#    extra bandwidth is negligible.
{ prev }:

prev.gnome-remote-desktop.overrideAttrs (oldAttrs: {
  buildInputs = (oldAttrs.buildInputs or []) ++ [
    prev.libvncserver
  ];

  mesonFlags = (oldAttrs.mesonFlags or []) ++ [
    "-Dvnc=true"
  ];

  postPatch = (oldAttrs.postPatch or "") + ''
    # ── Patch 1: Reconnect ──────────────────────────────────────────
    # Replace the single-session guard with code that stops existing
    # sessions before accepting the new connection.
    sed -i '/if (vnc_server->sessions)/{
      :loop
      N
      /return TRUE;/!b loop
      N
      c\  /* Veyon reconnect patch: stop existing sessions before accepting new */\
      while (vnc_server->sessions)\
        {\
          GrdSession *existing = vnc_server->sessions->data;\
          g_debug ("Stopping existing VNC session for reconnect");\
          grd_session_stop (existing);\
        }
    }' src/grd-vnc-server.c

    # Verify reconnect patch
    if grep -q "Refusing new VNC connection" src/grd-vnc-server.c; then
      echo "ERROR: Failed to patch out VNC single-session limit"
      grep -n -A5 -B5 "vnc_server->sessions" src/grd-vnc-server.c
      exit 1
    fi
    if ! grep -q "Stopping existing VNC session for reconnect" src/grd-vnc-server.c; then
      echo "ERROR: Reconnect patch not found in grd-vnc-server.c"
      exit 1
    fi

    # Ensure grd-session.h is included (for grd_session_stop prototype)
    if ! grep -q '#include "grd-session.h"' src/grd-vnc-server.c; then
      sed -i '/#include "grd-vnc-server.h"/a #include "grd-session.h"' src/grd-vnc-server.c
    fi

    # ── Patch 2: Force Raw encoding + frame coalescing ──────────────
    # libvncserver has no server-side encoding restriction API.  The
    # encoding is chosen per-client from cl->preferredEncoding after
    # the client sends SetEncodings.  We override it via displayHook,
    # which fires just before rfbSendFramebufferUpdate() for each
    # client.  This forces Raw (uncompressed, lossless) every frame.
    #
    # We also set deferUpdateTime=40ms so rapid PipeWire frames are
    # coalesced instead of overwhelming the encoder, and limit to one
    # rectangle per update for clean full-screen delivery.

    cat > src/grd-vnc-raw-patch.h << 'RAWPATCH'
    #ifndef GRD_VNC_RAW_PATCH_H
    #define GRD_VNC_RAW_PATCH_H

    #include <rfb/rfb.h>

    /* Force Raw encoding and full-frame updates for every VNC client.
     * Called by libvncserver's displayHook before each framebuffer update. */
    static void
    grd_force_raw_full_frame (rfbClientPtr cl)
    {
      cl->preferredEncoding = rfbEncodingRaw;
      cl->useCopyRect = FALSE;
      cl->enableCursorShapeUpdates = FALSE;
      cl->enableCursorPosUpdates = FALSE;
      cl->useRichCursorEncoding = FALSE;
      cl->enableLastRectEncoding = FALSE;
    }

    #endif /* GRD_VNC_RAW_PATCH_H */
    RAWPATCH

    # Include the header
    sed -i '/#include "grd-vnc-pipewire-stream.h"/a #include "grd-vnc-raw-patch.h"' \
      src/grd-session-vnc.c

    # Replace deferUpdateTime=0 with our tuned settings
    sed -i 's|rfb_screen->deferUpdateTime = 0;|/* Raw encoding + frame coalescing (NixOS overlay) */\
  rfb_screen->deferUpdateTime = 40;\
  rfb_screen->maxRectsPerUpdate = 1;\
  rfb_screen->displayHook = grd_force_raw_full_frame;|' \
      src/grd-session-vnc.c

    # Verify encoding patch
    if ! grep -q "grd_force_raw_full_frame" src/grd-session-vnc.c; then
      echo "ERROR: Raw encoding patch not found in grd-session-vnc.c"
      exit 1
    fi
    if grep -q "deferUpdateTime = 0" src/grd-session-vnc.c; then
      echo "ERROR: deferUpdateTime=0 still present (should be 40)"
      exit 1
    fi
  '';
})
