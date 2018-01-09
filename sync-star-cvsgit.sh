#!/usr/bin/env bash
#
# In this script we copy select CVS modules from a large CVS repository to
# a single Git repository. The mapping of CVS modules to Git repositories is
# controlled by $CVSGIT_MODULE_MAP defined below.
#
# Prerequisites
# -------------
#
# - The environment variable $CVSROOT must contain the path to the CVS
# repository with the CVSROOT/ subdirectory.
#
# - A 'star-cvsgit-authors.txt' file mapping CVS user names to personal names and emails.
# E.g.
#
#     cat star-cvsgit-authors.txt
#     cvsuser1=John Doe <doe@somewhere.com>
#     cvsuser2=Jane Roe <roe@somewhereelse.com>
#     ...
#
# How to use
# ----------
#
# When export for the first time use the 'init' mode to create a new git
# repository. E.g.:
#
#     PREFIX=/tmp sync-star-cvsgit.sh muDst init
#
# For subsequent updates of an existing git repository use the 'update' mode.
# E.g.:
#
#     sync-star-cvsgit.sh bfchain [update]
#
# To export a commit from a git repository to CVS:
#
#     git cvsexportcommit -w /path/to/cvs/checkout -v -u -p -c <sha1_id>
#


# Set typical default values for script variables
: ${PREFIX:="${HOME}"}
: ${LOCAL_CVSROOT_DIR:="${PREFIX}/star-cvs"}
: ${LOCAL_GIT_DIR:="${PREFIX}/star-bnl"}
: ${CVS_TOP_MODULE:="StRoot"}
: ${CVSGIT_AUTHORS:="star-cvsgit-authors.txt"}
: ${CVSGIT_MODE:="update"}


# Predefined map linking CVS modules to proposed git repositories
declare -A CVSGIT_MODULE_MAP

CVSGIT_MODULE_MAP["base"]="macros Star2Root StarClassLibrary StarMagField StarRoot St_base StBFChain StBichsel StChain StIOMaker StMagF StStarLogger StTreeMaker StUtilities"
CVSGIT_MODULE_MAP["stevent"]="StAssociationMaker StEvent StEventCompendiumMaker StEventMaker StEventUtilities StMcEvent StMcEventMaker"
CVSGIT_MODULE_MAP["picoDst"]="StPicoDstMaker StPicoEvent"
CVSGIT_MODULE_MAP["muDst"]="StMuDSTMaker StStrangeMuDstMaker"
CVSGIT_MODULE_MAP["detectors"]="StTpcCalibrationMaker StTpcDb StTpcEvalMaker StTpcHitMaker StTpcHitMoverMaker \
   StTpcPool StTpcRSMaker StTpcTagMaker StdEdxY2Maker \
   StFtpcCalibMaker StFtpcClusterMaker StFtpcDriftMapMaker StFtpcMixerMaker StFtpcSlowSimMaker StFtpcTrackMaker \
   StIstClusterMaker StIstDbMaker StIstHitMaker StIstRawHitMaker StIstSimMaker StIstUtil \
   StPxlClusterMaker StPxlDbMaker StPxlHitMaker StPxlRawHitMaker StPxlSimMaker StPxlUtil \
   StMtdCalibMaker StMtdEvtFilterMaker StMtdHitMaker StMtdMatchMaker StMtdQAMaker StMtdSimMaker StMtdUtil \
   StPmdCalibrationMaker StPmdClusterMaker StPmdDiscriminatorMaker StPmdReadMaker StPmdSimulatorMaker StPmdUtil \
   StHbtMaker \
   StFgtA2CMaker StFgtClusterMaker StFgtDbMaker StFgtPointMaker StFgtPool StFgtRawMaker StFgtSimulatorMaker StFgtUtil \
   StEmcADCtoEMaker StEmcCalibrationMaker StEmcMixerMaker StEmcPool StEmcRawMaker StEmcSimulatorMaker StEmcTriggerMaker StEmcUtil \
   StEEmcDbMaker StEEmcPool StEEmcSimulatorMaker StEEmcUtil StPreEclMaker StEpcMaker \
   StEpdDbMaker \
   StBTofCalibMaker StBTofHitMaker StBTofMatchMaker StBTofMixerMaker StBTofPool StBTofSimMaker StBTofUtil \
   StTofCalibMaker StTofHitMaker StTofMaker StTofPool StTofSimMaker StTofUtil StTofpMatchMaker StTofrMatchMaker \
   StFmsDbMaker StFmsFastSimulatorMaker StFmsFpsMaker StFmsHitMaker StFmsPointMaker StFmsUtil \
   StVpdCalibMaker StVpdSimMaker \
   StSvtAlignMaker StSvtCalibMaker StSvtClassLibrary StSvtClusterMaker StSvtDaqMaker StSvtDbMaker StSvtPool StSvtSelfMaker StSvtSeqAdjMaker StSvtSimulationMaker \
   StSstDaqMaker StSstPointMaker StSstUtil StSsdClusterMaker StSsdDaqMaker StSsdDbMaker StSsdEvalMaker StSsdFastSimMaker StSsdPointMaker StSsdSimulationMaker StSsdUtil \
   "
