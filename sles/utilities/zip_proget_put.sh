#!/usr/bin/env bash
set -vx
set -vx -euo pipefail


[ -f ./proget_sources.sh ] && source ./proget_sources.sh


upack_create() {
    local NAME1="$1"
    local NAME2="$2"
    local SEMVER="$3"
    local IFILES=("${@:4}") # Capture all arguments from the 4th position to the end into an array.
    local abs_files=()
    local f

    # Symlink targets resolve relative to UPKGSRC after pushd; use abs paths.
    for f in "${IFILES[@]}"; do
        abs_files+=("$(readlink -f -- "$f")")
    done

    pushd $UPKGSRC
	ln -f -s "${abs_files[@]}" .
	if [[ "${GEN_SHA256SUM:-0}" == 1 ]]; then
	    echo "info $0:$LINENO: --sha256sum: generating SHA256SUM for files in $UPKGSRC"
	    # Follow symlinks (-L); exclude the checksum file itself.
	    find -L . -type f ! -name SHA256SUM -printf '%P\0' | sort -z | xargs -0 -r sha256sum > SHA256SUM
	    cat SHA256SUM
	    sha256sum -c SHA256SUM
	fi
	pgutil upack create --overwrite --name=$NAME1/$NAME2 --version=${SEMVER} --source-directory=$UPKGSRC --target-directory=$UPKGDST
    popd

    ls -lR $UPKGSRC
    ls -lR $UPKGDST
    ls -lR $UPKGDST/$NAME2-$SEMVER.upack
    if [[ $- == *i* ]]; then
        # interactive shell
        unzip -t $UPKGDST/$NAME2-$SEMVER.upack
    else
        # non-interactive shell
        unzip -t $UPKGDST/$NAME2-$SEMVER.upack | tail -20
    fi
} # upack_create


proget_put() {
    upack_create $NAME1 $NAME2 $SEMVER "${IFILES[@]}"
    if [ -z "$PROGET_BASE_URL" ]; then
        echo $0:$LINENO:
        pgutil packages list --feed=$FEED --source=$PGUTILSRC
        pgutil packages upload --feed=$FEED --input-file=$UPKGDST/$NAME2-$SEMVER.upack --source=$PGUTILSRC --timeout=7200
        set +euo pipefail
            pgutil upack remove --package=$NAME1/$NAME2
        set -euo pipefail
        pgutil upack install --package=$NAME1/$NAME2 --version=$SEMVER --feed=$FEED --target=$TARGETDIR/ --source=$PGUTILSRC
    else
        echo $0:$LINENO:
        pgutil packages list --feed=$FEED --source=$PROGET_BASE_URL --api-key=$PROGET_API_KEY
        pgutil packages upload --feed=$FEED --input-file=$UPKGDST/$NAME2-$SEMVER.upack --source=$PROGET_BASE_URL --api-key=$PROGET_API_KEY --timeout=7200
        set +euo pipefail
            pgutil upack remove --package=$NAME1/$NAME2
        set -euo pipefail
        pgutil upack install --package=$NAME1/$NAME2 --version=$SEMVER --feed=$FEED --target=$TARGETDIR/ --source=$PROGET_BASE_URL --api-key=$PROGET_API_KEY
    fi
} # proget_put


proget_get() {
  # upack_create $NAME1 $NAME2 $SEMVER $IFILES
    if [ -z "$PROGET_BASE_URL" ]; then
        echo $0:$LINENO:
        pgutil packages list --feed=$FEED --source=$PGUTILSRC
      # pgutil packages upload --feed=$FEED --input-file=$UPKGDST/$NAME2-$SEMVER.upack  --source=$PGUTILSRC
        set +euo pipefail
            pgutil upack remove --package=$NAME1/$NAME2
        set -euo pipefail
        pgutil upack install --package=$NAME1/$NAME2 --version=$SEMVER --feed=$FEED --target=$TARGETDIR/ --source=$PGUTILSRC
    else
        echo $0:$LINENO:
        pgutil packages list --feed=$FEED --source=$PROGET_BASE_URL --api-key=$PROGET_API_KEY
      # pgutil packages upload --feed=$FEED --input-file=$UPKGDST/$NAME2-$SEMVER.upack --source=$PROGET_BASE_URL --api-key=$PROGET_API_KEY
        set +euo pipefail
            pgutil upack remove --package=$NAME1/$NAME2
        set -euo pipefail
        pgutil upack install --package=$NAME1/$NAME2 --version=$SEMVER --feed=$FEED --target=$TARGETDIR/ --source=$PROGET_BASE_URL --api-key=$PROGET_API_KEY
    fi
    upack_unpack
} # proget_get


