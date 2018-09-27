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
# 1. When export for the first time use the 'init' mode to create a new git
# repository. E.g.:
#
#     PREFIX=/tmp sync-star-cvsgit.sh cvs rsync
#     PREFIX=/tmp sync-star-cvsgit.sh muDst init
#     PREFIX=/tmp CVSGIT_AUTHORS=none LOCAL_GIT_DIR=/tmp/star-bnl-readonly sync-star-cvsgit.sh cvs init
#
# 2. Configure the newly created local Git repository.
#
#     cd /tmp/star-bnl-readonly/star-cvs
#     git remote add cvs git@github.com:star-bnl/star-cvs.git
#     git checkout -b cvs --track cvs/master
#     git push --all cvs
#     git push --tags cvs
#
# 3. For subsequent updates of an existing git repository use the 'update' mode.
# E.g.:
#
#     sync-star-cvsgit.sh cvs [update]
#
# 4. To export a commit from a git repository to CVS do:
#
#     git cvsexportcommit -w /path/to/cvs/checkout -v -u -p -c <commit_sha1_id>
#


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


# Set typical default values for script variables
: ${PREFIX:="${HOME}"}
: ${CVSROOT:="/afs/rhic.bnl.gov/star/packages/repository"}
: ${LOCAL_CVSROOT_DIR:="${PREFIX}/star-cvs-local"}
: ${LOCAL_GIT_DIR:="${PREFIX}/star-bnl"}
: ${CVS_TOP_MODULE:="StRoot"}
: ${CVSGIT_AUTHORS:="${SCRIPT_DIR}/star-cvsgit-authors.txt"}
: ${CVSGIT_MODE:="update"}


# Predefined map linking CVS modules to proposed git repositories
declare -A CVSGIT_MODULE_MAP

# A single map element defines how to export selected CVS modules to a single git repository
CVSGIT_MODULE_MAP["vertex"]="StGenericVertexMaker StZdcVertexMaker StSecondaryVertexMaker"

# All CVS modules into a single git repo, CVS_TOP_MODULE is unused in this case
CVSGIT_MODULE_MAP["soft"]="soft"
CVSGIT_MODULE_MAP["cvs"]="cvs"


# Check input arguments provided by user
if [ -n "$1" ]
then
   CVSGIT_MODULE=$1
   LOCAL_GIT_DIR="${LOCAL_GIT_DIR}/star-${CVSGIT_MODULE}"
else
   echo "ERROR: First parameter must be provided:"
   echo "$ ${0##*/} vertex|cvs|soft|... [update|init]"
   exit 1
fi

if [ -n "$2" ]
then
   if [ "$2" == "rsync" -o "$2" == "init" -o "$2" == "update" ]
   then
      CVSGIT_MODE=$2
   else
      echo "ERROR: Second parameter must be either \"update\" (default), \"rsync\", or \"init\":"
      echo "$ ${0##*/} vertex|cvs|soft|... [rsync|init|update]"
      exit 1
   fi
fi

# Special cases
case "${CVSGIT_MODULE}" in
"soft" | "cvs")
   CVS_TOP_MODULE="unused"
   ;;
*)
   #do_nothing
   ;;
esac

# Just print out the variable's values for the record
echo "The following variables are set:"
echo -e "\t CVSROOT:            \"$CVSROOT\""
echo -e "\t CVSGIT_MODULE:      \"$CVSGIT_MODULE\""
echo -e "\t LOCAL_CVSROOT_DIR:  \"$LOCAL_CVSROOT_DIR\""
echo -e "\t LOCAL_GIT_DIR:      \"$LOCAL_GIT_DIR\""
echo -e "\t CVS_TOP_MODULE:     \"$CVS_TOP_MODULE\""
echo -e "\t CVSGIT_AUTHORS:     \"$CVSGIT_AUTHORS\""
echo -e "\t SCRIPT_DIR:         \"$SCRIPT_DIR\""

# Create output directories
mkdir -p "${LOCAL_CVSROOT_DIR}"
mkdir -p "${LOCAL_CVSROOT_DIR}/${CVSGIT_MODULE}"

# Sync local CVSROOT with the central CVS repository
cmd="rsync -a --omit-dir-times --no-perms --delete ${CVSROOT}/CVSROOT ${LOCAL_CVSROOT_DIR}/"

echo
echo ---\> Updating local CVSROOT directory... ${LOCAL_CVSROOT_DIR}/CVSROOT
echo $ $cmd
$cmd

