#!/bin/bash

# ------------------------------------------------------------------
# Shell script to set up and run a E3SM_FATES_TEST case
# ------------------------------------------------------------------

# ------------------------------------------------------------------
# Cleanup previous test directories if they exist
# Remove old scratch and archive directories to start fresh
# ------------------------------------------------------------------
rm -rf /projects_mirror/scratch/E3SM_FATES_TEST
rm -rf /projects_mirror/archive/E3SM_FATES_TEST

# ------------------------------------------------------------------
# Define base directories and case parameters
# ------------------------------------------------------------------

# PROJECTS_DIR is the directory containing all project files
PROJECTS_DIR="/projects_mirror"

# CIME script directory where CIME commands are located
CIME_DIR="/E3SM/cime/scripts"

# Scratch and archive directories for the case
SCRATCH_DIR="$PROJECTS_DIR/scratch"

# Case-specific directories
CASE="E3SM_FATES_TEST"
CASE_DIR="$SCRATCH_DIR/$CASE"

# Archive directory for storing model output
ARCHIVE_DIR="$PROJECTS_DIR/archive/$CASE"

# Input data directories
E3SM_INPUT_DIR="$PROJECTS_DIR/inputdata"
ELMFORC_DIR="$E3SM_INPUT_DIR/atm/datm7" # ELM forcing data directory (adjust path if necessary)

# ------------------------------------------------------------------
# Navigate to the CIME scripts directory
# ------------------------------------------------------------------
cd "$CIME_DIR"

# ------------------------------------------------------------------
# Set up model and component parameters for the simulation
# ------------------------------------------------------------------

# Model type: using E3SM model
CIME_MODEL="e3sm"

# Compset defines model components: FATES + land, ocean, and ice models
COMP="2000_DATM%QIA_ELM%BGC-FATES_SICE_SOCN_SROF_SGLC_SWAV"

# Resolution setting for Brazil region
RES="1x1_brazil"

# Machine name (use the specific machine configuration)
MACH="docker"

# Compiler setting (use the GNU compiler)
COMPILER="gnu"

# ------------------------------------------------------------------
# Create a new case with the specified parameters
# ------------------------------------------------------------------
./create_newcase --case "$CASE_DIR" --res "$RES" --compset "$COMP" --mach "$MACH" --compiler "${COMPILER}" --project "${PROJECT}"

# ------------------------------------------------------------------
# Navigate to the newly created case directory
# ------------------------------------------------------------------
cd "$CASE_DIR"

# ------------------------------------------------------------------
# Apply XML changes to configure the run
# These settings configure the model run (e.g., run length, forcing data)
# ------------------------------------------------------------------

# List of XML changes to be applied
xmlchanges=(
    "STOP_N=1"                          # Run for 1 year
    "RUN_STARTDATE=2001-01-01"          # Set the start date of the simulation
    "STOP_OPTION=nyears"                # Stop the simulation after 1 year
    "DATM_CLMNCEP_YR_START=1996"        # Start year of the atmospheric forcing data
    "DATM_CLMNCEP_YR_END=1997"          # End year of the atmospheric forcing data
    "ELM_FORCE_COLDSTART=on"            # Force cold start for ELM model
    "DIN_LOC_ROOT=$E3SM_INPUT_DIR"      # Set the root directory for input data
    "DIN_LOC_ROOT_CLMFORC=$ELMFORC_DIR" # Set the directory for ELM forcing data
    "EXEROOT=$CASE_DIR/bld"             # Directory for compiled executable
    "RUNDIR=$CASE_DIR/run"              # Directory for runtime outputs
    "DOUT_S_ROOT=$ARCHIVE_DIR"          # Directory for storing archived outputs
    "CIME_OUTPUT_ROOT=$CASE_DIR"
    "RUNDIR=${CASE_DIR}/run"
    "EXEROOT=${CASE_DIR}/bld"
    "DOUT_S"=TRUE
)

# Loop through and apply each XML change
for change in "${xmlchanges[@]}"; do
    if ! ./xmlchange "$change"; then
        echo "Error: Failed to apply XML change: $change"
        exit 1
    fi
done

# ------------------------------------------------------------------
# Set up the case (e.g., creating necessary files and directories)
# ------------------------------------------------------------------
./case.setup

# ------------------------------------------------------------------
# Preview the namelists and check the required input data
# --download flag ensures missing input data is automatically downloaded
# ------------------------------------------------------------------
./preview_namelists
./check_input_data --download

# ------------------------------------------------------------------
# Build the case (compiles the model with the chosen configuration)
# --skip-provenance-check flag avoids calling git
# ------------------------------------------------------------------

./case.build --skip-provenance-check

# ------------------------------------------------------------------
# Submit the case to the job scheduler to run the simulation
# ------------------------------------------------------------------
./case.submit

# ------------------------------------------------------------------
# Post-processing: Move to the archive history directory for output processing
# ------------------------------------------------------------------

# Define the archive directory for model output history files
ARCHIVE_HIST_DIR="$ARCHIVE_DIR/lnd/hist"

# Change to the archive history directory
cd "$ARCHIVE_HIST_DIR" 

# ------------------------------------------------------------------
# Concatenate NetCDF history output files into a single file
# ------------------------------------------------------------------
ncrcat *.h0.*.nc "Aggregated_${CASE}_Output.nc"

# ------------------------------------------------------------------
# End of script
# ------------------------------------------------------------------