upack_unpack() {
    ls -alR $TARGETDIR
    pushd $TARGETDIR
        shopt -s nullglob
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
        shopt -u nullglob
        # SHA256SUM may sit at package root or one level down (upack install layout).
        _found=0
        while IFS= read -r -d '' sumfile; do
            echo "info $0:$LINENO: sha256sum -c $sumfile"
            ( cd "$(dirname "$sumfile")" && sha256sum -c SHA256SUM )
            _found=1
        done < <(find . -name SHA256SUM -print0 2>/dev/null)
        [[ "${_found}" -eq 1 ]] || { echo "error $0:$LINENO: no SHA256SUM found under $TARGETDIR" >&2; exit $LINENO; }
        unset _found
    popd
} # upack_unpack


# Usage: zip_proget_{put,get}.sh [--sha256sum] FEED NAME1 NAME2 SEMVER file1 [file2 ...]
# --sha256sum (put only): write SHA256SUM for all packaged files before upack create.
GEN_SHA256SUM=0
_ARGS=()
for _a in "$@"; do
    case "${_a}" in
        --sha256sum) GEN_SHA256SUM=1 ;;
        --*)
            echo "error $0:$LINENO: unknown option '${_a}'" >&2
            exit $LINENO
            ;;
        *) _ARGS+=("${_a}") ;;
    esac
done
set -- "${_ARGS[@]}"
unset _ARGS _a


set +euo pipefail
FEED="$1" # test-configuration-assets # <--- EDIT ---<<<<
NAME1="$2" # "Microchip_FW" # <--- EDIT ---<<<<
NAME2="$3" # "Dell_AIC" # <--- EDIT ---<<<<
SEMVER="$4" # <--- EDIT ---<<<<
IFILES=("${@:5}") # Capture all arguments from the 5th position to the end into an array.
ls -alR ${IFILES[@]}

first="${IFILES[0]}"
if [[ "$first" == *.tar.gz ]]; then
    EXTRACT_KIND=tar
else
    EXTRACT_KIND=zip
fi
TARGETDIR=instdir
set -euo pipefail


if [ -d $TARGETDIR ]; then
    set +euo pipefail
        rm -rf $TARGETDIR
        [ $? -ne 0 ] && sudo rm -rf $TARGETDIR
    set -euo pipefail
fi
[ ! -d $TARGETDIR ] && mkdir -p $TARGETDIR


[ ! command -v pgutil >/dev/null 2>&1 ] && echo "error $0:$LINENO: pgutil executable not found" && exit $LINENO


export UPKGSRC=$PWD/upacksrc
[ ! -z "$UPKGSRC" ] && [ -d $UPKGSRC ] && rm -r $UPKGSRC
[ ! -d $UPKGSRC ] && mkdir $UPKGSRC
export UPKGDST=$PWD/upackdst
[ ! -z "$UPKGDST" ] && [ -d $UPKGDST ] && rm -r $UPKGDST
[ ! -d $UPKGDST ] && mkdir $UPKGDST

if [[ "$(basename $0)" == *"_get.sh" ]]; then
    PUTGET=get
    proget_get
elif [[ "$(basename $0)" == *"_put.sh" ]]; then
    PUTGET=put
    proget_put
fi

[ ! -z "$UPKGSRC" ] && [ -d $UPKGSRC ] && rm -r $UPKGSRC
[ ! -z "$UPKGDST" ] && [ -d $UPKGDST ] && rm -r $UPKGDST

echo "info $0:$LINENO: \$?=$?"