# Now sync all local CVS submodules with the central CVS repository
for CVSGIT_ENTRY in ${CVSGIT_MODULE_MAP[$CVSGIT_MODULE]}
do
   if [ "${CVSGIT_MODULE}" == "soft" -o "${CVSGIT_MODULE}" == "cvs" ]
   then
      cmd="rsync -a --omit-dir-times --no-perms --delete --exclude-from=${SCRIPT_DIR}/star-cvsgit-paths.txt -R ${CVSROOT}/./* ${LOCAL_CVSROOT_DIR}/${CVSGIT_MODULE}/"
   else
      cmd="rsync -a --omit-dir-times --no-perms --delete -R ${CVSROOT}/${CVS_TOP_MODULE}/./${CVSGIT_ENTRY} ${LOCAL_CVSROOT_DIR}/${CVSGIT_MODULE}/"
   fi

   echo
   echo ---\> Updating local CVS module... ${CVSGIT_MODULE}/${CVSGIT_ENTRY}
   echo $ $cmd
   $cmd
done

if [ "$CVSGIT_MODE" == "rsync" ]
then
   echo
   echo ---\> Done copying from ${CVSROOT} to local ${LOCAL_CVSROOT_DIR}
   exit 0
fi

# Now import changes from CVS to git repo

# Create output directories
mkdir -p "${LOCAL_GIT_DIR}"

echo
echo ---\> Syncing ${LOCAL_GIT_DIR} ...

# Define the main command to import from cvs to git. Also works when run for the
# first time in 'init' mode
#
# ...but first get the list of authors
CVSGIT_AUTHORS_OPTION=""

if [ "${CVSGIT_AUTHORS}" != "none" ]
then
   base64 -d < ${CVSGIT_AUTHORS} > "/tmp/.star-cvsgit-authors-decoded.txt"
   # ... and now set the variable to the new path
   CVSGIT_AUTHORS="/tmp/.star-cvsgit-authors-decoded.txt"
   CVSGIT_AUTHORS_OPTION=" -A ${CVSGIT_AUTHORS}"
fi

cmd_git_cvsimport="git cvsimport -a -v -r cvs ${CVSGIT_AUTHORS_OPTION} -C ${LOCAL_GIT_DIR} -d ${LOCAL_CVSROOT_DIR} ${CVSGIT_MODULE}"

# If this is the first time import just execute the import command and exit
if [ "$CVSGIT_MODE" == "init" ]
then
   echo $ ${cmd_git_cvsimport}
   ${cmd_git_cvsimport} &> /dev/null
   # Delete author list
   [[ "${CVSGIT_AUTHORS}" != "none" ]] && rm ${CVSGIT_AUTHORS}
   exit 0
fi

# Proceed only in case of 'update'
cd "${LOCAL_GIT_DIR}" || exit

# In case there are local changes stash them first
git stash
git rev-parse --verify cvs/master

# Check the exit code of the previous command
if [ "$?" -eq "0" ]
then
   echo -e "Found cvs/master branch"
else
   echo -e "FATAL: cvs/master branch not found\n"
   echo -e "Try using 'init' argument:"
   echo -e "$ ${0##*/} <git-repo-id> [update|init]\n"
   # Delete author list
   [[ "${CVSGIT_AUTHORS}" != "none" ]] && rm ${CVSGIT_AUTHORS}
   exit 1
fi

git checkout -B cvs cvs/master

# Run the main cvs-import/git-update command
echo $ ${cmd_git_cvsimport}
${cmd_git_cvsimport} &> /dev/null

# Delete author list
[[ "${CVSGIT_AUTHORS}" != "none" ]] && rm ${CVSGIT_AUTHORS}

# Check if an appropriate remote exists
git ls-remote --exit-code cvs &> /dev/null

# Check the exit code of the previous command
# Push commits into existing repo
if [ "$?" -eq "0" ]
then
   echo -e "Found remote 'cvs'. Pushing all branches to remote 'cvs'"
   git remote -v

   cvs_branches=$(git branch -r)

   for cvs_branch in ${cvs_branches}
   do
      echo "cvs_branch: ${cvs_branch}"

      if [[ $cvs_branch =~ ^cvs\/(.*)$ && "${BASH_REMATCH[1]}" != "HEAD" ]]
      then
          branch_to_export="${BASH_REMATCH[1]}"
          git branch -f ${branch_to_export} cvs/${branch_to_export}
          git push cvs ${branch_to_export}
          git branch -D ${branch_to_export}
      fi
   done

   git push cvs --tags
else
   echo -e "Remote 'cvs' not found. Pushing 'cvs' branch to 'origin'"
   git remote -v
   git push origin cvs
fi

exit 0
