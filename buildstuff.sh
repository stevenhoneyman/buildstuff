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

## destination prefix for musl libc
export _pfx=/musl
## destination for compiles using glibc
export _bin=$HOME/bin
## configs, patches, etc
export _breqs=/opt/reqs
## local already cloned git sources
export _gitdir=$HOME/git
## additional busybox applets
export _bbext=$HOME/bbext
## temp dir for compiling
export _tmp=$(mktemp -d)

## clone depth for stuff you don't have already.
## the lower the number, the more chance of a version generator problem.
## set to 1 if you don't care, or have a crap internet connection
export _gitdepth=100

## comment this line out to use latest (or uncomment to use specific snapshot)
#export _ncurses='ncurses-5.9-20140927.tgz'

unset CC CXX CFLAGS CPPFLAGS CXXFLAGS LDFLAGS
export CC="musl-gcc"
export CXX=/bin/false
export CFLAGS='-s -Os -march=x86-64 -mtune=generic -pipe -fno-strict-aliasing -fomit-frame-pointer -falign-functions=1 -falign-jumps=1 -falign-labels=1 -falign-loops=1 -fno-asynchronous-unwind-tables -fno-unwind-tables -fvisibility=hidden -D_GNU_SOURCE'
export _orig_CFLAGS="${CFLAGS}"

#######################

#if [ -e "$_pfx" ] && [ -z "$NODIRCHECK" ]; then
#	echo "$_pfx already exists, delete it and re-run"
#	exit 1
#fi
mkdir -p "$_pfx" || exit 1

function msg1() { echo -e "\e[91m==> $@\e[0m"; } # red
function msg2() { echo -e "\e[92m==> $@\e[0m"; } # green
function msg3() { echo -e "\e[93m==> $@\e[0m"; } # yellow
function msg4() { echo -e "\e[94m==> $@\e[0m"; } # blue
function msg5() { echo -e "\e[95m==> $@\e[0m"; } # magenta
function msg6() { echo -e "\e[96m==> $@\e[0m"; } # cyan
function msg7() { echo -e "\e[97m==> $@\e[0m"; } # white
for i in {1..7}; do export -f msg$i ; done

function git_pkg_ver() {
	[[ -f "config.h" ]] && cf="config.h"
	[[ -f "include/config.h" ]] && cf="include/config.h"
	[[ -f "lib/config.h" ]] && cf="lib/config.h"
	[[ ! -z "$2" ]] && cf="$2"

	if [[ -f "$cf" ]]; then
	    echo $(awk '/PACKAGE_VERSION/ {gsub(/"/,"",$3); print "'$1' "$3}' $cf)-$(git log -1 --format=%cd.%h --date=short|tr -d -)
	else
	    echo "$1 $(git log -1 --format=%cd.%h --date=short|tr -d -)"
	fi
}

function new_pkg_ver() {
	sed -i "/^$1/d" "${_pfx}/version"
}

function cc_wget() {
	[[ $# -lt 2 ]] && return
	wget -nv "$1" -O - | $CC $CFLAGS $LDFLAGS -x c - -s -o "$2"
}

function download_source() {
  local url="no"
  case $1 in
	musl) 		url="git://git.musl-libc.org/musl" ;;
	busybox)	url="git://git.busybox.net/busybox" ;;
	*-headers)	url="git://github.com/sabotage-linux/kernel-headers.git" ;;

	acl)		url="git://git.sv.gnu.org/acl.git" ;;
	attr)		url="git://git.sv.gnu.org/attr.git" ;;
	bash)		url="git://git.sv.gnu.org/bash.git" ;;
#	bison)		url="git://git.sv.gnu.org/bison.git" ;;
	coreutils)	url="git://git.sv.gnu.org/coreutils.git" ;;
#	cryptsetup)	url="git://git.kernel.org/pub/scm/utils/cryptsetup/cryptsetup.git" ;;
#	curl)		url="git://github.com/bagder/curl.git" ;;
	cv)		url="git://github.com/Xfennec/cv.git" ;;
	dash)		url="git://git.kernel.org/pub/scm/utils/dash/dash.git" ;;
	diffutils)	url="git://git.sv.gnu.org/diffutils.git" ;;
	dropbear)	url="git://github.com/mkj/dropbear.git" ;;
	e2fsprogs)	url="git://git.kernel.org/pub/scm/fs/ext2/e2fsprogs.git" ;;
	ethtool)	url="git://git.kernel.org/pub/scm/network/ethtool/ethtool.git" ;;
#	eudev)		url="git://github.com/gentoo/eudev.git" ;;
#	file)		url="git://github.com/file/file.git" ;;
#	findutils)	url="git://git.sv.gnu.org/findutils.git" ;;
	flex)		url="git://git.code.sf.net/p/flex/flex" ;;
	gawk)		url="git://git.sv.gnu.org/gawk.git" ;;
	gnulib)		url="git://git.sv.gnu.org/gnulib.git" ;;
	gzip)		url="git://git.sv.gnu.org/gzip.git" ;;
#	hexedit)	url="git://github.com/pixel/hexedit.git" ;;
	htop)		url="git://github.com/hishamhm/htop.git" ;;
#	icoutils)	url="git://git.sv.gnu.org/icoutils.git" ;;
	iproute2)	url="git://git.kernel.org/pub/scm/linux/kernel/git/shemminger/iproute2.git" ;;
	iptables)	url="git://git.netfilter.org/iptables.git" ;;
	iw)		url="git://git.kernel.org/pub/scm/linux/kernel/git/jberg/iw.git" ;;
	kmod)		url="git://git.kernel.org/pub/scm/utils/kernel/kmod/kmod.git" ;;
	lbzip2)		url="git://github.com/kjn/lbzip2.git" ;;
	libnl-tiny)	url="git://github.com/sabotage-linux/libnl-tiny.git" ;;
