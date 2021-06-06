#!/usr/bin/env bash

VERBOSE=0
SN_SERVICE=storagenode
SUPERVISORCTL=/usr/local/bin/supervisorctl
SN_BINDIR=$HOME/bin
SN_BIN="${SN_BINDIR}/storagenode"
SN_LATEST="${SN_BINDIR}/storagenode-latest"
USE_SUDO=sudo
SCNAME="`basename \"$0\"`"

# FUNCS

err() {
        EXNO=$1
        shift
        echo "${SCNAME}: $*" >&2
        exit $EXNO
}

msg() {
        test $VERBOSE -gt 0 && echo "$*"
}

# check args
if [ "x$1" = "x-v" ]; then
	VERBOSE=1
fi

if [ ! -x $SN_LATEST -o ! -x $SN_BIN ]; then
        err 1 "Can't find existing or latest storagenode binary, exiting..."
fi

if cmp -s $SN_BIN $SN_LATEST; then
        msg "$SN_BIN and $SN_LATEST are same - nothing to do, exiting..."
        exit 0
fi

msg "$SN_BIN is different to $SN_LATEST"

$USE_SUDO $SUPERVISORCTL status $SN_SERVICE >/dev/null 2>&1
if [ $? -ne 0 -a $? -ne 3 ]; then
        err 1 "Issue getting status of storagenode service exiting..."
fi

NODE_PID="`$USE_SUDO $SUPERVISORCTL pid $SN_SERVICE`"
if [ $? -ne 0 ]; then
        SN_WAS_RUNNING=0
else
        SN_WAS_RUNNING=1
	msg "Stopping Service..."
        $USE_SUDO $SUPERVISORCTL stop $SN_SERVICE
fi

msg "Copying $SN_LATEST to $SN_BIN..."
cp -p $SN_LATEST $SN_BIN

if [ $SN_WAS_RUNNING -ne 0 ]; then
	msg "Restarting Service."
        $USE_SUDO $SUPERVISORCTL start $SN_SERVICE
fi
exit 0
