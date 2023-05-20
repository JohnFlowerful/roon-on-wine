#!/bin/bash

#set -x
MY_ROON_URL="http://download.roonlabs.com/builds/RoonInstaller64.exe"
MY_ARCH="win64"
test "$MY_ARCH" = "win32" && MY_ROON_URL="http://download.roonlabs.com/builds/RoonInstaller.exe"
MY_WINE_ROON_DIR=".roon"

PREFIX="${HOME}/$MY_WINE_ROON_DIR"
WINE_ENV="env WINEARCH=$MY_ARCH WINEPREFIX=$PREFIX WINEDLLOVERRIDES=winemenubuilder.exe=d"

VERBOSE=0

check_executable() {
	local exe=$1

	if ! command -v $exe &> /dev/null; then
		echo "ERROR: can't find $exe, which is required for Roon installation."
		echo "Please install $exe using your distribution package tooling."
		echo
		exit 1
	fi
}

_winetricks() {
	comment="$1"
	shift
	echo "[$MY_ARCH|$PREFIX] $comment ..."

	if [ $VERBOSE -eq 1 ]; then
		$WINE_ENV winetricks "$@"
	else
		$WINE_ENV winetricks "$@" > /dev/null 2>&1
	fi

	sleep 2
}

_wine() {
	comment="$1"
	shift
	echo "[${MY_ARCH}|${PREFIX}] $comment ..."

	if [ $VERBOSE -eq 1 ]; then
		$WINE_ENV wine "$@"
	else
		$WINE_ENV wine "$@" > /dev/null 2>&1
	fi

	sleep 2
}

# check necessary stuff
check_executable wine
check_executable winecfg
check_executable winetricks
check_executable wget
check_executable xdotool

# configure Wine
rm -rf $PREFIX
_wine "Setup Wine bottle" wineboot --init

#_winetricks "Installing .NET 4.7.2"  -q --force dotnet472
#_winetricks "Installing .NET 4.8"    -q dotnet48
_winetricks "Installing .NET 6.0"    -q dotnet6

# setting some environment stuff
_winetricks "Setting Windows version to 10" -q win10 # windows 10 is required for roon 2.0
_winetricks "Setting DDR to OpenGL"         -q renderer=gl
_winetricks "Setting sound to ALSA"         -q sound=alsa
#_winetricks "Setting sound to Pulseaudio"   -q sound=pulse # roon doesn't support pulse
_winetricks "Disabling crash dialog"        -q nocrashdialog

sleep 2

# download Roon
ROON_EXE=$(basename $MY_ROON_URL)
test -f $ROON_EXE || wget $MY_ROON_URL

# install Roon
_wine "Installing Roon" $ROON_EXE

# ensure local bin dir exists
mkdir -p ~/.local/bin

# Preconditions for start script. 
# Need a properly formatted path to the user's Roon.exe in their wine configuration
# Get the Windows OS formatted path to the user's Local AppData folder
WINE_LOCALAPPDATA=$($WINE_ENV wine cmd.exe /c echo %LocalAppData% 2> /dev/null)
# Convert Windows OS formatted path to Linux formatted path from the user's wine configuration
UNIX_LOCALAPPDATA="$($WINE_ENV winepath -u "$WINE_LOCALAPPDATA")"
# Windows line endings carry through winepath conversion. Remove it to get an error free path.
UNIX_LOCALAPPDATA=${UNIX_LOCALAPPDATA%$'\r'} # remove ^M
ROONEXE="Roon/Application/Roon.exe"

# Preconditions for start script met.
# create start script
cat << EOF > ~/.local/bin/start_roon.sh
#!/bin/bash

# This parameter influences the scale at which
# the Roon UI is rendered.
#
# 1.0 is default, but on an UHD screen this should be 1.5 or 2.0

SCALEFACTOR=1.0

PREFIX="$PREFIX"
EXE="${UNIX_LOCALAPPDATA}/${ROONEXE}"
env WINEPREFIX=\$PREFIX WINEDEBUG=fixme-all wine \$EXE -scalefactor=\$SCALEFACTOR
EOF
chmod +x ~/.local/bin/start_roon.sh

# create simple media controls
cat << EOF > ~/.local/bin/roon_control.sh
#!/bin/sh

case \$1 in
	"play")
		key="XF86AudioPlay"
		;;
	"next")
		key="XF86AudioNext"
		;;
	"prev")
		key="XF86AudioPrev"
		;;
	*)
		echo "Usage: $0 play|next|prev"
		exit 1
		;;
esac
xdotool key --window \$(xdotool search --name "Roon" | head -n1) \$key
exit
EOF
chmod +x ~/.local/bin/roon_control.sh

# create XDG stuff
cat << EOF > ~/.local/share/applications/roon.desktop
[Desktop Entry]
Name=Roon
GenericName=Music streaming and management
Exec=~/.local/bin/start_roon.sh
Terminal=false
Type=Application
StartupNotify=true
Icon=roon-Roon
StartupWMClass=roon.exe
Categories=AudioVideo;Audio
EOF

# add icons
xdg-icon-resource install --context apps --size 16 ./icons/16x16.png roon-Roon
xdg-icon-resource install --context apps --size 32 ./icons/32x32.png roon-Roon
xdg-icon-resource install --context apps --size 48 ./icons/48x48.png roon-Roon
xdg-icon-resource install --context apps --size 256 ./icons/256x256.png roon-Roon

# refresh XDG stuff
update-desktop-database ~/.local/share/applications
gtk-update-icon-cache

echo
echo "DONE!"
echo

exit 0