CVSGIT_MODULE_MAP["sti"]="Sti StiCA StiEmc StiEvaluator StiFtpc StiGui StiIst StiMaker StiPixel StiPxl StiRnD StiSsd StiSvt StiTpc StiUtilities"
CVSGIT_MODULE_MAP["stv"]="Stv StvMaker StvSeed StvUtil"
CVSGIT_MODULE_MAP["ca-tracker"]="TPCCATracker"
CVSGIT_MODULE_MAP["vertex"]="StGenericVertexMaker StZdcVertexMaker StSecondaryVertexMaker"
CVSGIT_MODULE_MAP["RTS"]="RTS"
CVSGIT_MODULE_MAP["db"]="StDbBroker StDbLib St_db_Maker StDbUtilities StDetectorDbMaker"
CVSGIT_MODULE_MAP["trigger"]="StTriggerData StTriggerDataMaker StTriggerUtilities StTrgDatFileReader StTrgMaker"
CVSGIT_MODULE_MAP["daq"]="StDaqLib StDAQMaker"
CVSGIT_MODULE_MAP["geant"]="St_geant_Maker"
CVSGIT_MODULE_MAP["phys"]="StGammaMaker StRefMultCorr StJetFinder StJetMaker StSpinPool StHeavyTagMaker \
   StHighPtTagsMaker StTagsMaker St_QA_Maker StAnalysisMaker StAnalysisUtilities \
   "

# pams is outside of StRoot therefore it requires CVS_TOP_MODULE=pams
CVSGIT_MODULE_MAP["pams"]="ctf ebye emc ftpc global l3 mwc sim svt tables tls tpc trg vpd"
# vmc is outside of StRoot therefore it requires CVS_TOP_MODULE=StarVMC
CVSGIT_MODULE_MAP["vmc"]="Geometry StarAgmlChecker StarAgmlLib StarAgmlUtil StarAgmlViewer StarGeometry StarVMCApplication StVMCMaker StVmcTools xgeometry"

# Check input arguments provided by user
if [ -n "$1" ]
then
   CVSGIT_MODULE=$1
   LOCAL_GIT_DIR="${LOCAL_GIT_DIR}/star-${CVSGIT_MODULE}"
else
   echo "ERROR: First parameter must be provided:"
   echo "$ ${0##*/} muDst|fgt|vertex [update|init]"
   exit 1
fi

if [ -n "$2" ]
then
   if [ "$2" == "init" ] || [ "$2" == "update" ]
   then
      CVSGIT_MODE=$2
   else
      echo "ERROR: Second parameter must be either \"update\" (default) or \"init\":"
      echo "$ ${0##*/} fgt|vertex|... [update|init]"
      exit 1
   fi