#	libpng)		url="git://git.code.sf.net/p/libpng/code" ;;
	lz4)		url="git://github.com/Cyan4973/lz4.git" ;;
	make)		url="git://git.sv.gnu.org/make.git" ;;
#	md5deep)	url="git://github.com/jessek/hashdeep.git" ;;
	mksh)		url="git://github.com/MirBSD/mksh.git" ;;
	multitail)	url="git://github.com/flok99/multitail.git" ;;
	nasm)		url="git://repo.or.cz/nasm.git" ;;
	nbwmon)		url="git://github.com/causes-/nbwmon.git" ;;
	ncdu)		url="git://g.blicky.net/ncdu.git" ;;
	openssl)	url="git://git.openssl.org/openssl.git" ;;
	patch)		url="git://git.sv.gnu.org/patch.git" ;;
	patchelf)	url="git://github.com/NixOS/patchelf.git" ;;
	pigz)		url="git://github.com/madler/pigz.git" ;;
	pipetoys)	url-"git://github.com/AndyA/pipetoys.git" ;;
#	pixelserv)	url="git://github.com/h0tw1r3/pixelserv.git" ;;
	pkgconf)	url="git://github.com/pkgconf/pkgconf.git" ;;
	readline)	url="git://git.sv.gnu.org/readline.git" ;;
	screen)		url="git://git.sv.gnu.org/screen.git" ;;
	sed)		url="git://git.sv.gnu.org/sed.git" ;;
	sstrip)		url="git://github.com/BR903/ELFkickers.git" ;;
	strace)		url="git://git.code.sf.net/p/strace/code" ;;
	tar)		url="git://git.sv.gnu.org/tar.git" ;;
#	tcc)		url="git://repo.or.cz/tinycc.git" ;;
	util-linux)	url="git://git.kernel.org/pub/scm/utils/util-linux/util-linux.git" ;;
#	wget)		url="git://git.sv.gnu.org/wget.git" ;;
	wpa_supplicant)	url="git://w1.fi/hostap.git" ;;
	xz)		url="http://git.tukaani.org/xz.git" ;;
	yasm)		url="git://github.com/yasm/yasm.git" ;;
	zlib)		url="git://github.com/madler/zlib.git" ;;

	## there's always a few awkward ones...
#	distcc) 	svn co -q http://distcc.googlecode.com/svn/trunk/ "$_tmp/distcc-src" ;;
#	mdocml)		wget -nv http://mdocml.bsd.lv/snapshots/mdocml.tar.gz -O-|tar zxf - -C "$_tmp" && mv "$_tmp"/${1}-* "$_tmp"/${1}-src ;;
#	minised)	svn co http://svn.exactcode.de/minised/trunk/ "$_tmp/minised-src" ;;
	nano) 		svn co svn://svn.savannah.gnu.org/nano/trunk/nano "$_tmp/nano-src" ;;
	ncurses)	wget -nv ftp://invisible-island.net/ncurses/current/${_ncurses:-ncurses.tar.gz} -O-| tar zxf - -C "$_tmp" && mv "$_tmp"/${1}-* "$_tmp"/${1}-src ;;
	netcat) 	svn co -q svn://svn.code.sf.net/p/netcat/code/trunk "$_tmp/netcat-src" ;;
	pax-utils) 	(cd "$_tmp" && cvs -qd :pserver:anonymous@anoncvs.gentoo.org:/var/cvsroot co -d ${1}-src gentoo-projects/${1}) ;;
	pcre)		svn co svn://vcs.exim.org/pcre/code/trunk "$_tmp/pcre-src" ;;
	popt) 		(cd "$_tmp" && cvs -qd :pserver:anonymous@rpm5.org:/cvs co -d popt-src popt) ;;
	tree)		wget -nv http://mama.indstate.edu/users/ice/tree/src/tree-1.7.0.tgz -O-|tar zxf - -C "$_tmp" && mv "$_tmp"/${1}-* "$_tmp"/${1}-src ;;
	wol)	 	svn co -q svn://svn.code.sf.net/p/wake-on-lan/code/trunk "$_tmp/wol-src" ;;

	## and a few that I can't find a source repo or daily snapshot of...
	atop)		wget -nv http://www.atoptool.nl/download/$(wget -qO- http://atoptool.nl/downloadatop.php|grep -om1 'atop-[0-9.-]*tar\.gz'|head -n1) -O-|tar zxf - -C "$_tmp" && mv "$_tmp"/${1}-* "$_tmp"/${1}-src ;;
	bc) 		wget -nv ftp://alpha.gnu.org/gnu/bc/bc-1.06.95.tar.bz2 -O-|tar jxf - -C "$_tmp" && mv "$_tmp"/${1}-* "$_tmp"/${1}-src ;;
	cpuid) 		wget -nv http://etallen.com/${1}/$(wget -qO- "http://etallen.com/$1/?C=M;O=D;F=1;P=$1*src*"|grep -om1 "$1.*gz") -O-|tar zxf - -C "$_tmp" && mv "$_tmp"/${1}-* "$_tmp"/${1}-src ;;
	less)		wget -nv http://greenwoodsoftware.com/less/$(wget http://greenwoodsoftware.com/less/download.html -qO-|grep -om1 'less-[0-9]*\.tar\.gz') -O-|tar zxf - -C "$_tmp" && mv "$_tmp"/${1}-* "$_tmp"/${1}-src ;;
	libedit)	wget -nv http://thrysoee.dk/editline/$(wget http://thrysoee.dk/editline/ -qO-|grep -om1 'libedit[0-9.-]*\.tar\.gz'|head -n1) -O-|tar zxf - -C "$_tmp" && mv "$_tmp"/${1}-* "$_tmp"/${1}-src ;;

	## and then there's this! wtf? also, requiring unzip, to unzip unzip is stupid.
