#!/usr/bin/env bash
#
VERBOSE=0

STORAGENODE_BIN=storagenode
STORAGENODE_BIN_LATEST=${STORAGENODE_BIN}-latest
tempfoo=`basename $0`
TMPDIR=`mktemp -d /tmp/${tempfoo}.XXXXXX`
if [ $? -ne 0 ]; then
        echo "$0: Can't create temp directory, exiting..."
        exit 1
fi

if [ "x$1" = "x-v" ]; then
        VERBOSE=1
fi

TMPVER=$TMPDIR/versions.json


fetch_zip() {
	URL=$1
	OUTFILE=$2
        ZIPFILE=$TMPDIR/sn.zip
        echo "downloading ${URL}..."
        curl -L -s -o $ZIPFILE $URL
        if [ $? -ne 0 ]; then
                rm -f $TMPDIR/*; rmdir $TMPDIR
                echo "$0: Problem downloading binary, exiting..."
                exit 1
        fi
        unzip -o $ZIPFILE -d $TMPDIR
        if [ $? -ne 0 -o ! -f $TMPDIR/$STORAGENODE_BIN ]; then
                rm -f $TMPDIR/*; rmdir $TMPDIR
                echo "$0: Problem extracting binary, exiting..."
                exit 1
        fi

        cp -p $TMPDIR/$STORAGENODE_BIN $OUTFILE
        chmod 755 $OUTFILE # some times perms are wrong
}

if [ ! -f $HOME/bin/$STORAGENODE_BIN ]; then
	fetch_zip https://github.com/storj/storj/releases/latest/download/storagenode_freebsd_amd64.zip $HOME/bin/$STORAGENODE_BIN
fi

curl -L -s -o $TMPVER https://version.storj.io
if [ $? -ne 0 ]; then
        rm -f $TMPDIR/*; rmdir $TMPDIR
        echo "$0: Can't fetch remote versions, exiting..."
        exit 1
fi

REMOTE_VER="`jq -r .processes.storagenode.suggested.version $TMPVER`"
LOCAL_VER="`$HOME/bin/$STORAGENODE_BIN version 2>/dev/null| awk '/^Version/ { sub(/^v/,"",$2);print $2 }'`"

if [ "x$LOCAL_VER" = "x" -o "x$LOCAL_VER" = "x" ]; then
        rm -f $TMPDIR/*; rmdir $TMPDIR
        echo "$0: Problem detecting versions, exiting..."
        exit 1
fi

if [ $VERBOSE -ne 0 ]; then
        echo "Local version: $LOCAL_VER"
        echo "Remote version: $REMOTE_VER"
fi


if [ "$REMOTE_VER" != "$LOCAL_VER" ]; then
        date
        if [ -f $HOME/bin/$STORAGENODE_BIN_LATEST ]; then
                LOCAL_LATEST_VER="`$HOME/bin/$STORAGENODE_BIN_LATEST version 2>/dev/null| awk '/^Version/ { sub(/^v/,"",$2);print $2 }'`"
                if [ "$REMOTE_VER" = "$LOCAL_LATEST_VER" ]; then
                        rm -f $TMPDIR/*; rmdir $TMPDIR
                        echo "Already downloaded new version as $STORAGENODE_BIN_LATEST but it is not installed as $STORAGENODE_BIN"
                        echo "root will need to stop storage node and rename command and restart storage node."
                        exit 0
                fi
        fi
        ARCH="`uname -p`"
        #OS="`uname -s | tr '[:upper:]' '[:lower:]'`"
        OS="`uname -s`"
        URL="`jq -r .processes.storagenode.suggested.url $TMPVER | sed -e \"s/{os}/$OS/\" -e \"s/{arch}/$ARCH/\" -e \"s/\.exe//\"`"
        echo "Update detected - upgrade from version $LOCAL_VER to $REMOTE_VER"
        cp -p $HOME/bin/$STORAGENODE_BIN $HOME/bin/${STORAGENODE_BIN}-${LOCAL_VER}
	fetch_zip $URL $HOME/bin/$STORAGENODE_BIN_LATEST

        echo "Created $HOME/bin/$STORAGENODE_BIN_LATEST"
        echo "root will need to stop storage node and rename command and restart storage node."
        echo "---"
elif [ $VERBOSE -ne 0 ]; then
        echo "Versions are equal - nothing to do."
fi

rm -f $TMPDIR/*; rmdir $TMPDIR
exit 0
