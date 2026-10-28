#!/usr/bin/env bash

# This utility generates drivers for retrospective runs. While you could run each
# utility to generate data for 20+ years, it would take a very long time. This utility
# breaks years up and sends them to different servers to generate the data in a
# feasible amount of time.

# Be strict about errors
set -euo pipefail

BLURB="MiCASA batch post-processing" 

# Process settings
# ---
# Fancy way to source setup and support symlinks, spaces, etc.
POSTDIR=$(dirname "$(readlink -f "$0")")
. "$POSTDIR/../../setup.sh"

# Redefine the default argument parsing
# ---
# Defaults
YEAR0=2001
YEARF=$(date -d "-$LATENCY days" +%Y)					# $LATENCY defined in setup.sh

CMDLIST=("check.sh" "cogmake.sh" "cogupload.sh" "drivers.sh" "process.sh")
CMDHELP=$(printf '%s, ' "${CMDLIST[@]}" | sed 's/, $//')

usage() {
    echo "usage: $1 [-h] [-p PROD] [-v VER] [-r RES] [--beg YYYY] [--end YYYY]" \
        "[-i DIR] [-o DIR] [-f] command"
}

helpout() {
    echo "$1"
    echo ""
    echo "positional arguments:"
    echo "  command               operation mode: $CMDHELP"
    echo ""
    echo "options:"
    echo "  -h, --help            show this help message and exit"
    echo "  -p PROD, --prod PROD  product name (default: $PRODDEF)"
    echo "  -v VER, --ver VER     version (default: $VERDEF)"
    echo "  -r RES, --res RES     resolution (default: $RESDEF)"
    echo "  --beg YYYY            begin year (default: $YEAR0)"
    echo "  --end YYYY            end year (default: $YEARF)"
    echo "  -i DIR, --input DIR   input root directory (default: $DATADEF)"
    echo "  -o DIR, --output DIR  output root directory (default: $DATADEF)"
    echo "  -f, --force           overwrite files (default: False)"
}

argparse() {
    # Defaults
    PROD=$PRODDEF
    VER=$VERDEF
    RES=$RESDEF
    DATAIN=$DATADEF
    DATAOUT=$DATADEF
    FORCE=false

    # First two args are for help
    MYNAME="$1"
    BLURB="$2"
    shift 2

    POSARGS=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--prod)
                PROD="$2"
                shift 2
                ;;
            -v|--ver)
                VER="$2"
                shift 2
                ;;
            -r|--res)
                RES="$2"
                shift 2
                ;;
            --beg)
                YEAR0="$2"
                shift 2
                ;;
            --end)
                YEARF="$2"
                shift 2
                ;;
            -i|--input)
                DATAIN="$2"
                shift 2
                ;;
            -o|--output)
                DATAOUT="$2"
                shift 2
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -h|--help)
                usage "$MYNAME"
                echo ""
                helpout "$BLURB"
                exit
                ;;
            -*)
                usage "$MYNAME" >&2
                echo "$MYNAME: error: unknown option $1" >&2
                exit 1
                ;;
            # Handle positional arguments (arguments without flags)
            *)
                POSARGS+=("$1")
                shift
                ;;
        esac
    done

    # Get and check name and mode
    # ---
    if [[ ${#POSARGS[@]} -ne 1 ]]; then
        usage "$MYNAME" >&2
        echo "$MYNAME: error: the following arguments are required: command" >&2
        exit 1
    fi

    # Note: `command` is a shell built-in
    cmd="${POSARGS[0]}"
    found=false
    for check in "${CMDLIST[@]}"; do
        if [[ "$cmd" == "$check" ]]; then
            found=true
            break
        fi
    done

    if [[ "$found" != true ]]; then
        usage "$MYNAME" >&2
        echo "$MYNAME: error: argument command: invalid choice: \'$cmd\'" >&2
        exit 1
    fi
}

# Process arguments
# ---
argparse "$(basename "$0")" "$BLURB" "$@"

LOGDIR="$(realpath -s "$DATAIN/..")/logs"
ROOTDIR=$(realpath -s "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")

# Outputs and warnings
# ---
echo "---"
echo "$BLURB"
echo "---"
echo "Input location: $DATAIN/v$VER"
echo "Output location: $DATAOUT/v$VER"
echo "Log location: $LOGDIR/v$VER"
echo "Command: $ROOTDIR/$cmd"
echo "Year(s): $YEAR0..$YEARF"
echo "Host(s): ${HOSTS[*]}"

warnings

echo ""

# Run
# ---
CMDARGS=("--prod" '"'"$PROD"'"' "--ver" '"'"$VER"'"' "--res" '"'"$RES"'"' \
    "--input" '"'"$DATAIN"'"' "--output" '"'"$DATAOUT"'"')
[[ "$FORCE" == true ]] && CMDARGS+=("--force")

NUMHOSTS=${#HOSTS[@]}
for year in $(seq "$YEAR0" "$YEARF"); do
    nn=$(( (year - YEAR0) % NUMHOSTS ))

    mkdir -p "$LOGDIR/v$VER/post/$cmd/$year"
    cd "$LOGDIR/v$VER/post/$cmd/$year" || exit

    # Note: `command` is a shell built-in
    mycmd="$ROOTDIR/$cmd $year ${CMDARGS[*]} --batch"
    echo "${HOSTS[$nn]}: Submitting $mycmd"
    screen -L -dmS "MiCASA-post-$cmd-$year" \
        bash --login -c "ssh -t ${HOSTS[$nn]} \"$mycmd; exit\""
done
