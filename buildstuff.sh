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

unset CC CXX CFLAGS CPPFLAGS CXXFLAGS LDFLAGS
export CXX=/bin/false
export CFLAGS='-s -Os -march=x86-64 -mtune=generic -pipe -D_GNU_SOURCE'

#######################

if [ -e "$_pfx" ] && [ -z "$NODIRCHECK" ]; then
	echo "$_pfx already exists, delete it and re-run"
	exit 1
fi
mkdir -p "$_pfx" || exit 1

function get_source() {
  local url="no"
  case $1 in
	musl) 		url="git://git.musl-libc.org/musl" ;;
	busybox)	url="git://git.busybox.net/busybox" ;;
	*-headers)	url="git://github.com/sabotage-linux/kernel-headers.git" ;;

	*) echo "$1 is not a recognized source name" ;;
  esac

  [ $url != "no" ] && \
	git clone --single-branch $url "${_tmp}/${1}-src"
}

for src in musl musl-kernel-headers busybox; do
	if [ -d "$_gitdir/$src" ]; then
		echo "Updating $_gitdir/$src"; cd "$_gitdir/$src" && git pull
		echo "Copying $src source"; cp -r "$_gitdir/$src" "$_tmp/${src}-src"
	else
		echo "Downloading $src source..."
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
