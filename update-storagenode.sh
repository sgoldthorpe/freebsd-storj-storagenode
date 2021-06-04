#!/usr/bin/env bash

# GLOBALS
VERBOSE=0
SN_BIN=storagenode
SN_BIN_LATEST=${SN_BIN}-latest
SCNAME="`basename $0`"
TMPDIR="`mktemp -d \"/tmp/${SCNAME}.XXXXXX\"`"

if [ $? -ne 0 ]; then
	echo "$0: Can't create temp directory, exiting..." >&2
	exit 1
fi

# FUNCS

fetch_zip() {
	URL=$1
	DEST=$2
	ZFILE=$TMPDIR/sn.zip
	test $VERBOSE -gt 0 && echo "downloading ${URL}..."
	curl -L -s -o $ZFILE $URL >/dev/null 2>&1
	if [ $? -ne 0 ]; then
		rm -f $TMPDIR/*; rmdir $TMPDIR
		echo "$0: Problem downloading, exiting..." >&2
		exit 1
	fi
	unzip -o $ZFILE -d $TMPDIR >/dev/null 2>&1
	if [ $? -ne 0 -o ! -f $TMPDIR/$SN_BIN ]; then
		rm -f $TMPDIR/*; rmdir $TMPDIR
		echo "$0: Problem extracting, exiting..." >&2
		exit 1
	fi

	cp -p $TMPDIR/$SN_BIN $DEST
	chmod 755 $DEST # ensure perms are OK
}

get_ver() {
	echo "`$1 version 2>/dev/null| awk '/^Version/ { sub(/^v/,"",$2);print $2 }'`"
}

get_sugg_ver() {
	jq -r .processes.storagenode.suggested.version $1 2>/dev/null
}

get_sugg_url() {
	jq -r .processes.storagenode.suggested.url $1 | sed -e "s/{os}/$OS/" -e "s/{arch}/$ARCH/" -e 's/\.exe//'
}

fetch_storj_vers() {
	test $VERBOSE -gt 0 && echo "Fetching version information..."
	curl -L -s -o $1 https://version.storj.io >/dev/null 2>&1
}

# CHECK ARGS

if [ "x$1" = "x-v" ]; then
	VERBOSE=1
fi

# Storj only support amd64 on freebsd so hardcode
ARCH=amd64
# Assume anything not FreeBSD is Linux (for testing)
case `uname -o` in
	FreeBSD)
		OS=freebsd;;
	*)
		OS=linux;;
esac

LATEST_ZIP=https://github.com/storj/storj/releases/latest/download/${SN_BIN}_${OS}_${ARCH}.zip

test -d $HOME/bin || mkdir $HOME/bin

# if the storagenode binary doesn't exist, fetch it from github
if [ ! -f $HOME/bin/$SN_BIN ]; then
	fetch_zip ${LATEST_ZIP} $HOME/bin/$SN_BIN
fi

# if the storagenode-latest file doesn't exist, just copy the storagenode binary
if [ ! -f $HOME/bin/$SN_BIN_LATEST ]; then
	cp -p $HOME/bin/$SN_BIN $HOME/bin/$SN_BIN_LATEST
fi

V_FILE=$TMPDIR/versions.json
fetch_storj_vers $V_FILE

if [ $? -ne 0 ]; then
	rm -f $TMPDIR/*; rmdir $TMPDIR
	echo "$0: Can't fetch remote versions, exiting..." >&1
	exit 1
fi

S_VER="`get_sugg_ver $V_FILE`"
L_VER="`get_ver $HOME/bin/$SN_BIN`"

if [ "x$L_VER" = "x" -o "x$L_VER" = "x" ]; then
	rm -f $TMPDIR/*; rmdir $TMPDIR
	echo "$0: Problem detecting versions, exiting..." >&1
	exit 1
fi

if [ $VERBOSE -gt 0 ]; then
	echo "Local version: $L_VER"
	echo "Suggested version: $S_VER"
fi

if [ "$S_VER" != "$L_VER" ]; then
	LATEST_VER="`get_ver $HOME/bin/$SN_BIN_LATEST`"
	if [ "$S_VER" = "$LATEST_VER" ]; then
		rm -f $TMPDIR/*; rmdir $TMPDIR
		date
		echo "Already downloaded suggested version as $SN_BIN_LATEST but it is not installed as $SN_BIN"
		echo "root will need to stop storage node and rename command and restart storage node."
		exit 0
	fi
	URL="`get_sugg_url $V_FILE`"
	echo "Update detected - upgrade from version $L_VER to $S_VER"
	cp -p $HOME/bin/$SN_BIN $HOME/bin/${SN_BIN}-${L_VER}
	fetch_zip $URL $HOME/bin/$SN_BIN_LATEST

	echo "Created $HOME/bin/$SN_BIN_LATEST"
	echo "root will need to stop storage node and rename command and restart storage node."
	echo "---"
elif [ $VERBOSE -ne 0 ]; then
	echo "Versions are equal - nothing to do."
fi

rm -f $TMPDIR/*; rmdir $TMPDIR
exit 0
