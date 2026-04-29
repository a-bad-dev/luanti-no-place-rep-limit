#!/bin/bash -e

# this script is intended to be run on debian 13 x86_64


VERSION="5.16.0-rc1"
SDL_VERSION="2.32.10"

BOLD="\x1b[1m"
RED="\x1b[31m"
GREEN="\x1b[32m"
RESET="\x1b[0m"

# make sure we are root
if [ "$(id -u)" != "0" ]; then
	echo -e "${BOLD}${RED}This script must be run as root!${RESET}"
	exit 1
fi

# install deps
echo -e "${BOLD}Downloading deps...${RESET}"

apt-get install -y --no-install-recommends \
	git \
	g++ \
	make \
	ninja-build \
	libc6-dev \
	cmake \
	curl \
	libpng-dev \
	libjpeg-dev \
	libxi-dev \
	libgl1-mesa-dev \
	libsqlite3-dev \
	libogg-dev \
	libvorbis-dev \
	libopenal-dev \
	libcurl4-openssl-dev \
	libfreetype6-dev \
	zlib1g-dev \
	libgmp-dev \
	libsdl2-dev \
	libzstd-dev \
	libleveldb-dev \
	gettext \
	desktop-file-utils \
	ca-certificates \
	file

# download luajit, SDL2, and luanti source code
echo -e "${BOLD}Downloading LuaJIT, SDL2, and Luanti source code...${RESET}"
git clone --depth=1 https://github.com/LuaJIT/LuaJIT.git luajit
curl -Lo luanti.zip https://github.com/luanti-org/luanti/archive/refs/tags/${VERSION}.zip
curl -Lo sdl2.zip https://github.com/libsdl-org/SDL/releases/download/release-${SDL_VERSION}/SDL2-${SDL_VERSION}.zip

unzip luanti.zip
mv luanti-${VERSION} luanti/
rm luanti.zip

unzip sdl2.zip
mv SDL2-${SDL_VERSION} sdl2
rm sdl2.zip

# create patch files
cat > patch-1.patch <<'EOF'
3753c3753
< 	m_repeat_place_time                  = g_settings->getFloat("repeat_place_time", 0.16f, 2.0f);
---
> 	m_repeat_place_time                  = g_settings->getFloat("repeat_place_time", 0.001f, 2.0f);
EOF

cat > patch-2.patch <<'EOF'
151c151
< repeat_place_time (Place repetition interval) float 0.25 0.16 2.0
---
> repeat_place_time (Place repetition interval) float 0.25 0.001 2.0
EOF

# apply patches
patch luanti/src/client/game.cpp patch-1.patch
patch luanti/builtin/settingtypes.txt patch-2.patch

rm patch-[1-2].patch

# compile luajit
echo -e "${BOLD}Compiling LuaJIT...${RESET}"
cd luajit
make amalg -j$(nproc)
cd ..

# compile sdl2
echo -e "${BOLD}Compiling SDL2...${RESET}"
cd sdl2

mkdir build
cd build

cmake .. -G Ninja \
	-DSDL_INSTALL_CMAKEDIR=usr/lib/cmake/SDL2 \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=/ \
	-DCMAKE_C_FLAGS="-DSDL_LEAN_AND_MEAN=1" \
	-DSDL_{AUDIO,RENDER,VULKAN,TEST,STATIC}=OFF

ninja -j$(nproc)
strip -s *.so
DESTDIR="../../" ninja install -j$(nproc)

cd ../..

# prepare to compile luanti
cd luanti
mkdir -p build
cd build

echo -e "${BOLD}Downloading AppImageTool${RESET}"
curl -Lo appimagetool https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x appimagetool

# compile luanti
echo -e "${BOLD}Compiling Luanti...${RESET}"
cmake .. -G Ninja \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=AppDir/usr \
	-DBUILD_UNITTESTS=OFF \
	-DENABLE_SYSTEM_JSONCPP=OFF \
	-DLUA_INCLUDE_DIR=../../luajit/src/ \
	-DLUA_LIBRARY=../../luajit/src/libluajit.a

# install into the AppDir folder
ninja install -j$(nproc)

# build the appimage itself
cd AppDir

echo -e "${BOLD}Building AppImage...${RESET}"
# put desktop and icon at root of AppDir
ln -sf usr/share/applications/org.luanti.luanti.desktop luanti.desktop
ln -sf usr/share/icons/hicolor/128x128/apps/luanti.png luanti.png
ln -sf luanti.png .DirIcon

# fix locales
mv usr/share/locale usr/share/luanti

cat > AppRun <<'EOF'
#!/bin/bash
APP_PATH="$(dirname "$(readlink -f "${0}")")"
export LD_LIBRARY_PATH="${APP_PATH}"/usr/lib/:"${LD_LIBRARY_PATH}"
exec "${APP_PATH}/usr/bin/luanti" "$@"
EOF

chmod +x AppRun

# bundle the libraries
INCLUDE_LIBS=(
	libopenal.so.1
	libsndio.so.7.0
	libbsd.so.0
	libmd.so.0
	libjpeg.so.62
	libpng16.so.16
	libvorbisfile.so.3
	libogg.so.0
	libvorbis.so.0
	libzstd.so.1
	libsqlite3.so.0
	libleveldb.so.1d
	libsnappy.so.1
)

mkdir -p usr/lib/
for i in "${INCLUDE_LIBS[@]}"; do
	cp /usr/lib/x86_64-linux-gnu/${i} usr/lib/
done

# copy our SDL2 into place
cp ../../../usr/lib/libSDL2-2.0.so.0 usr/lib/

# finally make the appimage
cd ..
ARCH=x86_64 ./appimagetool --appimage-extract-and-run AppDir/

# move the appimage to this script's folder
mv Luanti-x86_64.AppImage ../../luanti-${VERSION}-x86_64.AppImage

# clean up
cd ../..

rm -rf luanti/
rm -rf sdl2/
rm -rf usr/
rm -rf luajit/

# done :D
echo -e "${BOLD}${GREEN}Done!${RESET}"