#	unzip)	(wget http://antinode.info/ftp/info-zip/$(wget -qO- 'http://antinode.info/ftp/info-zip/?C=M;O=D;P=unzip*.zip'|grep -o 'unzip[0-9a-zA-Z_.-]*\.zip'|head -n1) -O "$_tmp/unzip.zip"
#				unzip "$_tmp"/unzip.zip -d "$_tmp" && rm "$_tmp/unzip.zip" && mv "$_tmp"/unzip* "$_tmp"/unzip-src ) & ;;

	*) url="no" ;;
  esac

  [[ "$url" == "no" ]] && : || \
	git clone --single-branch --depth=${_gitdepth} $url "${_tmp}/${1}-src" || \
	git clone --single-branch $url "${_tmp}/${1}-src"
}
export -f download_source

#for src in musl musl-kernel-headers busybox acl attr bash bc coreutils cpuid cryptsetup cv dash diffutils distcc dropbear e2fsprogs ethtool file findutils gawk gzip hexedit htop icoutils iptables kmod libnl-tiny libpng make mksh multitail nano nasm ncurses netcat openssl patch pax-utils pkgconf popt readline screen sed sstrip strace tar tcc tree util-linux wget yasm zlib ; do


function get_source() {
	local src=$1
	if [ -d "$_gitdir/$src" ]; then
		msg3 "Updating $_gitdir/$src"; cd "$_gitdir/$src" && git pull
		msg6 "Copying $src source"; cp -r "$_gitdir/$src" "$_tmp/${src}-src"
	else
		msg5 "Downloading $src source..."
		download_source "$src"
	fi
}

if [[ ! -z "$GNULIB_SRCDIR" ]]; then
    echo "Using GNUlib from $GNULIB_SRCDIR"
else
    msg5 'Downloading GNUlib. Consider setting $GNULIB_SRCDIR for faster builds'
    download_source gnulib
    export GNULIB_SRCDIR="${_tmp}/gnulib-src"
fi

if [[ -e "$_pfx/bin/pkg-config" ]]; then
    export PKG_CONFIG="$_pfx/bin/pkg-config"
fi

# TODO: if !gcc; then
export STATIC_OPTS="--disable-shared --enable-static"


for inst in $@; do
get_source $inst
case $inst in

musl)
cd "$_tmp/musl-src"
CC=/bin/gcc CFLAGS="-Os -pipe" LDFLAGS="" ./configure --prefix="$_pfx" --disable-shared --disable-debug
make && make install || exit 3
echo "musl $(<VERSION)-$(git log -1 --format=%cd.%h --date=short|tr -d -)" >>"$_pfx/version"
#if [[ -e "/usr/lib/ccache/bin/musl-gcc" ]]; then		# TODO: fix (ccache: error: Could not find compiler "musl-gcc" in PATH)
#    msg2 'ccache symlink found, using that as $CC'
#    export CC="/usr/lib/ccache/bin/musl-gcc"
#else
    export CC="$_pfx/bin/musl-gcc"
#fi
cd "$_tmp/musl-kernel-headers-src"
make ARCH=x86_64 prefix="$_pfx" install
echo "kernel-headers $(git describe --tags|cut -d'-' -f'1,2').$(git log -1 --format=%cd.%h --date=short|tr -d -)" >>"$_pfx/version"
;; ### musl */


busybox)
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
patch -p1 -i "$_breqs/busybox-1.22-httpd-no-cache.patch"
patch -p1 -i "$_breqs/busybox-1.22-ifplugd-musl-fix.patch"
[ -z "$CONFIG" ] || make gconfig
cp .config "$_pfx"/busybox.config
make CC="$_pfx/bin/musl-gcc" && install -Dm755 busybox "$_pfx"/bin/busybox || exit 3
echo busybox $(sed 's/.git//' .kernelrelease)-$(git log -1 --format='%cd.%h' --date=short|tr -d '-') >>"$_pfx/version"
;; ### busybox */

pkgconf)
cd "$_tmp/pkgconf-src"
./autogen.sh
./configure --prefix=${_pfx} CFLAGS="${CFLAGS/-D_GNU_SOURCE/}"
make && make check && make install && strip -s ${_pfx}/bin/pkgconf || exit 3
ln -s "$_pfx"/bin/pkgconf "$_pfx/bin/pkg-config"
git_pkg_ver "pkgconf" >>"$_pfx/version"
export PKG_CONFIG="$_pfx/bin/pkg-config"
;; ### pkgconf */

ncurses)
cd "$_tmp/ncurses-src"
## Generated by:   sh -e ./tinfo/MKfallback.sh /usr/share/terminfo ../misc/terminfo.src /usr/bin/tic linux vt100 xterm xterm-256color >fallback.c
cp ${_breqs}/ncurses-fallback.c ncurses/fallback.c
#
CFLAGS="$CFLAGS -fPIC" ./configure --prefix="$_pfx" --sysconfdir=/etc \
	--enable-{widec,symlinks,pc-files} --disable-rpath \
	--without-{ada,cxx-binding,debug,develop,manpages,shared,tests} \
	--with-{default-terminfo-dir,terminfo-dirs}=/usr/share/terminfo \
	--disable-db-install --with-fallbacks="linux vt100 xterm xterm-256color" #--disable-home-terminfo
make && make install || exit 3
cp -vnpP "$_pfx"/include/ncurses*/* "$_pfx/include/"
awk '/NCURSES_VERSION_STRING/ {gsub(/"/,"",$3); print "ncurses "$3}' config.status >>"$_pfx/version"
;; ### ncurses */

zlib)
cd "$_tmp/zlib-src"
CFLAGS="$CFLAGS -fPIC" ./configure --prefix=${_pfx} --static --64
make && make test && make install || exit 3
make -C contrib/minizip CC=musl-gcc CFLAGS="$CFLAGS"
make -C contrib/untgz CC=musl-gcc CFLAGS="$CFLAGS"
for b in minigzip{,64} contrib/minizip/mini{unz,zip} contrib/untgz/untgz; do
	strip -s $b && cp -v $b "$_pfx/bin/"
