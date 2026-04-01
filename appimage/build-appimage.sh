#!/bin/bash
set -e

APP_NAME="dangerous-balloons"
VERSION=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "1.0.0")

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/AppDir"

echo "=== Building $APP_NAME AppImage ==="

echo "==> Building application..."
gprbuild -P dangerous_balloons.gpr -p

echo "==> Creating AppDir structure..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/usr/bin"
mkdir -p "$APP_DIR/usr/lib"
mkdir -p "$APP_DIR/usr/share/applications"
mkdir -p "$APP_DIR/usr/share/icons/hicolor/48x48/apps"
mkdir -p "$APP_DIR/usr/share/metainfo"

echo "==> Copying executable..."
cp bin/dangerous-balloons "$APP_DIR/usr/bin/"

echo "==> Copying libraries..."
cp /usr/lib/x86_64-linux-gnu/libncursesada.so.6.2.4 "$APP_DIR/usr/lib/" || echo "Warning: libncursesada.so.6.2.4 not found"
cp /usr/lib/x86_64-linux-gnu/libncurses.so.6 "$APP_DIR/usr/lib/"
cp /usr/lib/x86_64-linux-gnu/libgnat-13.so "$APP_DIR/usr/lib/"
cp /usr/lib/x86_64-linux-gnu/libgcc_s.so.1 "$APP_DIR/usr/lib/"
cp /usr/lib/x86_64-linux-gnu/libc.so.6 "$APP_DIR/usr/lib/"
cp /usr/lib/x86_64-linux-gnu/libform.so.6 "$APP_DIR/usr/lib/" || echo "Warning: libform.so.6 not found"
cp /usr/lib/x86_64-linux-gnu/libmenu.so.6 "$APP_DIR/usr/lib/" || echo "Warning: libmenu.so.6 not found"
cp /usr/lib/x86_64-linux-gnu/libpanel.so.6 "$APP_DIR/usr/lib/" || echo "Warning: libpanel.so.6 not found"
cp /usr/lib/x86_64-linux-gnu/libtinfo.so.6 "$APP_DIR/usr/lib/"
cp /usr/lib/x86_64-linux-gnu/libm.so.6 "$APP_DIR/usr/lib/"

echo "==> Creating AppRun..."
cat >"$APP_DIR/AppRun" <<'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH}"

if [ -t 0 ]; then
    exec "${HERE}/usr/bin/dangerous-balloons" "$@"
else
    for term in xfce4-terminal gnome-terminal konsole xterm kitty alacritty; do
        if command -v "$term" &>/dev/null; then
            case "$term" in
                xfce4-terminal) exec "$term" -x "${HERE}/usr/bin/dangerous-balloons" "$@" ;;
                gnome-terminal) exec "$term" -- "${HERE}/usr/bin/dangerous-balloons" "$@" ;;
                konsole)       exec "$term" -e "${HERE}/usr/bin/dangerous-balloons" "$@" ;;
                xterm)        exec "$term" -e "${HERE}/usr/bin/dangerous-balloons" "$@" ;;
                kitty)        exec "$term" "${HERE}/usr/bin/dangerous-balloons" "$@" ;;
                alacritty)    exec "$term" -e "${HERE}/usr/bin/dangerous-balloons" "$@" ;;
            esac
        fi
    done
    exec "${HERE}/usr/bin/dangerous-balloons" "$@"
fi
EOF
chmod +x "$APP_DIR/AppRun"

echo "==> Creating desktop file..."
cat >"$APP_DIR/com.github.dolgarev.dangerous-balloons.desktop" <<'EOF'
[Desktop Entry]
Name=Dangerous Balloons
Comment=Avoid balloons and blow up walls
Exec=dangerous-balloons
Icon=dangerous-balloons
Type=Application
Categories=Game;
Terminal=true
EOF
cp "$APP_DIR/com.github.dolgarev.dangerous-balloons.desktop" "$APP_DIR/usr/share/applications/"

echo "==> Copying icon..."
if [ -f "$(dirname "$0")/dangerous-balloons.png" ]; then
    cp "$(dirname "$0")/dangerous-balloons.png" "$APP_DIR/dangerous-balloons.png"
    cp "$(dirname "$0")/dangerous-balloons.png" "$APP_DIR/usr/share/icons/hicolor/48x48/apps/"
else
    echo "Warning: dangerous-balloons.png not found, skipping icon."
fi

echo "==> Creating AppStream metainfo..."
cat >"$APP_DIR/com.github.dolgarev.dangerous-balloons.appdata.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<component type="console-application">
  <id>com.github.dolgarev.dangerous-balloons</id>
  <metadata_license>CC0-1.0</metadata_license>
  <project_license>GPL-3.0-only</project_license>
  <name>Dangerous Balloons</name>
  <summary>Avoid balloons and blow up walls</summary>
  <description>
    <p>Dangerous Balloons is a bomberman-style console game.</p>
    <p>Blow up walls, avoid balloons and advance to the next level!</p>
  </description>
  <url type="homepage">https://github.com/dolgarev/dangerous-balloons</url>
  <launchable type="desktop-id">com.github.dolgarev.dangerous-balloons.desktop</launchable>
  <provides>
    <binary>dangerous-balloons</binary>
  </provides>
  <categories>
    <category>Game</category>
  </categories>
  <content_rating type="oars-1.1"/>
</component>
EOF
cp "$APP_DIR/com.github.dolgarev.dangerous-balloons.appdata.xml" "$APP_DIR/usr/share/metainfo/"

if command -v appimagetool &>/dev/null; then
	APPIMAGETOOL="appimagetool"
elif [ -x /tmp/appimagetool ]; then
	APPIMAGETOOL="/tmp/appimagetool"
else
	echo "==> Error: appimagetool not found"
	echo "==> Install AppImageKit: https://github.com/AppImage/AppImageKit"
	echo "    Or download prebuilt binary from: https://github.com/AppImage/AppImageKit/releases"
	echo "    wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O /tmp/appimagetool && chmod +x /tmp/appimagetool"
	exit 1
fi

echo "==> Creating AppImage..."
mkdir -p "$(dirname "$0")/../bin"
"$APPIMAGETOOL" "$APP_DIR" "$(dirname "$0")/../bin/$APP_NAME-$VERSION-x86_64.AppImage"

echo "=== Done! ==="
