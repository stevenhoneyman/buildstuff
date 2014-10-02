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
## local already cloned git sources
export _gitdir=$HOME/git
## configs, patches, etc
export _breqs=/opt/reqs
## temp dir for compiling
export _tmp=$(mktemp -d)

unset CC CXX CFLAGS CPPFLAGS CXXFLAGS LDFLAGS
export CXX=/bin/false
export CFLAGS='-s -Os -march=x86-64 -mtune=generic -pipe -D_GNU_SOURCE'

#######################

if [ -e "$_pfx" ]; then
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