done
echo "zlib $(git describe --tags|tr '-' ' ')" >>"$_pfx/version"
;; ### zlib */

popt)
cd "$_tmp/popt-src"
./autogen.sh
CFLAGS="$CFLAGS -fPIC" ./configure --prefix=${_pfx} --disable-{nls,doxygen,shared}
make && make install-strip
awk '/PACKAGE_VERSION/ {gsub(/"/,"",$3); print "popt "$3}' config.h >>"$_pfx/version"
;; ### popt */

make)
cd "$_tmp/make-src"
sed -i '/^SUBDIRS/s/doc//' Makefile.am
autoreconf -fi
patch -p1 -i ${_breqs}/make4-git_bug23273.patch
./configure --prefix=${_pfx} --sysconfdir=/etc \
	--disable-nls --disable-rpath --without-guile
make && strip -s make && cp make "$_pfx/bin/"
git_pkg_ver "make" >>"$_pfx/version"
;; ### make */

htop)
cd "$_tmp/htop-src"
./autogen.sh
./configure --prefix=${_pfx} --sysconfdir=/etc
make && strip -s htop && cp htop "$_pfx/bin/"
git_pkg_ver "htop" >>"$_pfx/version"
;; ### htop */

nano)
cd "$_tmp/nano-src"
./autogen.sh
./configure --prefix=${_pfx} --sysconfdir=/etc --datarootdir=/usr/share \
	--disable-{nls,extra,speller,browser,mouse,wrapping} \
	--disable-{multibuffer,tabcomp,justify,operatingdir} \
	--enable-{color,nanorc,utf8}
make && strip -s src/nano && cp src/nano "$_pfx/bin/"
awk '/PACKAGE_VERSION/ {gsub(/"/,"",$3); print "nano "$3"'$(svnversion)'"}' config.h >>"$_pfx/version"
;; ### nano */

dropbear) 			## *** 272kb with zlib, 227kb without ***
cd "$_tmp/dropbear-src"
patch -p1 -i ${_breqs}/dropbear-65-prevent-warning.patch
autoreconf -fi
./configure --prefix=${_pfx} --sysconfdir=/etc --datarootdir=/usr/share --sbindir=/usr/bin \
	--disable-{lastlog,utmp,utmpx,wtmp,wtmpx,pututline,pututxline,pam} --disable-zlib
sed -e '/#define INETD_MODE/d'      	\
    -e '/#define DROPBEAR_BLOWFISH/d' 	\
    -e '/#define DROPBEAR_ECDH/d'   	\
    -e '/#define DROPBEAR_ECDSA/d'  	\
    -e '/#define DROPBEAR_MD5_HMAC/d' 	\
    -e '/#define DROPBEAR_TWOFISH/d' 	\
    -e '/#define SFTPSERVER_PATH/d' 	\
    -e '/DEFAULT_KEEPALIVE/s/0/30/'     -i options.h
sed -i 's|-dropbear_" DROPBEAR_VERSION|-sshserver_" "2014"|' sysoptions.h
make PROGRAMS="dropbear dropbearkey dbclient" MULTI=1
strip -s dropbearmulti && cp -v dropbearmulti "$_pfx/bin/"
for p in dropbear dropbearkey dbclient ssh; do ln -s dropbearmulti "$_pfx/bin/$p"; done
echo "dropbear $(awk '/define DROPBEAR_VERSION/ {gsub(/"/,"",$3); print $3}' sysoptions.h)-$(git log -1 --format=%cd.%h --date=short|tr -d -)" >>"$_pfx/version"
;; ### dropbear */

xxd)
cc_wget 'https://vim.googlecode.com/hg/src/xxd/xxd.c' "${_pfx}/bin/xxd"
echo "xxd 1.10" >>"$_pfx/version"
;; ### xxd */

strace)
cd "$_tmp/strace-src"
./bootstrap
./configure --prefix=${_pfx}
make && strip -s strace && cp -v strace "$_pfx/bin/"
git_pkg_ver "strace" >>"$_pfx/version"
;; ### strace */

multitail)
cd "$_tmp/multitail-src"
_MT_VER="$(sed 's/VERSION=//' version)-$(git log -1 --format=%cd.%h --date=short|tr -d -)"
sed -i '/ts...mt_started/d; /show_f1 =/d; s/if (show_f1)/if (0)/g' mt.c
${CC} ${CFLAGS} -s *.c -lpanelw -lncursesw -lm -lutil ${LDFLAGS} -o multitail -DUTF8_SUPPORT=yes -DCONFIG_FILE=\"/etc/multitail.conf\" -DVERSION=\"${_MT_VER}\"
install -Dm755 multitail      "${_pfx}/bin/multitail"
install -Dm644 multitail.conf "${_pfx}/etc/multitail.conf"
install -Dm644 multitail.1    "${_pfx}/share/man/man1/multitail.1"
echo "multitail ${_MT_VER}" >>"$_pfx/version"
;; ### multitail */

cv)
cd "$_tmp/cv-src"
${CC} ${CFLAGS} -s *.c -lncursesw ${LDFLAGS} -o "${_pfx}"/bin/cv
echo $(awk '/VERSION/ {gsub(/"/,"",$3); print "'cv' "$3}' cv.h)-$(git log -1 --format=%cd.%h --date=short|tr -d -) >>"$_pfx/version"
;; ### cv */

attr)
cd "$_tmp/attr-src"
./autogen.sh
CFLAGS="$CFLAGS -fPIC" ./configure --prefix=${_pfx} --disable-{nls,rpath,shared,debug}
make && make install-binPROGRAMS install-pkgconfDATA install-pkgincludeHEADERS
git_pkg_ver "attr" >>"$_pfx/version"
;; ### attr */

