#!/bin/bash

# Defaults
# ---
# NB: Different than modvir defaults, but those should probably be changed
# (you're never going to want to push play and have it process 25+ years)
export MIROOT="$HOME/Projects/MiCASA"				# Root dir (export needed by post)
export VERSION="NRT"						# Version (export needed by post)
RUNNAME="v$VERSION"						# Run name
daybeg=$(date -d "-1 days" +%F)
dayend=$(date -d "-1 days" +%F)
BATCH=false

# Initialize environment
# ---
# This initialization is system specific. It needs to
#     1) Activate the Python stack where MiCASA is installed,
#     2) Load the NCO utilities,
#     3) Load Matlab/Octave and define the appropriate $matlab command.
# Note that it is theoretically possible to do this all in .bashrc, but
# on NCCS Discover we don't (yet).

# Conda is designed for interactive shells, gets cranky without this
# May also define aliases which are not defined for non-interactive
. ~/.bashrc
conda activate

module load nco
# Can be replaced by Octave (in dev)
module load matlab/R2020a
export MLM_LICENSE_FILE="27000@ace64:28000@ls1,28000@ls2,28000@ls3"
matlab="matlab -nosplash -nodesktop"

# Get and check arguments
# ---
usage() {
    echo "usage: $(basename "$0") [options]"
    echo ""
    echo "Run MiCASA"
    echo ""
    echo "options:"
    echo "  -h, --help   show this help message and exit"
    echo "  --beg BEG    begin date (default: $daybeg)"
    echo "  --end END    end date (default: $dayend)"
    echo "  --ver VER    version (default: $VERSION)"
    echo "  --run RUN    run name (default: $RUNNAME)"
    echo "  --root ROOT  root directory (default: $MIROOT)"
    echo "  --batch      operate in batch mode (no user input)"
}

datecheck() {
    [[ $1 =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && date -d "$1" 2> /dev/null
}

ii=1
while [[ "$ii" -le "$#" ]]; do
    arg="${@:$ii:1}"
    if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
        usage
        exit
    elif [[ "$arg" == "--beg" ]]; then
        ii=$((ii+1))
        daybeg="${@:$ii:1}"
        if ! [[ $(datecheck "$daybeg") ]]; then
            echo "ERROR: Invalid begin date $daybeg"
            echo ""
            usage
            exit 1
        fi
    elif [[ "$arg" == "--end" ]]; then
        ii=$((ii+1))
        dayend="${@:$ii:1}"
        if ! [[ $(datecheck "$dayend") ]]; then
            echo "ERROR: Invalid end date $dayend"
            echo ""
            usage
            exit 1
        fi
    elif [[ "$arg" == "--ver" ]]; then
        ii=$((ii+1))
        VERSION="${@:$ii:1}"
        [[ "$RUNKEEP" != true ]] && RUNNAME="v$VERSION"
    elif [[ "$arg" == "--run" ]]; then
        ii=$((ii+1))
        RUNNAME="${@:$ii:1}"
        RUNKEEP=true
    elif [[ "$arg" == "--root" ]]; then
        ii=$((ii+1))
        MIROOT="${@:$ii:1}"
    elif [[ "$arg" == "--batch" ]]; then
        BATCH=true
    else
        echo "ERROR: Invalid $ii-th argument $arg"
        echo ""
        usage
        exit 1
    fi
    ii=$((ii+1))
done

# Outputs and warnings
# ---
echo "---"
echo "MiCASA" 
echo "---"

echo "WARNING: This will overwrite drivers in $MIROOT/data/v$VERSION/drivers"
echo "WARNING:             and CASA output in $MIROOT/data/$RUNNAME"
echo ""

echo "Start date: $daybeg"
echo "End   date: $dayend"

# Give a chance to abort
if [[ "$BATCH" != true ]]; then
    echo ""
    read -n1 -s -r -p $"Press any key to continue ..." unused
    echo ""
fi

# Run
# ---
MVARGS=("--ver" "$VERSION" "--data" "data/v$VERSION/drivers")
# A day before start so fill works
daybe4=$(date -d "$daybeg-1 days" +%F)

cd "$MIROOT" || exit
if [[ "$VERSION" == "NRT" ]]; then
    # Need to be split so it doesn't try to retrieve NRT MODIS collections
    modvir vegind --mode regrid --beg "$daybeg" --end "$dayend" "${MVARGS[@]}" --nrt
    modvir vegind --mode fill   --beg "$daybe4" --end "$dayend" "${MVARGS[@]}" --nrt
else
    modvir vegind --mode regrid --beg "$daybeg" --end "$dayend" "${MVARGS[@]}"
    modvir vegind --mode fill   --beg "$daybe4" --end "$dayend" "${MVARGS[@]}"
    modvir burn   --mode regrid --beg "$daybeg" --end "$dayend" "${MVARGS[@]}"
fi
cd "$MIROOT"/src/CASA || exit
[[ "$VERSION" == "NRT" ]] && $matlab -r "makeNRTburn; exit"
$matlab -r "runname = '$RUNNAME'; CASA; convertOutput; exit"
$matlab -r "runname = '$RUNNAME'; lofi.make_sink; lofi.make_3hrly_land; exit"

# Post process
# ---
numbeg=$(($(date -d "$daybeg" +%Y)*12 + $(date -d "$daybeg" +%m) - 1))
numend=$(($(date -d "$dayend" +%Y)*12 + $(date -d "$dayend" +%m) - 1))

for num in $(seq $numbeg $numend); do
    year=$(($num/12))
    mon=$(($num - $year*12 + 1))

    "$MIROOT"/src/CASA/post/process.sh $year --mon $mon --ver $VERSION --batch
done

# Forecast
# ---
# A hack for now (persistence). May want to add a climatological adjustment (ML?)?
# Note: Even if you had a met forecast, you don't have a VI and BA forecast.
# From what we've seen in other fields, it may be better to try to train a forecast
# of MET -> BA, VI or MET, C0 -> PP, ER?
[[ "$VERSION" == "NRT" ]] && "$MIROOT"/src/CASA/post/forecast.sh $dayend --batch
