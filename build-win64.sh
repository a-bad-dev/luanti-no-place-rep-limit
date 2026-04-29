#!/bin/bash
# this script is intended to be run in MSYS2 CLANG64

VERSION="5.16.0-rc1"

BOLD="\x1b[1m"
GREEN="\x1b[32m"
RESET="\x1b[0m"

# system update (skip this most of the time)
echo -e "${BOLD}Updating system...${RESET}"
pacman -Syu

# install deps
echo -e "${BOLD}Installing dependencies...${RESET}"
pacman -S patch zip git mingw-w64-clang-x86_64-{clang,cmake,ninja,curl-winssl,libpng,libjpeg-turbo,freetype,libogg,libvorbis,sqlite3,openal,zstd,gettext,luajit,SDL2}

# download and extract sources - TODO: download, compile, and use luajit
echo -e "${BOLD}Downloading Luanti source code...${RESET}"
curl -Lo luanti.tar.gz https://github.com/luanti-org/luanti/archive/refs/tags/${VERSION}.tar.gz

gunzip luanti.tar.gz
tar -xf luanti.tar

cd luanti-${VERSION}/

# create and apply patches
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

patch src/client/game.cpp patch-1.patch
patch builtin/settingtypes.txt patch-2.patch

rm patch-[1-2].patch

# configure
echo -e "${BOLD}Preparing to compile...${RESET}"
cmake . -G Ninja -DRUN_IN_PLACE=TRUE

# compile
echo -e "${BOLD}Compiling Luanti...${RESET}"
ninja -j$(nproc)

# bundle DLLs
echo -e "${BOLD}Bundling DLLs...${RESET}"
chmod +x ../bundle_dlls.sh
../bundle_dlls.sh bin/luanti.exe bin/

# build the zip archive of luanti
echo -e "${BOLD}Building zip file...${RESET}"
mkdir -p luanti-${VERSION}-msys2-win64/games/

cp -r bin/ builtin/ client/ clientmods/ textures/ doc/ fonts/ locale/ mods/ worlds/ minetest.conf.example luanti-${VERSION}-msys2-win64/

zip -r9 luanti-${VERSION}-msys2-win64.zip luanti-${VERSION}-msys2-win64/

# clean up
echo -e "${BOLD}Cleaning up...${RESET}"
mv luanti-${VERSION}-msys2-win64.zip ..
cd ..
rm -rf luanti{.tar,-${VERSION}}

echo -e "${BOLD}${GREEN}Done!${RESET}"