acl)			#+# requires: attr
cd "$_tmp/acl-src"
./autogen.sh
CFLAGS="$CFLAGS -fPIC" ./configure --prefix=${_pfx} --disable-{nls,rpath,shared,debug}
make && make install-binPROGRAMS install-pkgconfDATA install-pkgincludeHEADERS install-sysincludeHEADERS
git_pkg_ver "acl" >>"$_pfx/version"
;; ### acl */

# TODO: check include/sys/acl.h, include/attr/xattr.h exist before starting coreutils build
coreutils)		#+# requires: acl, attr
cd "$_tmp/coreutils-src"
./bootstrap --skip-po
## Werror breaks compile
sed -i '/as_fn_append CFLAGS.*Werror/d' configure
## visual tweaks
sed -i 's|online help: <%s>\(.n.., PACKAGE_NAME, PACKAGE_\)URL|%s\1VERSION|' src/system.h
sed -i '/redundant message/,/program . . invocation/d' src/system.h
./configure --prefix=${_pfx} --sysconfdir=/etc --disable-{nls,rpath,assert} \
	--enable-{acl,xattr} --without-gmp --enable-no-install-program=stdbuf
make && make install-strip
## let's have the multicall binary as well
./configure --prefix=${_pfx} --sysconfdir=/etc --disable-{nls,rpath,assert} \
	--enable-{acl,xattr} --without-gmp --enable-no-install-program=stdbuf --enable-single-binary=symlinks
make && strip -s src/coreutils && cp -v src/coreutils "$_pfx/bin/"
git_pkg_ver "coreutils" | cut -f1,2,3 -d. >>"$_pfx/version"
;; ### coreutils */

util-linux)
cd "$_tmp/util-linux-src"
./autogen.sh
## sbin... pfft...
sed -i "/^usrsbin_execdir=/ s|/sbin|/bin|g" configure
## hackish fix for musl libc
# TODO: find an actual fix for logger ntp_gettime
sed -i 's|ntp_gettime(&ntptv) == TIME_OK|0|g' misc-utils/logger.c
## minor tweaks
patch -p1 -i ${_breqs}/util-linux-nicer-fdisk.patch
## 1 line descriptions ##
mv sys-utils/swapoff.8 sw8 && cp sys-utils/swapon.8 sys-utils/swapff.8
for mp in $(find *utils -name *.1 -o -name *.8|sed 's%schedutils/ionice.1%%'); do
  sed -i "s#^.*fputs(USAGE_HEADER, \([a-z]*\)#\tfputs(_(\"$(grep -m1 "^$(basename ${mp%%.*})" "$mp"|sed s@\\\"@\'@g)\\\\n\"), \1);\n&#" ${mp%%.*}.c || true
done
mv sw8 sys-utils/swapoff.8
### / ###
./configure --prefix=${_pfx} --without-{python,user,udev,systemd} --disable-{rpath,nls,makeinstall-chown,shared} \
	--disable-{bash-completion,use-tty-group,pylibmount,wall,minix,mesg,uuidd,write,cramfs,switch_root} \
	--enable-fs-paths-extra=/usr/bin --localstatedir=/run --sbindir=${_pfx}/bin --with-pic
make && \
make install-binPROGRAMS install-sbinPROGRAMS install-usrbin_execPROGRAMS install-usrsbin_execPROGRAMS \
	install-nodist_blkidincHEADERS install-nodist_mountincHEADERS install-nodist_smartcolsincHEADERS \
	install-uuidincHEADERS install-exec install-pkgconfigDATA
git_pkg_ver "util-linux" >>"$_pfx/version"
;; ### util-linux */

tree)
cd "$_tmp/tree-src"
make prefix=${_pfx} CC=${CC} CFLAGS="${CFLAGS/-D_GNU_SOURCE/} -DLINUX -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64"
echo "tree 1.7.0" >>"$_pfx/version"
;; ### tree */

iptables)    ## ?? libnftnl libmnl ??
cd "$_tmp/iptables-src"
./autogen.sh
sed -i '/^#inc.*types/a#include <sys/types.h>' include/linux/netfilter.h
sed -i '/^#inc.*6_tab/a#include <sys/types.h>' iptables/xshared.h
CFLAGS="$CFLAGS -D_GNU_SOURCE -D__GLIBC__=2 \
    -DTCPOPT_WINDOW=2 -DTCPOPT_MAXSEG=2 -DTCPOPT_SACK_PERMITTED=4 -DTCPOPT_SACK=5 -DTCPOPT_TIMESTAMP=8" \
./configure --prefix=${_pfx} --sbindir=${_pfx}/bin --sysconfdir=/etc --disable-{shared,ipv6,devel,nftables}
make && make install-strip
git_pkg_ver "iptables" >>"$_pfx/version"
;; ### iptables */

screen)
cd "$_tmp/screen-src/src"
mkdir -p ${_pfx}/extra/screen/terminfo
sed -i "s|tic|tic -o $_pfx/extra/screen|; /chmod/d" Makefile.in
./autogen.sh
./configure --prefix=${_pfx} --disable-pam --enable-{colors256,rxvt_osc,telnet} \
     --with-pty-group=5 --with-socket-dir=/run/screens --with-sys-screenrc=/etc/screenrc
make && make install
rm -f config.h		# yeah, whatever - fix your PACKAGE_VERSION then, GNU!
awk '/^VERSION/ {print "#define PACKAGE_VERSION "$3}' Makefile >config.h
git_pkg_ver "screen" >>"$_pfx/version"
;; ### screen */

dash)
cd "$_tmp/dash-src"
./autogen.sh
CC=${CC} CFLAGS="$CFLAGS -ffunction-sections -fdata-sections" LDFLAGS="-Wl,--gc-sections" \
    ./configure --prefix=${_pfx} --sysconfdir=/etc