fi

# Just print out the variable's values for the record
echo "The following variables are set:"
echo -e "\t CVSGIT_MODULE:      \"$CVSGIT_MODULE\""
echo -e "\t LOCAL_CVSROOT_DIR:  \"$LOCAL_CVSROOT_DIR\""
echo -e "\t LOCAL_GIT_DIR:      \"$LOCAL_GIT_DIR\""
echo -e "\t CVS_TOP_MODULE:     \"$CVS_TOP_MODULE\""
echo -e "\t CVSGIT_AUTHORS:     \"$CVSGIT_AUTHORS\""

# Create output directories
mkdir -p "${LOCAL_CVSROOT_DIR}"
mkdir -p "${LOCAL_CVSROOT_DIR}/${CVSGIT_MODULE}"
mkdir -p "${LOCAL_GIT_DIR}"

ln -fs ../CVSROOT "${LOCAL_CVSROOT_DIR}/${CVSGIT_MODULE}/"

# Sync local CVSROOT with the central CVS repository
cmd="rsync -a --delete ${CVSROOT}/CVSROOT ${LOCAL_CVSROOT_DIR}/"

echo
echo ---\> Updating local CVSROOT directory... ${LOCAL_CVSROOT_DIR}/CVSROOT
echo $ $cmd
echo
$cmd

# Now sync all local CVS submodules with the central CVS repository
for CVSGIT_ENTRY in ${CVSGIT_MODULE_MAP[$CVSGIT_MODULE]}
do
   cmd="rsync -a --delete -R ${CVSROOT}/./${CVS_TOP_MODULE}/${CVSGIT_ENTRY} ${LOCAL_CVSROOT_DIR}/${CVSGIT_MODULE}/"
   echo ---\> Updating local CVS module... ${CVSGIT_MODULE}/${CVSGIT_ENTRY}
   echo $ $cmd
   $cmd
done

# Finally import changes from CVS to git repo
echo
echo ---\> Syncing ${LOCAL_GIT_DIR} ...

# Define the main command to import from cvs to git. Also works when run for the
# first time in 'init' mode
cmd_git_cvsimport="git cvsimport -a -v -r cvs -A ${CVSGIT_AUTHORS} -C ${LOCAL_GIT_DIR} -d ${LOCAL_CVSROOT_DIR}/${CVSGIT_MODULE} ${CVS_TOP_MODULE}"

# If this is the first time import just execute the import command and exit
if [ "$CVSGIT_MODE" == "init" ]
then
   echo $ ${cmd_git_cvsimport}
   ${cmd_git_cvsimport} &> /dev/null
   exit 0
fi

# Proceed only in case of update
cd "${LOCAL_GIT_DIR}" || exit

# In case there are local changes stash them first
git stash
git rev-parse --verify cvs/master
CVSGIT_BRANCH_EXISTS="$?"

# Check the exit code of the previous command
if [ "$CVSGIT_BRANCH_EXISTS" -eq "0" ]
then
   echo -e "Found cvs/master branch"
else
   echo -e "fatal: cvs/master branch not found. Exiting...\n"
   echo -e "Try using 'init' argument:"
   echo -e "$ ${0##*/} <git-repo-id> [update|init]\n"
   exit 1
fi

git checkout -B cvs cvs/master

# Run the main cvs-import/git-update command
echo $ ${cmd_git_cvsimport}
${cmd_git_cvsimport} &> /dev/null

git ls-remote --exit-code . origin/master &> /dev/null

# Check the exit code of the previous command
if [ "$?" -eq "0" ]
then
   echo -e "Found remote origin/master"
else
   echo -e "Remote origin/master not found. Creating one..."
   git remote add origin "git@github.com:star-bnl/star-${CVSGIT_MODULE}.git"
   git fetch origin
fi

git remote -v
git push origin cvs
git push --tags
git checkout -B master origin/master

exit 0
