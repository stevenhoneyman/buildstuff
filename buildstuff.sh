#!/bin/bash -e
#
# buildstuff.sh - Compile musl libc, then busybox & some libs
# 2014-10-02 Steven Honeyman <stevenhoneyman at gmail com>
#
##
if [ $UID -eq 0 ]; then
	echo "Don't run this as root; are you crazy?!"
	exit 64
fi

## destination prefix
export _pfx=/musl
## configs, patches, etc
export _breqs=/opt/reqs
## local already cloned git sources
export _gitdir=$HOME/git
## additional busybox applets
export _bbext=$HOME/bbext
## temp dir for compiling
export _tmp=$(mktemp -d)

## comment this line out to use latest (or uncomment to use specific snapshot)
#export _ncurses='ncurses-5.9-20140927.tgz'

unset CC CXX CFLAGS CPPFLAGS CXXFLAGS LDFLAGS
export CXX=/bin/false
export CFLAGS='-s -Os -march=x86-64 -mtune=generic -pipe -D_GNU_SOURCE'

#######################

if [ -e "$_pfx" ] && [ -z "$NODIRCHECK" ]; then
	echo "$_pfx already exists, delete it and re-run"
	exit 1
fi
mkdir -p "$_pfx" || exit 1

function msg1() { echo -e "\e[91m==> $@\e[0m"; } # red
function msg2() { echo -e "\e[92m==> $@\e[0m"; } # green
function msg3() { echo -e "\e[93m==> $@\e[0m"; } # yellow
function msg4() { echo -e "\e[94m==> $@\e[0m"; } # blue
function msg5() { echo -e "\e[95m==> $@\e[0m"; } # magenta
function msg6() { echo -e "\e[96m==> $@\e[0m"; } # cyan
function msg7() { echo -e "\e[97m==> $@\e[0m"; } # white

function git_pkg_ver() {
	[[ -f "config.h" ]] && cf="config.h"
	[[ -f "include/config.h" ]] && cf="include/config.h"
	[[ -f "lib/config.h" ]] && cf="lib/config.h"
	[[ ! -z "$2" ]] && cf="$2"

	[[ -f "$cf" ]] && echo $(awk '/PACKAGE_VERSION/ {gsub(/"/,"",$3); print "'$1' "$3}' $cf)-$(git log -1 --format=%cd.%h --date=short|tr -d -)
}

function cc_wget() {
	[[ $# -lt 2 ]] && return
	wget -nv "$1" -O - | $CC $CFLAGS $LDFLAGS -x c - -s -o "$2"
}

function get_source() {
  local url="no"
  case $1 in
	musl) 		url="git://git.musl-libc.org/musl" ;;
	busybox)	url="git://git.busybox.net/busybox" ;;
	*-headers)	url="git://github.com/sabotage-linux/kernel-headers.git" ;;
	pkgconf)	url="git://github.com/pkgconf/pkgconf.git" ;;
	zlib)		url="git://github.com/madler/zlib.git" ;;

	ncurses)	wget -nv ftp://invisible-island.net/ncurses/current/${_ncurses:-ncurses.tar.gz} -O - | tar zxf - -C "$_tmp" && mv "$_tmp"/${1}-* "$_tmp"/${1}-src ;;

	*) echo "$1 is not a recognized source name" ;;
  esac

  [ $url != "no" ] && \
	git clone --single-branch $url "${_tmp}/${1}-src"
}

for src in musl musl-kernel-headers busybox; do
	if [ -d "$_gitdir/$src" ]; then
		msg3 "Updating $_gitdir/$src"; cd "$_gitdir/$src" && git pull
		msg6 "Copying $src source"; cp -r "$_gitdir/$src" "$_tmp/${src}-src"
	else
		msg5 "Downloading $src source..."
		get_source "$src"
	fi
done

### /* musl
cd "$_tmp/musl-src"
CC=/usr/bin/gcc CFLAGS="-Os" ./configure \
	--prefix="$_pfx" --disable-shared --disable-debug