make && make install-strip
git_pkg_ver "dash" >>"$_pfx/version"
;; ### dash */

mksh)
cd "$_tmp/mksh-src"
CPPFLAGS="-DMKSH_SMALL_BUT_FAST -DMKSH_S_NOVI -DMKSH_NOPWNAM" sh ./Build.sh -r -c lto
strip -s ./mksh && cp -v mksh "${_pfx}/bin/"
install -Dm644 mksh.1 "${_pfx}/share/man/man1/mksh.1"
install -Dm644 dot.mkshrc "${_pfx}/etc/skel/.mkshrc"
git_pkg_ver "mksh" >>"$_pfx/version"
;; ### mksh */

readline)
cd "$_tmp/readline-src"
CFLAGS="$CFLAGS -fPIC" ./configure --prefix=${_pfx} --with-curses --disable-shared
make && make install-headers && cp -v lib*.a "${_pfx}/lib/"
git_pkg_ver "readline" >>"$_pfx/version"
;; ### readline */

bash)
cd "$_tmp/bash-src"
CFLAGS="${CFLAGS/-Os/-O2} -DDEFAULT_PATH_VALUE='\"/bin\"' -DSYS_BASHRC='\"/etc/bash.bashrc\"' -DSTANDARD_UTILS_PATH='\"/bin\"' -L${_pfx}/lib" \
./configure --prefix=${_pfx} --disable-nls --without-bash-malloc \
    --enable-static-link --enable-readline --with-installed-readline --with-curses
sed -i 's|\(#define PPROMPT\).*$|\1 "[\\\\u@\\\\h \\\\W]\\\\$ "|' config-top.h
sed -i 's|-lcurses|-lncursesw|' Makefile
make && make install-strip
find "${_pfx}/" -name "bashbug*" -delete
git_pkg_ver "bash" >>"$_pfx/version"
;; ### bash */

sstrip)
cd "$_tmp/sstrip-src"
sed -i '/cp doc/d; s/cp /cp -f /g' Makefile
make install prefix=${_pfx} CC="$CC -s" PROGRAMS="elfls objres rebind sstrip"
git_pkg_ver "sstrip" >>"$_pfx/version"
;; ### sstrip */

mesa-utils)
## GLIBC ONLY (needs X11 etc)
mkdir -p "$_tmp/mesa-utils-src" && cd "$_tmp/mesa-utils-src"
wget -nv http://cgit.freedesktop.org/mesa/demos/plain/src/xdemos/glinfo_common.c
wget -nv http://cgit.freedesktop.org/mesa/demos/plain/src/xdemos/glinfo_common.h
wget -nv http://cgit.freedesktop.org/mesa/demos/plain/src/xdemos/glxgears.c
wget -nv http://cgit.freedesktop.org/mesa/demos/plain/src/xdemos/glxinfo.c
gcc $CFLAGS glxinfo.c glinfo_common.c glinfo_common.h $LDFLAGS -lX11 -lGL -o "$_bin"/glxinfo-git -s
gcc $CFLAGS glxgears.c $LDFLAGS -lX11 -lGL -lm -o "$_bin"/glxgears-git -s
git_pkg_ver "mesa-utils" >>"$_pfx/version"
;; ### mesa-utils */

libnl-tiny)
cd "$_tmp/libnl-tiny-src"
make prefix=${_pfx} CC="$CC" CFLAGS="${CFLAGS/-D_GNU_SOURCE/}" ALL_LIBS=libnl-tiny.a install
git_pkg_ver "libnl-tiny" >>"$_pfx/version"
;; ### libnl-tiny */

iproute2)
cd "$_tmp/iproute2-src"
sed -i '/_GLIBC_/d; s/else/if 0/g' include/libiptc/ipt_kernel_headers.h
sed -i '/^TARGET/s/arpd//' misc/Makefile
sed -i '/example/d; s/doc//g' Makefile
make CFLAGS="$CFLAGS -DHAVE_SETNS -I../include" CC="$CC -s" SHARED_LIBS=n PREFIX=${_pfx} SBINDIR=${_pfx}/bin install
git_pkg_ver "iproute2" >>"$_pfx/version"
;; ### iproute2 */

iw)
cd "$_tmp/iw-src"
make prefix=${_pfx} CC="$CC" CFLAGS="$CFLAGS -DCONFIG_LIBNL20 -DLIBNL1_COMPAT -I${_pfx}/include/libnl-tiny" PKG_CONFIG=${_pfx}/bin/pkg-config NLLIBNAME=libnl-tiny
strip -s iw && cp iw "${_pfx}/bin/"
install -Dm644 iw.8 "${_pfx}/share/man/man8/iw.8"
git_pkg_ver "iw" >>"$_pfx/version"
;; ### iw */

xz)
cd "$_tmp/xz-src"
./autogen.sh 2>/dev/null
./configure --prefix=${_pfx} --with-pic \
    --disable-{nls,rpath,symbol-versions,debug,werror,lzmadec,lzmainfo,lzma-links,scripts,doc} ${STATIC_OPTS}
make && make install-strip
git_pkg_ver "xz" >>"$_pfx/version"
;; ### xz */

pcre)				#+# requires: readline #+#
cd "$_tmp/pcre-src"
./autogen.sh
./configure --prefix=${_pfx} --disable-{cpp,pcregrep-jit} --with-pic \
    --enable-unicode-properties --enable-pcretest-libreadline  #--enable-pcre16 --enable-pcre32
make && strip -s pcretest && make install-binPROGRAMS install-includeHEADERS install-nodist_includeHEADERS install-libLTLIBRARIES install-pkgconfigDATA
echo "$(awk '/PACKAGE_VERSION/ {gsub(/"/,"",$3); print "pcre "$3}' $cf)-svn$(svnversion)" >>"$_pfx/version"
;; ### pcre */

