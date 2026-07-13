#!/usr/bin/env bash

# This utility generates drivers for retrospective runs. While you could run the modvir
# utility to generate data for 20+ years, it would take a very long time. This utility
# breaks years up and sends them to different servers to generate the drivers in a
# feasible amount of time.
#
# Note that while vegind and burn will generate cover, splitting the year into a/b runs
# will cause whichever finishes second to crash trying to write the same cover file.
# So it's a good idea to run cover first for safety.

BLURB="MiCASA prepare drivers"

# Process settings & arguments
# ---
# Fancy way to source setup and support symlinks, spaces, etc.
PREPDIR=$(dirname "$(readlink -f "$0")")
. "$PREPDIR/../setup.sh"

# Redefine default argument parsing
# ---
usage() {
    echo "usage: $1 [-h] [-p PROD] [-v VER] [-r RES] [--beg YYYY-MM-DD]" \
        "[--end YYYY-MM-DD] [-o DIR] [-f] name mode"
}

# Defaults
daybeg="2000-02-24"					# First day of MCD43A4
dayend="$(date -d "$LATENCY" +%F)"			# $LATENCY defined in setup.sh

helpout() {
    echo "$1"
    echo ""
    echo "positional arguments:"
    echo "  name                  name of dataset to build: cover, vegind, burn"
    echo "  mode                  operation mode: get, regrid"
    echo ""
    echo "options:"
    echo "  -h, --help            show this help message and exit"
    echo "  -p PROD, --prod PROD  product name (default: $PRODDEF)"
    echo "  -v VER, --ver VER     version (default: $VERDEF)"
    echo "  -r RES, --res RES     resolution (default: $RESDEF)"
    echo "  --beg YYYY-MM-DD      begin date (default: $daybeg)"
    echo "  --end YYYY-MM-DD      end date (default: $dayend)"
    echo "  -o DIR, --output DIR  output root directory (default: $DATADEF)"
    echo "  -f, --force           overwrite files (default: False)"
    echo "  -b, --batch           operate in batch mode (default: False)"
}

argparse() {
    # Defaults
    PROD=$PRODDEF
    VER=$VERDEF
    RES=$RESDEF
    DATADIR=$DATADEF
    FORCE=false
    BATCH=false

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
                if ! daybeg=$(date -d "$2" +%F); then
                    usage "$MYNAME" >&2
                    exit 1
                fi
                shift 2
                ;;
            --end)
                if ! dayend=$(date -d "$2" +%F); then
                    usage "$MYNAME" >&2
                    exit 1
                fi
                shift 2
                ;;
            -o|--output)
                DATADIR="$2"
                shift 2
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -b|--batch)
                BATCH=true
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
    if [[ ${#POSARGS[@]} -ne 2 ]]; then
        usage "$MYNAME" >&2
        echo "$MYNAME: error: the following arguments are required: name, mode" >&2
        exit 1
    fi

    name="${POSARGS[0]}"
    if [[ "$name" != "cover" && "$name" != "vegind" && "$name" != "burn" ]]; then
        usage "$MYNAME" >&2
        echo "$MYNAME: error: argument name: invalid choice: \'$name\'" >&2
        exit 1
    fi

    mode="${POSARGS[1]}"
    if [[ "$mode" != "get" && "$mode" != "regrid" ]]; then
        usage "$MYNAME" >&2
        echo "$MYNAME: error: argument mode: invalid choice: \'$mode\'" >&2
        exit 1
    fi
}

# Process arguments
# ---
argparse "$(basename "$0")" "$BLURB" "$@"

LOGDIR="$(realpath -s "$DATADIR/..")/logs"

# Outputs and warnings
# ---
echo "---"
echo "$BLURB"
echo "---"
echo "Output location: $DATADIR/v$VER"
echo "Log location: $LOGDIR/v$VER"
echo "Collection: $name"
echo "Mode: $mode"
echo "Date(s): $daybeg..$dayend"

warnings

# Run
# ---
cmd0="modvir $name --mode $mode --ver \"$VER\""
cmd0="$cmd0 --output \"$DATADIR/v$VER/drivers\""

NUMHOSTS=${#HOSTS[@]}

# Weird synatx to support spaces in variable names
# Doesn't support --res at this time
MVARGS=("$name" "--mode" "$mode" "--prod" '"'"$PROD"'"' "--ver" '"'"$VER"'"' \
    "--output" '"'"$DATADIR/v$VER/drivers"'"')
[[ "$FORCE" == true ]] && MVARGS+=("--force")

YEAR0=$(date -d "$daybeg" +%Y)
YEARF=$(date -d "$dayend" +%Y)
for year in $(seq "$YEAR0" "$YEARF"); do
    nn=$(( (year - YEAR0) % NUMHOSTS ))

    # Cover is annual, so much easier
    if [[ "$name" == "cover" ]]; then
        nowbeg="$year-01-01"
        nowend="$year-12-31"

        tag="${year}"

        mkdir -p "$LOGDIR/v$VER/$name/$mode/$tag"
        cd "$LOGDIR/v$VER/$name/$mode/$tag" || exit

        # Note: `command` is a shell built-in
        cmd="modvir ${MVARGS[*]} --beg $nowbeg --end $nowend"
        screen -L -dmS "modvir-$name-$mode-$tag" \
            bash --login -c "ssh -t ${HOSTS[$nn]} \"$cmd; exit\""

    # Split up vegind and burn to speed things up
    else
        # First half
        # --
        # Make sure we stay within the day range
        [[ "$year-01-01" < "$daybeg" ]] && nowbeg=$daybeg || nowbeg="$year-01-01"
        [[ "$dayend" < "$year-06-30" ]] && nowend=$dayend || nowend="$year-06-30"

        if [[ ! "$nowend" < "$nowbeg" ]]; then
            tag="${year}a"

            mkdir -p "$LOGDIR/v$VER/$name/$mode/$tag"
            cd "$LOGDIR/v$VER/$name/$mode/$tag" || exit

            cmd="modvir ${MVARGS[*]} --beg $nowbeg --end $nowend"
            screen -L -dmS "modvir-$name-$mode-$tag" \
                bash --login -c "ssh -t ${HOSTS[$nn]} \"$cmd; exit\""
        fi

        # Second half
        # ---
        # Make sure we stay within the day range
        [[ "$year-07-01" < "$daybeg" ]] && nowbeg=$daybeg || nowbeg="$year-07-01"
        [[ "$dayend" < "$year-12-31" ]] && nowend=$dayend || nowend="$year-12-31"

        if [[ ! "$nowend" < "$nowbeg" ]]; then
            tag="${year}b"

            mkdir -p "$LOGDIR/v$VER/$name/$mode/$tag"
            cd "$LOGDIR/v$VER/$name/$mode/$tag" || exit

            cmd="modvir ${MVARGS[*]} --beg $nowbeg --end $nowend"
            screen -L -dmS "modvir-$name-$mode-$tag" \
                bash --login -c "ssh -t ${HOSTS[$nn]} \"$cmd; exit\""
        fi
    fi
done
