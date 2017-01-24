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
: ${LOCAL_CVSROOT_DIR:="${HOME}/local-star-cvsroot"}
: ${LOCAL_GIT_DIR:="${HOME}/star-bnl"}
: ${CVS_TOP_MODULE:="StRoot"}
: ${CVSGIT_AUTHORS:="${HOME}/cvs_authors"}
: ${CVSGIT_MODE:="update"}


# Predefined map linking CVS modules to proposed git repositories
declare -A CVSGIT_MODULE_MAP

CVSGIT_MODULE_MAP["base"]="St_base StChain StarRoot Star2Root StarClassLibrary StarMagField StStarLogger StTreeMaker StIOMaker StBichsel StUtilities"
CVSGIT_MODULE_MAP["stevent"]="StEvent* StMcEvent* StAssociationMaker"
CVSGIT_MODULE_MAP["bfchain"]="StBFChain"
CVSGIT_MODULE_MAP["macros"]="macros"
CVSGIT_MODULE_MAP["picoDst"]="StPico*"
CVSGIT_MODULE_MAP["muDst"]="StMuDSTMaker StStrangeMuDstMaker"
CVSGIT_MODULE_MAP["tpc"]="StTpc*"
CVSGIT_MODULE_MAP["ftpc"]="StFtpc*"
CVSGIT_MODULE_MAP["ist"]="StIst*"
CVSGIT_MODULE_MAP["pxl"]="StPxl*"
CVSGIT_MODULE_MAP["mtd"]="StMtd*"
CVSGIT_MODULE_MAP["hbt"]="StHbt*"
CVSGIT_MODULE_MAP["fgt"]="StFgt*"
CVSGIT_MODULE_MAP["emc"]="StEmc* StEEmc*"
CVSGIT_MODULE_MAP["tof"]="StTof* StBTof*"
CVSGIT_MODULE_MAP["svt"]="StSvt*"
CVSGIT_MODULE_MAP["ssd"]="StSsd* StSst*"
CVSGIT_MODULE_MAP["sti"]="Sti*"
CVSGIT_MODULE_MAP["stv"]="Stv*"
CVSGIT_MODULE_MAP["ca-tracker"]="TPCCATracker"
CVSGIT_MODULE_MAP["vertex"]="StGenericVertexMaker StZdcVertexMaker StSecondaryVertexMaker"
CVSGIT_MODULE_MAP["RTS"]="RTS*"
CVSGIT_MODULE_MAP["stdb"]="StDb* StDetectorDbMaker St_db_Maker"
CVSGIT_MODULE_MAP["trigger"]="StTrigger* StTrg*"
CVSGIT_MODULE_MAP["daq"]="StDAQ* StDaq*"
CVSGIT_MODULE_MAP["geant"]="St_geant_Maker*"
CVSGIT_MODULE_MAP["phys"]="StGammaMaker StJetFinder StJetMaker"
#CVSGIT_MODULE_MAP["db-calibrations"]="Calibrations"
#CVSGIT_MODULE_MAP["pams"]="pams/global"

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


mkdir -p ${LOCAL_CVSROOT_DIR}
mkdir -p ${LOCAL_CVSROOT_DIR}/${CVSGIT_MODULE}
mkdir -p ${LOCAL_GIT_DIR}

ln -fs ../CVSROOT ${LOCAL_CVSROOT_DIR}/${CVSGIT_MODULE}/

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

cd ${LOCAL_GIT_DIR}

# In case there are local changes stash them
git stash
git rev-parse --verify cvs/master
CVSGIT_BRANCH_EXISTS="$?"

# Define command to import from cvs to git. Also works when run for the first
# time in 'init' mode
cmd_git_cvsimport="git cvsimport -a -v -r cvs -A ${CVSGIT_AUTHORS} -C ${LOCAL_GIT_DIR} -d ${LOCAL_CVSROOT_DIR}/${CVSGIT_MODULE} ${CVS_TOP_MODULE}"

if [ "$CVSGIT_MODE" == "init" ]
then
   echo $ $cmd_git_cvsimport
   $cmd_git_cvsimport&> /dev/null
   exit 0
fi

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
   git remote add origin git@github.com:star-bnl/star-${CVSGIT_MODULE}.git
   git fetch origin
fi

git remote -v
git push origin cvs
git checkout -B master origin/master

# Have not yet decided if the following should be executed by default
#git merge cvs
#git push origin master

exit 0