less)
cd "$_tmp/less-src"
./configure --prefix=${_pfx} --with-regex=regcomp-local
make && make install-strip
echo "less $(sed -n 's|char version.*"\([0-9]*\)".*$|\1|p' version.c)" >>"$_pfx/version"
;; ### less */

nasm)
cd "$_tmp/nasm-src"
./autogen.sh
./configure --prefix=${_pfx}
make nasm ndisasm && make strip && make install
git_pkg_ver "nasm" >>"$_pfx/version"
;; ### nasm */

yasm)				#~# makedeps: python #~#   # daily snapshots don't need python...
cd "$_tmp/yasm-src"
./autogen.sh
./configure --prefix=${_pfx} --disable-{nls,rpath,debug,maintainer-mode} #,python,python-bindings}
make && strip -s ./*asm
make install-binPROGRAMS install-man
git_pkg_ver "yasm" >>"$_pfx/version"
;; ### yasm */

openssl)
cd "$_tmp/openssl-src"
sed -i 's/-DTERMIO/&S/g' Configure
sed -i 's/defined(linux)/0/' crypto/ui/ui_openssl.c
sed -i '/LD_LIBRARY_PATH/d' Makefile.shared
sed -i '/pod2man/s/sh -c/true &/g; /PREFIX.*MANDIR.*SUFFIX/d' Makefile.org
./config --prefix=${_pfx} --openssldir=/etc/ssl -L${_pfx}/lib -I${_pfx}/include no-dso no-krb5 zlib ${CFLAGS} #no-shared
make depend
make build_libs
make build_apps openssl.pc libssl.pc libcrypto.pc
make INSTALL_PREFIX=$PWD/OUT install_sw
## OUT/etc/* ignored
cp -rv OUT/${_pfx}/* ${_pfx}/
mv "${_pfx}"/bin/c_rehash "${_pfx}"/bin/c_rehash.pl
wget -nv "http://git.pld-linux.org/?p=packages/openssl.git;a=blob_plain;f=openssl-c_rehash.sh" -O "${_pfx}"/bin/c_rehash
echo $(awk '/VERSION_NUMBER/ {gsub(/"/,"",$3); print "openssl "$3}' Makefile)-$(git log -1 --format=%cd.%h --date=short|tr -d -) >>"$_pfx/version"
;; ### openssl */

wpa_supplicant)				#+# requires: openssl, zlib
cd "$_tmp/wpa_supplicant-src/wpa_supplicant"
cp defconfig .config
sed -i 's|__uint|uint|g; s|__int|int|g' ../src/drivers/linux_wext.h
sed -i '/wpa_.*s.*LIBS/s/$/& -lz/' Makefile
CFLAGS="$CFLAGS -DCONFIG_LIBNL20=y -I${_pfx}/include/libnl-tiny" CONFIG_LIBNL_TINY=y make
strip -s wpa_{cli,passphrase,supplicant} && make BINDIR=${_pfx}/bin install
install -Dm600 wpa_supplicant.conf "${_pfx}"/etc/wpa_supplicant.conf
git_pkg_ver "wpa_supplicant" >>"$_pfx/version"
;; ### wpa_supplicant */

libedit)
cd "$_tmp/libedit-src"
sed -i 's|-lcurses|-lncursesw|' configure
./configure --prefix=${_pfx} --disable-examples
make && make LN_S=true install-strip
echo $(awk '/PACKAGE_VERSION/ {gsub(/"/,"",$3); print "libedit "$3}' config.h)-$(grep "GE.=" Makefile|cut -d- -f2) >>"$_pfx/version"
;; ### libedit */

flex)
cd "$_tmp/flex-src"
./autogen.sh
sed -i '/doc /d; /tests /d' Makefile.am
./configure --prefix=${_pfx} CXX=/bin/false CXXCPP=/bin/cpp
make -C src flex && strip -s src/flex
make -C src install-binPROGRAMS install-includeHEADERS install-libLTLIBRARIES
git_pkg_ver "flex" >>"$_pfx/version"
;; ### flex */

bc)					#+# requires: libedit, ncurses
cd "$_tmp/bc-src"
./configure --prefix=${_pfx} CFLAGS="$CFLAGS -DLIBEDIT"
make LIBL="-ledit -lncursesw" && strip -s bc/bc && cp -v bc/bc "$_pfx/bin/"
echo "bc 1.06.95" >>"$_pfx/version"
;; ### bc */

cpuid)
cd "$_tmp/cpuid-src"
make CC="$CC -s" CFLAGS="$CFLAGS"
cp -v cpuid "$_pfx/bin/"
echo "cpuid $(sed -n 's@^VERSION=\([0-9.]*\).*$@\1@p' Makefile)" >>"$_pfx/version"
;; ### cpuid */

diffutils)
cd "$_tmp/diffutils-src"
./bootstrap --skip-po
./configure --prefix=${_pfx} --disable-nls --disable-rpath
make && make install-strip
git_pkg_ver "diffutils" >>"$_pfx/version"
;; ### diffutils */

patch)
cd "$_tmp/patch-src"
./bootstrap --skip-po
./configure --prefix=${_pfx}
sed -i 's|/usr||g' config.h
make && make install-strip
git_pkg_ver "patch" >>"$_pfx/version"
;; ### patch */

pipetoys)
cd "$_tmp/pipetoys-src"
autoreconf -i
./configure --prefix=${_pfx}
make && make install-strip
git_pkg_ver "pipetoys" >>"$_pfx/version"
;; ### pipetoys */

