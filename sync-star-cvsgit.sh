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
# - A 'cvs_authors' file mapping CVS user names to personal names and emails.
# E.g.
#
#     cat cvs_authors
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
#     sync-star-cvsgit.sh muDst init
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
: ${LOCAL_CVSROOT_DIR:="${HOME}/local-star-cvs"}
: ${LOCAL_GIT_DIR:="${HOME}/star-bnl"}
: ${CVS_TOP_MODULE:="StRoot"}
: ${CVSGIT_AUTHORS:="${HOME}/cvs_authors"}
: ${CVSGIT_MODE:="update"}


# Predefined map linking CVS modules to proposed git repositories
declare -A CVSGIT_MODULE_MAP

CVSGIT_MODULE_MAP["base"]="St_base StChain StarRoot Star2Root StarClassLibrary StarMagField StStarLogger StTreeMaker StIOMaker StBichsel StUtilities"
CVSGIT_MODULE_MAP["stevent"]="StAssociationMaker StEvent StEventCompendiumMaker StEventMaker StEventUtilities StMcEvent StMcEventMaker"
CVSGIT_MODULE_MAP["bfchain"]="StBFChain"
CVSGIT_MODULE_MAP["macros"]="macros"
CVSGIT_MODULE_MAP["picoDst"]="StPicoDstMaker StPicoEvent"
CVSGIT_MODULE_MAP["muDst"]="StMuDSTMaker StStrangeMuDstMaker"
CVSGIT_MODULE_MAP["tpc"]="StTpcCalibrationMaker StTpcDb StTpcEvalMaker StTpcHitMaker StTpcHitMoverMaker StTpcPool StTpcRSMaker StTpcTagMaker"
CVSGIT_MODULE_MAP["ftpc"]="StFtpcCalibMaker StFtpcClusterMaker StFtpcDriftMapMaker StFtpcMixerMaker StFtpcSlowSimMaker StFtpcTrackMaker"
CVSGIT_MODULE_MAP["ist"]="StIstClusterMaker StIstDbMaker StIstHitMaker StIstRawHitMaker StIstSimMaker StIstUtil"
CVSGIT_MODULE_MAP["pxl"]="StPxlClusterMaker StPxlDbMaker StPxlHitMaker StPxlRawHitMaker StPxlSimMaker StPxlUtil"
CVSGIT_MODULE_MAP["mtd"]="StMtdCalibMaker StMtdEvtFilterMaker StMtdHitMaker StMtdMatchMaker StMtdQAMaker StMtdSimMaker StMtdUtil"
CVSGIT_MODULE_MAP["hbt"]="StHbtMaker"
CVSGIT_MODULE_MAP["fgt"]="StFgtA2CMaker StFgtClusterMaker StFgtDbMaker StFgtPointMaker StFgtPool StFgtRawMaker StFgtSimulatorMaker StFgtUtil"
CVSGIT_MODULE_MAP["emc"]="StEmcADCtoEMaker StEmcCalibrationMaker StEmcMixerMaker StEmcPool StEmcRawMaker StEmcSimulatorMaker StEmcTriggerMaker StEmcUtil tEEmcDbMaker tEEmcPool tEEmcSimulatorMaker tEEmcUtil"
CVSGIT_MODULE_MAP["epd"]="StEpdDbMaker"
CVSGIT_MODULE_MAP["tof"]="StBTofCalibMaker StBTofHitMaker StBTofMatchMaker StBTofMixerMaker StBTofPool StBTofSimMaker StBTofUtil StTofCalibMaker StTofHitMaker StTofMaker StTofPool StTofSimMaker StTofUtil StTofpMatchMaker StTofrMatchMaker"
CVSGIT_MODULE_MAP["fms"]="StFmsDbMaker StFmsFastSimulatorMaker StFmsFpsMaker StFmsHitMaker StFmsPointMaker StFmsUtil"
CVSGIT_MODULE_MAP["vpd"]="StVpdCalibMaker StVpdSimMaker"
CVSGIT_MODULE_MAP["svt"]="StSvtAlignMaker StSvtCalibMaker StSvtClassLibrary StSvtClusterMaker StSvtDaqMaker StSvtDbMaker StSvtPool StSvtSelfMaker StSvtSeqAdjMaker StSvtSimulationMaker"
CVSGIT_MODULE_MAP["ssd"]="StSstDaqMaker StSstPointMaker StSstUtil StSsdClusterMaker StSsdDaqMaker StSsdDbMaker StSsdEvalMaker StSsdFastSimMaker StSsdPointMaker StSsdSimulationMaker StSsdUtil"
CVSGIT_MODULE_MAP["sti"]="Sti StiCA StiEmc StiEvaluator StiFtpc StiGui StiIst StiMaker StiPixel StiPxl StiRnD StiSsd StiSvt StiTpc StiUtilities"
CVSGIT_MODULE_MAP["stv"]="Stv StvMaker StvSeed StvUtil"
CVSGIT_MODULE_MAP["ca-tracker"]="TPCCATracker"
CVSGIT_MODULE_MAP["vertex"]="StGenericVertexMaker StZdcVertexMaker StSecondaryVertexMaker"
CVSGIT_MODULE_MAP["RTS"]="RTS"
CVSGIT_MODULE_MAP["db"]="StDbBroker StDbLib St_db_Maker StDbUtilities StDetectorDbMaker"
CVSGIT_MODULE_MAP["trigger"]="StTriggerData StTriggerDataMaker StTriggerUtilities StTrgDatFileReader StTrgMaker"
CVSGIT_MODULE_MAP["daq"]="StDaqLib StDAQMaker"
CVSGIT_MODULE_MAP["geant"]="St_geant_Maker"
CVSGIT_MODULE_MAP["phys"]="StGammaMaker StJetFinder StJetMaker"
CVSGIT_MODULE_MAP["jet"]="StJetFinder StJetMaker StSpinPool/StJetEvent StSpinPool/StJetSkimEvent StSpinPool/StJets StSpinPool/StUeEvent"
#CVSGIT_MODULE_MAP["db-calibrations"]="Calibrations"
# pams is outside of StRoot therefore it requires CVS_TOP_MODULE=pams
#CVSGIT_MODULE_MAP["pams"]="ctf ebye emc ftpc global l3 mwc sim svt tables tls tpc trg vpd"
# vmc is outside of StRoot therefore it requires CVS_TOP_MODULE=StarVMC
#CVSGIT_MODULE_MAP["vmc"]="Geometry StarAgmlChecker StarAgmlLib StarAgmlUtil StarAgmlViewer StarGeometry StarVMCApplication StVMCMaker StVmcTools xgeometry"

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


