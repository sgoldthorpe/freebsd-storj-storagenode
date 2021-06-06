#!/usr/bin/env bash

# GLOBALS
VERBOSE=0
SN_BIN=storagenode
SN_BIN_LATEST="${SN_BIN}-latest"
VERSION_URL=https://version.storj.io
LATEST_BASEURL="https://github.com/storj/storj/releases/latest/download"
SCNAME="`basename \"$0\"`"

# FUNCS

err() {
	EXNO=$1
	shift
	echo "${SCNAME}: $*" >&2
	rm -f "$TMPDIR"/*; rmdir "$TMPDIR"
	exit $EXNO
}

msg() {
	test $VERBOSE -gt 0 && echo "$*"
}

fetch_zip() {
	URL="$1"
	DEST="$2"
	ZIP="$TMPDIR/sn.zip"
	msg "downloading ${URL}..."
	curl -L -s -o "$ZIP" "$URL" >/dev/null 2>&1
	if [ $? -ne 0 ]; then
		err 1 "Problem downloading, exiting..."
	fi
	unzip -o "$ZIP" -d "$TMPDIR" >/dev/null 2>&1
	if [ $? -ne 0 -o ! -f "$TMPDIR/$SN_BIN" ]; then
		err 1 "Problem extracting, exiting..."
	fi

	cp -p "$TMPDIR/$SN_BIN" "$DEST"
	chmod 755 "$DEST" # ensure perms are OK
}

get_ver() {
	echo "`\"$1\" version 2>/dev/null| awk '/^Version/ { sub(/^v/,"",$2);print $2 }'`"
}

get_sugg_ver() {
	jq -r .processes.storagenode.suggested.version "$1" 2>/dev/null
}

get_sugg_url() {
	jq -r .processes.storagenode.suggested.url "$1" | sed -e "s/{os}/$OS/" -e "s/{arch}/$ARCH/" -e 's/\.exe//'
}

fetch_storj_vers() {
	msg "Fetching version information..."
	curl -L -s -o "$1" "$VERSION_URL" >/dev/null 2>&1
}

fetch_and_version() {
	fetch_zip "$1" "$TMPDIR/$SN_BIN_LATEST"
	VER="`get_ver \"$TMPDIR/$SN_BIN_LATEST\"`"
	if [ -z "$VER" ]; then
		err 1 "Couldn't get version from downloaded binary"
	fi
	mv "$TMPDIR/$SN_BIN_LATEST" "$HOME/bin/${SN_BIN}-${VER}"
	# create link then use mv to change link atomically
	ln -s "${SN_BIN}-${VER}" "$HOME/bin/${SN_BIN_LATEST}.new"
	mv "$HOME/bin/${SN_BIN_LATEST}.new" "$HOME/bin/${SN_BIN_LATEST}"
}

# create temporary working directory
TMPDIR="`mktemp -d \"/tmp/${SCNAME}.XXXXXX\"`"
if [ $? -ne 0 ]; then
	err 1 "Can't create temp directory, exiting..."
fi

# check args
if [ "x$1" = "x-v" ]; then
	VERBOSE=1
fi

# Storj only support amd64 on FreeBSD so hard-code for now (ditto linux)
ARCH=amd64
# Assume anything not FreeBSD is Linux (for testing)
case `uname -o` in
	FreeBSD)
		OS=freebsd;;
	*)
		OS=linux;;
esac

# create users bin directory if it doesn't exist
test -d "$HOME/bin" || mkdir "$HOME/bin"

# if the storagenode latest binary doesn't exist, fetch it from github
if [ ! -f "$HOME/bin/$SN_BIN_LATEST" ]; then
	msg "$SN_BIN_LATEST missing, fetching from github..."
	fetch_and_version "$LATEST_BASEURL/${SN_BIN}_${OS}_${ARCH}.zip"
fi

# if the storagenode binary doesn't exist, just copy it from latest
if [ ! -f "$HOME/bin/$SN_BIN" ]; then
	msg "$SN_BIN missing, copying from $SN_BIN_LATEST..."
	cp -p "$HOME/bin/$SN_BIN_LATEST" "$HOME/bin/$SN_BIN"
fi

V_FILE="$TMPDIR/versions.json"
fetch_storj_vers "$V_FILE"

if [ $? -ne 0 ]; then
	err 1 "Can't fetch remote versions, exiting..."
fi

S_VER="`get_sugg_ver \"$V_FILE\"`"
C_VER="`get_ver \"$HOME/bin/$SN_BIN_LATEST\"`"

if [ "x$C_VER" = "x" -o "x$S_VER" = "x" ]; then
	err 1 "Problem detecting versions, exiting..."
fi

msg "Current version: $C_VER"
msg "Suggested version: $S_VER"

if [ "$S_VER" != "$C_VER" ]; then
	msg "Update detected - upgrade from version $C_VER to $S_VER"
	URL="`get_sugg_url \"$V_FILE\"`"
	fetch_and_version "$URL"

	msg "Created $HOME/bin/$SN_BIN_LATEST"
	msg "service will need to be stopped, $SN_BIN_LATEST copied to $SN_BIN and service restarted."
else
	msg "Nothing to do."
fi

rm -f "$TMPDIR"/*; rmdir "$TMPDIR"
exit 0
