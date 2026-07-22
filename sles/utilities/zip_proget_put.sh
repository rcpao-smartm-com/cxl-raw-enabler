#!/usr/bin/env bash
set -vx # -euo pipefail


# zip_proget_get.sh -> zip_proget_put.sh
# Usage: zip_proget_{get,put}.sh NAME1 NAME2 SEMVER file1 [file2 ...]


# source ./proget_sources.sh


set +euo pipefail
    NAME1="marvell.com"
    NAME2="Structera_SLX24041_SDK"
    SEMVER="26.4.0"
    IFILES=()

    [ ! -z "$1" ] && NAME1="$1"
    [ ! -z "$2" ] && NAME2="$2"
    [ ! -z "$3" ] && SEMVER="$3"
    if [ $# -ge 4 ]; then
        shift 3
        IFILES=("$@")
    fi

    [ -z "$NAME1" ] && echo "error $0:$LINENO: NAME1 required as \$1" && exit $LINENO
    [ -z "$NAME2" ] && echo "error $0:$LINENO: NAME2 required as \$2" && exit $LINENO
    [ -z "$SEMVER" ] && echo "error $0:$LINENO: SEMVER required as \$3" && exit $LINENO
    [ ${#IFILES[@]} -eq 0 ] && echo "error $0:$LINENO: at least one input file required" && exit $LINENO

    first="${IFILES[0]}"
    if [[ "$first" == *.tar.gz ]]; then
        TARGETDIR=instdir
        EXTRACT_KIND=tar
    else
        IFILES_BASE=$(basename "$first" .zip)
        TARGETDIR=instdir/${SEMVER}-${IFILES_BASE}
        EXTRACT_KIND=zip
    fi
set -euo pipefail


upack_create() {
    local NAME1="$1"
    local NAME2="$2"
    local SEMVER="$3"
    local IFILES=("${@:4}")
    local abs_files=()
    local f

    # Symlink targets resolve relative to UPKGSRC after pushd; use abs paths.
    for f in "${IFILES[@]}"; do
        abs_files+=("$(readlink -f -- "$f")")
    done

    pushd $UPKGSRC
	ln -f -s "${abs_files[@]}" .
	pgutil upack create --overwrite --name=$NAME1/$NAME2 --version=${SEMVER} --source-directory=$UPKGSRC --target-directory=$UPKGDST
    popd

    ls -lR $UPKGSRC
    ls -lR $UPKGDST
    ls -lR $UPKGDST/$NAME2-$SEMVER.upack
    if [[ $- == *i* ]]; then
        unzip -t $UPKGDST/$NAME2-$SEMVER.upack
    else
        unzip -t $UPKGDST/$NAME2-$SEMVER.upack | tail -20
    fi
} # upack_create


if [[ "$(basename $0)" == *"_put.sh" ]]; then
    for f in "${IFILES[@]}"; do
        [ ! -f "$f" ] && echo "error $0:$LINENO: missing $f" && exit $LINENO
    done
    set +euo pipefail
        ls -alR "${IFILES[@]}"
    set -euo pipefail
fi


case "$EXTRACT_KIND" in
    tar)
        [ ! -d $TARGETDIR ] && mkdir $TARGETDIR
        ;;
    zip)
        if [ -d $TARGETDIR ]; then
            set +euo pipefail
                rm -rf $TARGETDIR
                [ $? -ne 0 ] && sudo rm -rf $TARGETDIR
            set -euo pipefail
        fi
        [ ! -d $TARGETDIR ] && mkdir -p $TARGETDIR
        ;;
esac


[ ! command -v pgutil >/dev/null 2>&1 ] && echo "error $0:$LINENO: pgutil executable not found" && exit $LINENO


# PGUTILSRC=svrr1
  PGUTILSRC=smartapd
# PGUTILSRC=Default

proget_get() {
    if [ -z "$PROGET_BASE_URL" ]; then
        echo $0:$LINENO:
        pgutil packages list --feed=test-configuration-assets --source=$PGUTILSRC
        set +euo pipefail
            pgutil upack remove --package=$NAME1/$NAME2
        set -euo pipefail
        pgutil upack install --package=$NAME1/$NAME2 --version=$SEMVER --feed=test-configuration-assets --target=$TARGETDIR/ --source=$PGUTILSRC
    else
        echo $0:$LINENO:
        pgutil packages list --feed=test-configuration-assets --source=$PROGET_BASE_URL --api-key=$PROGET_API_KEY
        set +euo pipefail
            pgutil upack remove --package=$NAME1/$NAME2
        set -euo pipefail
        pgutil upack install --package=$NAME1/$NAME2 --version=$SEMVER --feed=test-configuration-assets --target=$TARGETDIR/ --source=$PROGET_BASE_URL --api-key=$PROGET_API_KEY
    fi
} # proget_get

proget_put() {
    upack_create $NAME1 $NAME2 $SEMVER "${IFILES[@]}"
    if [ -z "$PROGET_BASE_URL" ]; then
        echo $0:$LINENO:
        pgutil packages list --feed=test-configuration-assets --source=$PGUTILSRC
        pgutil packages upload --feed=test-configuration-assets --input-file=$UPKGDST/$NAME2-$SEMVER.upack --source=$PGUTILSRC
        set +euo pipefail
            pgutil upack remove --package=$NAME1/$NAME2
        set -euo pipefail
        pgutil upack install --package=$NAME1/$NAME2 --version=$SEMVER --feed=test-configuration-assets --target=$TARGETDIR/ --source=$PGUTILSRC
    else
        echo $0:$LINENO:
        pgutil packages list --feed=test-configuration-assets --source=$PROGET_BASE_URL --api-key=$PROGET_API_KEY
        pgutil packages upload --feed=test-configuration-assets --input-file=$UPKGDST/$NAME2-$SEMVER.upack --source=$PROGET_BASE_URL --api-key=$PROGET_API_KEY
        set +euo pipefail
            pgutil upack remove --package=$NAME1/$NAME2
        set -euo pipefail
        pgutil upack install --package=$NAME1/$NAME2 --version=$SEMVER --feed=test-configuration-assets --target=$TARGETDIR/ --source=$PROGET_BASE_URL --api-key=$PROGET_API_KEY
    fi
} # proget_put


export UPKGSRC=$PWD/upacksrc
[ ! -z "$UPKGSRC" ] && [ -d $UPKGSRC ] && rm -r $UPKGSRC
[ ! -d $UPKGSRC ] && mkdir $UPKGSRC
export UPKGDST=$PWD/upackdst
[ ! -z "$UPKGDST" ] && [ -d $UPKGDST ] && rm -r $UPKGDST
[ ! -d $UPKGDST ] && mkdir $UPKGDST

if [[ "$(basename $0)" == *"_get.sh" ]]; then
    proget_get
elif [[ "$(basename $0)" == *"_put.sh" ]]; then
    proget_put
fi

[ ! -z "$UPKGSRC" ] && [ -d $UPKGSRC ] && rm -r $UPKGSRC
[ ! -z "$UPKGDST" ] && [ -d $UPKGDST ] && rm -r $UPKGDST


ls -alR $TARGETDIR
pushd $TARGETDIR

    [ -f SHA256SUM ] && sha256sum -c SHA256SUM

    case "$EXTRACT_KIND" in
        tar)
            for file in *.tar.gz; do
                if [[ $- == *i* ]]; then
                    tar -tvf "$file"
                    tar -xvf "$file"
                else
                    tar -tvf "$file" | tail -20
                    tar -xvf "$file" | tail -20
                fi
            done
            ;;
        zip)
            for file in *.zip; do
                unzip -t "$file"
                unzip "$file"
            done
            ;;
    esac
popd

echo "info $0:$LINENO: \$?=$?"
