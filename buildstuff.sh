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

	[[ -f "$cf" ]] && echo $(awk '/PACKAGE_VERSION/ {gsub(/"/,"",$3); print "'$1' "$3}' $cf)-$(git log -1 --format=%cd.%h --date=short|tr -d -)
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
	coreutils)	url="git://git.sv.gnu.org/coreutils.git" ;;
#	cryptsetup)	url="git://git.kernel.org/pub/scm/utils/cryptsetup/cryptsetup.git" ;;
	cv)		url="git://github.com/Xfennec/cv.git" ;;
	dash)		url="git://git.kernel.org/pub/scm/utils/dash/dash.git" ;;
#	diffutils)	url="git://git.sv.gnu.org/diffutils.git" ;;
	dropbear)	url="git://github.com/mkj/dropbear.git" ;;
#	e2fsprogs)	url="git://git.kernel.org/pub/scm/fs/ext2/e2fsprogs.git" ;;
#	ethtool)	url="git://git.kernel.org/pub/scm/network/ethtool/ethtool.git" ;;
#	file)		url="git://github.com/file/file.git" ;;
#	findutils)	url="git://git.sv.gnu.org/findutils.git" ;;
#	gawk)		url="git://git.sv.gnu.org/gawk.git" ;;
#	gzip)		url="git://git.sv.gnu.org/gzip.git" ;;
#	hexedit)	url="git://github.com/pixel/hexedit.git" ;;
	htop)		url="git://github.com/hishamhm/htop.git" ;;
#	icoutils)	url="git://git.sv.gnu.org/icoutils.git" ;;
	iproute2)	url="git://git.kernel.org/pub/scm/linux/kernel/git/shemminger/iproute2.git" ;;
	iptables)	url="git://git.netfilter.org/iptables.git" ;;
	iw)		url="git://git.kernel.org/pub/scm/linux/kernel/git/jberg/iw.git" ;;
#	kmod)		url="git://git.kernel.org/pub/scm/utils/kernel/kmod/kmod.git" ;;
	libnl-tiny)	url="git://github.com/sabotage-linux/libnl-tiny.git" ;;
#	libpng)		url="git://git.code.sf.net/p/libpng/code" ;;
	make)		url="git://git.sv.gnu.org/make.git" ;;
	mksh)		url="git://github.com/MirBSD/mksh.git" ;;
	multitail)	url="git://github.com/flok99/multitail.git" ;;
	nasm)		url="git://repo.or.cz/nasm.git" ;;
#	openssl)	url="git://git.openssl.org/openssl.git" ;;
#	patch)		url="git://git.sv.gnu.org/patch.git" ;;
#	pipetoys)	url-"git://github.com/AndyA/pipetoys.git" ;;
	pkgconf)	url="git://github.com/pkgconf/pkgconf.git" ;;
	readline)	url="git://git.sv.gnu.org/readline.git" ;;
	screen)		url="git://git.sv.gnu.org/screen.git" ;;
#	sed)		url="git://git.sv.gnu.org/sed.git" ;;
	sstrip)		url="git://github.com/BR903/ELFkickers.git" ;;
	strace)		url="git://git.code.sf.net/p/strace/code" ;;
#	tar)		url="git://git.sv.gnu.org/tar.git" ;;
#	tcc)		url="git://repo.or.cz/tinycc.git" ;;
	util-linux)	url="git://git.kernel.org/pub/scm/utils/util-linux/util-linux.git" ;;
#	wget)		url="git://git.sv.gnu.org/wget.git" ;;
	yasm)		url="git://github.com/yasm/yasm.git" ;;
	zlib)		url="git://github.com/madler/zlib.git" ;;

	## there's always a few awkward ones...
