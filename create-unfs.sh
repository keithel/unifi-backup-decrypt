#!/bin/bash

# Tool for taking a directory full of directories of decrypted and unpacked
# autobackup Unifi Controller backup files (.unf), and re-creating the .unf
# files that they once were.

# This is part of a slightly larger project to compress large numbers of
# autobackups in an efficient manner.

# Authors:
# 2024 Keith Kyzivat

set -e

DIR_PREFIX="autobackup_"

usage() {
    echo "Usage: $0 <directory containing directories with name of form ${DIR_PREFIX}*>"
}

recompress_dbs() {
    dir=$1

    # gzip up db and db_stat, as that is how it is within a standard .unf file.
    # It gets uncompressed so that a file holding many unifi backups can be
    # compressed efficiently.
    if [[ -e $dir/db_stat ]]; then
        gzip $dir/db_stat
    fi
    if [[ -e $dir/db ]]; then
        gzip $dir/db
    fi
}

ZIPFILE=""
zip_backup() {
    dir=$1

    ZIPFILE="$dir.zip"
    zipsuffix=1
    while [[ -e "$ZIPFILE" ]]; do
        candidate="${dir}-${zipsuffix}.zip"
        if [[ ! -e "$candidate" ]]; then
            ZIPFILE=$candidate
        fi
        ((zip_suffix++))
    done

    (cd $dir && zip -r ../$ZIPFILE .)
}

if [[ -n "$1" && ! -d "$1" ]]; then
    echo >&2 "$1 does not exist or is not a directory."
    usage
    exit 1
fi

if [[ -n "$1" ]]; then
    cd "$1"
fi

set +e
echo "ls -d ${DIR_PREFIX}* >/dev/null 2>&1"
ls -d ${DIR_PREFIX}* >/dev/null 2>&1
if [[ $? -gt 0 ]]; then
    echo >&2 "No unifi backup directories. Doing nothing."
    exit 1
fi
set -e

for dir in ./${DIR_PREFIX}*; do
    if [[ ! -e "${dir}/backup.json" ]]; then
        echo >&2 "Skipping $dir, as it does not look like a unifi backup."
        continue
    fi

    recompress_dbs $dir
    zip_backup $dir # Outputs $ZIPFILE
    openssl enc -e -in "./${ZIPFILE}" -out "${dir}.unf" -aes-128-cbc -K 626379616e676b6d6c756f686d617273 -iv 75626e74656e74657270726973656170
done