make && make install || exit 3
echo "musl $(<VERSION)-$(git log -1 --format=%cd.%h --date=short|tr -d -)" >>"$_pfx/version"
export CC="$_pfx/bin/musl-gcc"

cd "$_tmp/musl-kernel-headers-src"
make ARCH=x86_64 prefix="$_pfx" install
echo "kernel-headers $(git describe --tags|cut -d'-' -f'1,2').$(git log -1 --format=%cd.%h --date=short|tr -d -)" >>"$_pfx/version"
### musl */

### /* busybox
cd "$_tmp/busybox-src"
if [ -d "$_bbext" ]; then
    cp -v "$_bbext/nproc/nproc.c" 	"coreutils/nproc.c"
    cp -v "$_bbext/acpi/acpi.c" 	"miscutils/acpi.c"
    cp -v "$_bbext/bin2c/bin2c.c" 	"miscutils/bin2c.c"
    cp -v "$_bbext/uuidgen/uuidgen.c" 	"miscutils/uuidgen.c"
    cp -v "$_bbext/nologin/nologin.c" 	"util-linux/nologin.c"
fi
cp -v "$_breqs/busybox.config" "$_tmp/busybox-src/.config"
patch -p1 -i "$_breqs/busybox-1.22-dmesg-color.patch"
patch -p1 -i "$_breqs/busybox-1.22-ifplugd-musl-fix.patch"
[ -z "$CONFIG" ] || make gconfig
cp .config "$_pfx"/busybox.config
make CC="$_pfx/bin/musl-gcc" && install -Dm755 busybox "$_pfx"/bin/busybox || exit 3
echo busybox $(sed 's/.git//' .kernelrelease)-$(git log -1 --format='%cd.%h' --date=short|tr -d '-') >>"$_pfx/version"
### busybox */

### /* pkgconf
cd "$_tmp/pkgconf-src"
./autogen.sh
./configure --prefix=${_pfx} CFLAGS="${CFLAGS/-D_GNU_SOURCE/}"
make && make check && make install && strip -s ${_pfx}/bin/pkgconf || exit 3
ln -s "$_pfx"/bin/pkgconf "$_pfx/bin/pkg-config"
git_pkg_ver "pkgconf" >>"$_pfx/version"
export PKG_CONFIG="$_pfx/bin/pkg-config"
### pkgconf */

### /* ncurses
cd "$_tmp/ncurses-src"
## Generated by:   sh -e ./tinfo/MKfallback.sh /usr/share/terminfo ../misc/terminfo.src /usr/bin/tic linux vt100 xterm xterm-256color >fallback.c
cp ${_breqs}/ncurses-fallback.c ncurses/fallback.c
#
CFLAGS="$CFLAGS -fPIC" ./configure --prefix="$_pfx" --sysconfdir=/etc \
	--enable-{widec,symlinks,pc-files} --disable-rpath \
	--without-{ada,cxx-binding,debug,develop,manpages,shared,tests} \
	--with-{default-terminfo-dir,terminfo-dirs}=/usr/share/terminfo \
	--disable-db-install --disable-home-terminfo --with-fallbacks="linux vt100 xterm xterm-256color"
make && make install || exit 3
cp -vnpP "$_pfx"/include/ncursesw/* "$_pfx/include"
awk '/NCURSES_VERSION_STRING/ {gsub(/"/,"",$3); print "ncurses "$3}' config.status >>"$_pfx/version"
### ncurses */

### /* zlib
cd "$_tmp/zlib-src"
CFLAGS="$CFLAGS -fPIC" ./configure --prefix=${_pfx} --static --64
make && make test && make install || exit 3
make -C contrib/minizip CC=musl-gcc CFLAGS="$CFLAGS"
make -C contrib/untgz CC=musl-gcc CFLAGS="$CFLAGS"
for b in minigzip{,64} contrib/minizip/mini{unz,zip} contrib/untgz/untgz; do
	strip -s $b && cp -v $b "$_pfx/bin/"
done
echo "zlib $(git describe --tags|tr '-' ' ')" >>"$_pfx/version"
### zlib */