#	bc) 		wget -nv ftp://alpha.gnu.org/gnu/bc/bc-1.06.95.tar.bz2 -O-|tar jxf - -C "$_tmp" && mv "$_tmp"/${1}-* "$_tmp"/${1}-src ;;
#	cpuid) 		wget -nv http://etallen.com/${1}/$(wget -qO- "http://etallen.com/$1/?C=M;O=D;F=1;P=$1*src*"|grep -om1 "$1.*gz") -O-|tar zxf - -C "$_tmp" && mv "$_tmp"/${1}-* "$_tmp"/${1}-src ;;
#	distcc) 	svn co -q http://distcc.googlecode.com/svn/trunk/ "$_tmp/distcc-src" ;;
#	less)		echo "TODO" http://www.greenwoodsoftware.com/less/less-458.tar.gz ;;
	nano) 		svn co svn://svn.savannah.gnu.org/nano/trunk/nano "$_tmp/nano-src" ;;
	ncurses)	wget -nv ftp://invisible-island.net/ncurses/current/${_ncurses:-ncurses.tar.gz} -O - | tar zxf - -C "$_tmp" && mv "$_tmp"/${1}-* "$_tmp"/${1}-src ;;
#	netcat) 	svn co -q svn://svn.code.sf.net/p/netcat/code/trunk "$_tmp/netcat-src" ;;
#	pax-utils) 	(cd "$_tmp" && cvs -qd :pserver:anonymous@anoncvs.gentoo.org:/var/cvsroot co -d ${1}-src gentoo-projects/${1}) ;;
	popt) 		(cd "$_tmp" && cvs -qd :pserver:anonymous@rpm5.org:/cvs co -d popt-src popt) ;;
	tree)		wget -nv http://mama.indstate.edu/users/ice/tree/src/tree-1.7.0.tgz -O-|tar zxf - -C "$_tmp" && mv "$_tmp"/${1}-* "$_tmp"/${1}-src ;;

	## and then there's this! wtf? also, requiring unzip, to unzip unzip is stupid.
#	unzip)	(wget http://antinode.info/ftp/info-zip/$(wget -qO- 'http://antinode.info/ftp/info-zip/?C=M;O=D;P=unzip*.zip'|grep -o 'unzip[0-9a-zA-Z_.-]*\.zip'|head -n1) -O "$_tmp/unzip.zip"
#				unzip "$_tmp"/unzip.zip -d "$_tmp" && rm "$_tmp/unzip.zip" && mv "$_tmp"/unzip* "$_tmp"/unzip-src ) & ;;

	*) url="no" ;;
  esac

  [[ "$url" == "no" ]] && : || \
	git clone --single-branch --depth=${_gitdepth} $url "${_tmp}/${1}-src"
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

for inst in $@; do
get_source $inst
case $inst in

musl)
### /* musl
cd "$_tmp/musl-src"
CC=/bin/gcc CFLAGS="-Os" ./configure --prefix="$_pfx" --disable-shared --disable-debug
make && make install || exit 3
echo "musl $(<VERSION)-$(git log -1 --format=%cd.%h --date=short|tr -d -)" >>"$_pfx/version"
export CC="$_pfx/bin/musl-gcc"

cd "$_tmp/musl-kernel-headers-src"
make ARCH=x86_64 prefix="$_pfx" install
echo "kernel-headers $(git describe --tags|cut -d'-' -f'1,2').$(git log -1 --format=%cd.%h --date=short|tr -d -)" >>"$_pfx/version"
;; ### musl */


busybox)
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
;; ### busybox */

pkgconf)
### /* pkgconf
cd "$_tmp/pkgconf-src"
./autogen.sh
./configure --prefix=${_pfx} CFLAGS="${CFLAGS/-D_GNU_SOURCE/}"
make && make check && make install && strip -s ${_pfx}/bin/pkgconf || exit 3
ln -s "$_pfx"/bin/pkgconf "$_pfx/bin/pkg-config"
git_pkg_ver "pkgconf" >>"$_pfx/version"
export PKG_CONFIG="$_pfx/bin/pkg-config"
;; ### pkgconf */

ncurses)
### /* ncurses
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
;; ### zlib */

