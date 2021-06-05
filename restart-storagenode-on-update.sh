#!/usr/bin/env bash

STORAGENODE_SERVICE=storagenode
SUPERVISORCTL=/usr/local/bin/supervisorctl
STORAGENODE_BINDIR=/home/storj/bin
STORAGENODE_BIN="${STORAGENODE_BINDIR}/storagenode"
STORAGENODE_LATEST="${STORAGENODE_BINDIR}/storagenode-latest"
USE_SUDO=sudo

if [ ! -x $STORAGENODE_LATEST -o ! -x $STORAGENODE_BIN ]; then
        echo "$0: Can't find existing or latest storagenode binary, exiting..."
        exit 1
fi

LV="`$STORAGENODE_LATEST version`"
EV="`$STORAGENODE_BIN version`"

if [ "$LV" = "$EV" ]; then
        echo "$0: Versions are same - nothing to do, exiting..."
        exit 0
fi

$USE_SUDO $SUPERVISORCTL status $STORAGENODE_SERVICE >/dev/null 2>&1
if [ $? -ne 0 -a $? -ne 3 ]; then
        echo "$0: Issue getting status of storagenode service exiting..."
        exit 1
fi

NODE_PID="`$USE_SUDO $SUPERVISORCTL pid $STORAGENODE_SERVICE`"
if [ $? -ne 0 ]; then
        STORAGENODE_WAS_RUNNING=0
else
        STORAGENODE_WAS_RUNNING=1
        $USE_SUDO $SUPERVISORCTL stop $STORAGENODE_SERVICE
fi
cp -p $STORAGENODE_LATEST $STORAGENODE_BIN
if [ $STORAGENODE_WAS_RUNNING -eq 1 ]; then
        $USE_SUDO $SUPERVISORCTL start $STORAGENODE_SERVICE
fi
exit 0
