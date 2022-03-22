#!/bin/bash

#set -x
WIN_ROON_DIR=".roon"
ROON_DOWNLOAD="http://download.roonlabs.com/builds/RoonInstaller64.exe"
WINE_PLATFORM="win64"
test "$WINE_PLATFORM" = "win32" && ROON_DOWNLOAD="http://download.roonlabs.com/builds/RoonInstaller.exe"
SET_SCALEFACTOR=1
VERBOSE=0

PREFIX="~/$WIN_ROON_DIR"

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
	echo "[$WINE_PLATFORM|$PREFIX] $comment ..."
	if [ $VERBOSE -eq 1 ]; then
		env WINEARCH=$WINE_PLATFORM WINEPREFIX=$PREFIX winetricks "$@"
	else
		env WINEARCH=$WINE_PLATFORM WINEPREFIX=$PREFIX winetricks "$@" >/dev/null 2>&1
	fi

	sleep 2
}

_wine() {
	comment="$1"
	shift
	echo "[$WINE_PLATFORM|$PREFIX] $comment ..."
	if [ $VERBOSE -eq 1 ]; then
		#env WINEARCH=$WINE_PLATFORM WINEPREFIX=$PREFIX wine "$@"
		env WINEARCH=$WINE_PLATFORM WINEPREFIX=$PREFIX WINEDLLOVERRIDES=winemenubuilder.exe=d wine "$@"
	else
		#env WINEARCH=$WINE_PLATFORM WINEPREFIX=$PREFIX wine "$@" >/dev/null 2>&1
		env WINEARCH=$WINE_PLATFORM WINEPREFIX=$PREFIX WINEDLLOVERRIDES=winemenubuilder.exe=d wine "$@" >/dev/null 2>&1
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

# installing .NET needs to be done in a few steps; if we do this at once it fails on a few systems

#_winetricks "Installing .NET 2.0"    -q dotnet20
#_winetricks "Installing .NET 3.0"    -q dotnet30sp1
#_winetricks "Installing .NET 3.5"    -q dotnet35
_winetricks "Installing .NET 4.0"    -q --force dotnet40
#_winetricks "Installing .NET 4.5"    -q --force dotnet45
#_winetricks "Installing .NET 4.5.2"  -q --force dotnet452
#_winetricks "Installing .NET 4.6.2"  -q dotnet462
#_winetricks "Installing .NET 4.7.2"  -q dotnet472
#_winetricks "Installing .NET 4.8"    -q dotnet48

# setting some environment stuff
_winetricks "Setting Windows version to 7" -q win7
_winetricks "Setting DDR to OpenGL"        -q ddr=opengl
_winetricks "Setting sound to ALSA"        -q sound=alsa
#_winetricks "Setting sound to Pulseaudio"  -q sound=pulse # roon doesn't support pulse
_winetricks "Disabling crash dialog"       -q nocrashdialog

rm -f ./NDP472-KB4054530-x86-x64-AllOS-ENU.exe
wget 'https://download.visualstudio.microsoft.com/download/pr/1f5af042-d0e4-4002-9c59-9ba66bcf15f6/089f837de42708daacaae7c04b7494db/ndp472-kb4054530-x86-x64-allos-enu.exe' -O ./NDP472-KB4054530-x86-x64-AllOS-ENU.exe
_wine "Installing .NET..." ./NDP472-KB4054530-x86-x64-AllOS-ENU.exe /q

sleep 2

# download Roon
rm -f $ROON_DOWNLOAD
test -f $(basename $ROON_DOWNLOAD) || wget $ROON_DOWNLOAD

# install Roon
_wine "Installing Roon" $(basename $ROON_DOWNLOAD)

# create start script
cat << EOF > ./start_roon.sh
#!/bin/bash

SET_SCALEFACTOR=$SET_SCALEFACTOR

PREFIX="$PREFIX"
EXE="\$PREFIX/drive_c/users/$USER/AppData/Local/Roon/Application/Roon.exe"
if [ \$SET_SCALEFACTOR -eq 1 ]; then
	env WINEPREFIX=\$PREFIX wine "\$EXE" -scalefactor=1
else
	env WINEPREFIX=\${PREFIX} wine "\$EXE"
fi
EOF

chmod +x ./start_roon.sh
cp ./start_roon.sh ~/.local/bin/start_roon.sh

# create simple media controls
cat << EOF > ./roon_control.sh
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

chmod +x ./roon_control.sh
cp ./roon_control.sh ~/.local/bin/roon_control.sh

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
xdg-icon-resource install --context apps --size 48 ./icons/32x32.png roon-Roon
xdg-icon-resource install --context apps --size 256 ./icons/256x256.png roon-Roon

# refresh XDG stuff
update-desktop-database ~/.local/share/applications
gtk-update-icon-cache

exit 0