popt)
### /* popt
cd "$_tmp/popt-src"
./autogen.sh
CFLAGS="$CFLAGS -fPIC" ./configure --prefix=${_pfx} --disable-{nls,doxygen,shared}
make && make install-strip
awk '/PACKAGE_VERSION/ {gsub(/"/,"",$3); print "popt "$3}' config.h >>"$_pfx/version"
;; ### popt */

make)
### /* make
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
### /* htop
cd "$_tmp/htop-src"
./autogen.sh
./configure --prefix=${_pfx} --sysconfdir=/etc
make && strip -s htop && cp htop "$_pfx/bin/"
git_pkg_ver "htop" >>"$_pfx/version"
;; ### htop */

nano)
### /* nano
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

acl)			#+# attr before this
cd "$_tmp/acl-src"
./autogen.sh
CFLAGS="$CFLAGS -fPIC" ./configure --prefix=${_pfx} --disable-{nls,rpath,shared,debug}
make && make install-binPROGRAMS install-pkgconfDATA install-pkgincludeHEADERS install-sysincludeHEADERS
git_pkg_ver "acl" >>"$_pfx/version"
;; ### acl */

# TODO: check include/sys/acl.h, include/attr/xattr.h exist before starting coreutils build
coreutils)		#+# acl, attr before this
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
./autogen.sh
./configure --prefix=${_pfx} --disable-pam --enable-{colors256,rxvt_osc,telnet} \
     --with-pty-group=5 --with-socket-dir=/run/screens --with-sys-screenrc=/etc/screenrc
make && make install
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
make install prefix=${_pfx} CC="$CC -s" PROGRAMS="elfls objres rebind sstrip"
;; ### sstrip */

mesa-utils)
### /* mesa-utils
mkdir -p "$_tmp/mesa-utils-src" && cd "$_tmp/mesa-utils-src"
wget -nv http://cgit.freedesktop.org/mesa/demos/plain/src/xdemos/glinfo_common.c
wget -nv http://cgit.freedesktop.org/mesa/demos/plain/src/xdemos/glinfo_common.h
wget -nv http://cgit.freedesktop.org/mesa/demos/plain/src/xdemos/glxgears.c
wget -nv http://cgit.freedesktop.org/mesa/demos/plain/src/xdemos/glxinfo.c
gcc $CFLAGS glxinfo.c glinfo_common.c glinfo_common.h $LDFLAGS -lX11 -lGL -o "$_bin"/glxinfo-git -s
gcc $CFLAGS glxgears.c $LDFLAGS -lX11 -lGL -lm -o "$_bin"/glxgears-git -s
;; ### mesa-utils */

libnl-tiny)
cd "$_tmp/libnl-tiny-src"
make prefix=${_pfx} CC="$CC" CFLAGS="${CFLAGS/-D_GNU_SOURCE/}" ALL_LIBS=libnl-tiny.a install
;;

iproute2)

;;

iw)
cd "$_tmp/iw-src"
make prefix=${_pfx} CC="$CC" CFLAGS="$CFLAGS -DCONFIG_LIBNL20 -DLIBNL1_COMPAT -I${_pfx}/include/libnl-tiny" PKG_CONFIG=${_pfx}/bin/pkg-config NLLIBNAME=libnl-tiny
strip -s iw && cp iw "${_pfx}/bin/"
install -Dm644 iw.8 "${_pfx}/share/man/man8/iw.8"
;;

nasm)
;; ### nasm */

yasm)
;; ### yasm */

less)
;; ### less */

hexedit)
;; ### hexedit */

atop)
;; ### atop */

netcat)
;; ### netcat */

ncdu)
;; ### ncdu */


mdocml)
;; ### mdocml */

bc)
;; ### bc */

tcc)
;; ### tcc */

minised)
;; ### minised */

wol)
;; ### wol */

pixelserv)
;; ### pixelserv */

dumpelf)	# pax-utils #
;; ### dumpelf */

cpuid)
;; ### cpuid */

diffutils)
;; ### diffutils */



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