pax-utils)	# dumpelf, lddtree #
cd "$_tmp/pax-utils-src"
make CC="$CC" CFLAGS="$CFLAGS" USE_CAP=no USE_PYTHON=no PREFIX=${_pfx} strip install
## open to better suggestions here!
pax_ver=$(wget -qO- 'http://sources.gentoo.org/cgi-bin/viewvc.cgi/gentoo-x86/app-misc/pax-utils'|sed -n 's@.*ils-\([0-9.]*\).eb.*@\1@p'|sort -urV|head -n1)
echo "pax-utils ${pax_ver}-cvs" >>"$_pfx/version"
;; ### pax-utils */

wol)
cd "$_tmp/wol-src"
./autogen.sh
sed -i 's/__GLIBC.*/0/g' lib/getline.h
./configure --prefix=${_pfx} --disable-{nls,rpath}
sed -i '/ETHER/s/0/1/g;/STRUCT_ETHER_ADDR_OCTET/d' config.h
make && make install-strip
awk '/define VER/ {gsub(/"/,"",$3); print "wol "$3"'$(svnversion)'"}' config.h >>"$_pfx/version"
;; ### wol */

atop)
cd "$_tmp/atop-src"
sed -i '/O2/d; s/lncurses/&w/' Makefile
find . -name "show*.c" -exec sed -i 's@termio.h@termios.h@g' '{}' \;
make BINDIR=/bin SBINDIR=/bin CC="$CC -s" CFLAGS="$CFLAGS" DESTDIR="$_pfx" atop
cp -v atop "$_pfx/bin/"
cp -v man/atop.1 "$_pfx/share/man/man1/"
cp -v man/atoprc.5 "$_pfx/share/man/man5/"
awk '/ATOPVER/ {gsub(/"/,"",$3); print "atop "$3}' version.h >>"$_pfx/version"
;; ### atop */

netcat)
cd "$_tmp/wol-src"
autoreconf -i
./configure --prefix=${_pfx} --disable-{nls,rpath,debug}
make && make install-strip
awk '/define VER/ {gsub(/"/,"",$3); print "netcat "$3"'$(svnversion)'"}' config.h >>"$_pfx/version"
;; ### netcat */

ncdu)
cd "$_tmp/ncdu-src"
autoreconf -fi
./configure --prefix=${_pfx}
make && make install-strip
git_pkg_ver "ncdu" >>"$_pfx/version"
;; ### ncdu */

sed)
cd "$_tmp/sed-src"
./bootstrap --skip-po
./configure --prefix=${_pfx} --disable-{nls,rpath,i18n}
make && make install-strip
git_pkg_ver "sed" >>"$_pfx/version"
;; ### sed */

gawk)
cd "$_tmp/gawk-src"
./bootstrap.sh
sed -i 's/lncurses/&w/g' configure
./configure --prefix=${_pfx} --disable-{nls,rpath,extensions}
make && strip -s gawk
cp -v gawk "$_pfx/bin/"
cp -v doc/gawk.1 "$_pfx/share/man/man1/"
git_pkg_ver "gawk" >>"$_pfx/version"
;; ### gawk */

tar)
cd "$_tmp/tar-src"
./bootstrap --skip-po
sed -i 's/-Werror//g' configure
./configure --prefix=${_pfx} --disable-{nls,rpath} --with-rmt=/bin/rmt
make && make install-strip
git_pkg_ver "tar" >>"$_pfx/version"
;; ### tar */

gzip)
cd "$_tmp/gzip-src"
./bootstrap --skip-po
sed -i 's/-Werror//g' configure
./configure --prefix=${_pfx}
make && make install-strip
git_pkg_ver "gzip" >>"$_pfx/version"
;; ### gzip */

pigz)
cd "$_tmp/pigz-src"
make pigz CC="$CC -s" CFLAGS="$CFLAGS"
cp -v pigz "$_pfx/bin/"
cp -v pigz.1 "$_pfx/share/man/man1/"
echo "pigz $(git describe --tags)" >>"$_pfx/version"
;; ### pigz */

kmod)
cd "$_tmp/kmod-src"
autoreconf -fi
./configure --prefix=${_pfx} --disable-{debug,python,maintainer-mode} --enable-{tools,manpages} --with-{pic,xz,zlib}
make && make install-strip
git_pkg_ver "kmod" >>"$_pfx/version"
;; ### kmod */

e2fsprogs)
cd "$_tmp/e2fsprogs-src"
patch -p1 -i ${_breqs}/e2fsprogs-magic_t-fix.patch
./configure --prefix=${_pfx} --sbindir=${_pfx}/bin --enable-symlink-{build,install} --enable-relative-symlinks \
    --disable-{nls,rpath,fsck,uuidd,libuuid,libblkid,tls,e2initrd-helper}
make && make install-strip
git_pkg_ver "e2fsprogs" >>"$_pfx/version"
;; ### e2fsprogs */

ethtool)
cd "$_tmp/ethtool-src"
./autogen.sh
sed -i 's/__uint/uint/g; s/__int/int/g' internal.h
./configure --prefix=${_pfx} --sbindir=${_pfx}/bin
make && make install-strip
git_pkg_ver "ethtool" >>"$_pfx/version"
;; ### ethtool */

hexedit)
;; ### hexedit */

mdocml)
;; ### mdocml */

tcc)
;; ### tcc */

minised)
;; ### minised */

bison)
;; ### bison */

cryptsetup)
;; ### cryptsetup */

file)
;; ### file */

findutils)
;; ### findutils */

libpng)
;; ### libpng */

icoutils)
;; ### icoutils */

wget)
;; ### wget */

curl)
;; ### curl */

md5deep)
;; ### md5deep */

nbwmon)
;; ### nbwmon */

lz4)
;; ### lz4 */

dhcpcd)
;; ### dhcpcd */

pixelserv)
;; ### pixelserv */



*) ;;
esac
done
exit




# remove libtool junk
find "$_pfx" -type f -name *.la -delete

# compress man pages
find "$_pfx/share/man" -type f -exec gzip -9 '{}' \;

# trash the downloaded source
rm -rf "$_tmp"