mkdir -p "${LOCAL_CVSROOT_DIR}"
mkdir -p "${LOCAL_CVSROOT_DIR}/${CVSGIT_MODULE}"
mkdir -p "${LOCAL_GIT_DIR}"

ln -fs ../CVSROOT "${LOCAL_CVSROOT_DIR}/${CVSGIT_MODULE}/"

# Sync local CVSROOT with the central CVS repository
cmd="rsync -a --delete ${CVSROOT}/CVSROOT ${LOCAL_CVSROOT_DIR}/"

echo
echo ---\> Updating local CVSROOT dir... ${LOCAL_CVSROOT_DIR}/CVSROOT
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

cd "${LOCAL_GIT_DIR}" || exit

# Define command to import from cvs to git. Also works when run for the first
# time in 'init' mode
cmd_git_cvsimport="git cvsimport -a -v -r cvs -A ${CVSGIT_AUTHORS} -C ${LOCAL_GIT_DIR} -d ${LOCAL_CVSROOT_DIR}/${CVSGIT_MODULE} ${CVS_TOP_MODULE}"

if [ "$CVSGIT_MODE" == "init" ]
then
   echo $ $cmd_git_cvsimport
   $cmd_git_cvsimport &> /dev/null
   exit 0
fi

# In case there are local changes stash them
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

# The following command also works when run for the first time
echo $ $cmd_git_cvsimport
$cmd_git_cvsimport&> /dev/null

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
git checkout -B master origin/master

# Have not yet decided if the following should be executed by default
#git merge cvs
#git push origin master

exit 0
