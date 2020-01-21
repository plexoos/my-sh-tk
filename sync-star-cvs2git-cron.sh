#!/usr/bin/env bash
#
# This script can be run as a crontab job to sync STAR CVS repository with the
# remote Git repository github.com:star-bnl/star-cvs.git
# 
# 0 2,8,20 * * * /path/to/my-sh-tk/sync-star-cvs2git-cron.sh &> /path/to/my-sh-tk/sync-star-cvs2git-cron.log
#

echo -- Start crontab job at
date

# Set the variables
: ${SCRIPT_DIR:="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"}
: ${CVS_DIR:="rcas6010:/afs/rhic.bnl.gov/star/packages/repository"}
: ${PREFIX:="/scratch/smirnovd/star-bnl-readonly"}
: ${LOCAL_CVSROOT_DIR:="${PREFIX}/star-cvs-local"}
: ${LOCAL_GIT_DIR:="${PREFIX}/star-bnl/star-cvs"}


#
# Create or update a local copy of CVS repository
#
echo
echo -- Step 1. Updating local copy of CVS repository in ${LOCAL_CVSROOT_DIR}

mkdir -p "${LOCAL_CVSROOT_DIR}"
cmd="rsync -a --omit-dir-times --chmod=Dug=rwx,Do=rx,Fug+rw,Fo+r --delete --delete-excluded -R ${CVS_DIR}/./CVSROOT ${LOCAL_CVSROOT_DIR}/"
echo
echo ---\> Updating local CVSROOT in ${LOCAL_CVSROOT_DIR}
echo $ $cmd
$cmd

mkdir -p "${LOCAL_CVSROOT_DIR}/cvs"
cmd="rsync -a --omit-dir-times --chmod=Dug=rwx,Do=rx,Fug+rw,Fo+r --delete --delete-excluded --exclude-from=${SCRIPT_DIR}/star-cvsgit-paths.txt -R ${CVS_DIR}/./* ${LOCAL_CVSROOT_DIR}/cvs"
echo
echo ---\> Updating local CVS modules in ${LOCAL_CVSROOT_DIR}/cvs
echo $ $cmd
$cmd

echo -- Done

echo
echo -- Step 1a. Clean up local copy of CVS repository in ${LOCAL_CVSROOT_DIR}/cvs
rm -fr ${LOCAL_CVSROOT_DIR}/cvs/StarDb/Geometry/tpc/tpcPadPlanes.dev2019.C,v
echo -- Done


#
# Run cvs2git
#
echo
echo -- Step 2. Creating Git blob files from the local CVS repository
cvs2git --fallback-encoding=ascii --use-rcs --co=/usr/local/bin/co --force-keyword-mode=kept \
        --blobfile=${PREFIX}/git-blob.dat \
        --dumpfile=${PREFIX}/git-dump.dat \
        --username=cvs2git ${LOCAL_CVSROOT_DIR}/cvs &> ${PREFIX}/sync-star-cvs2git-cron-step2.log
echo -- Done

#
# Re-create the actual git repository from the blob and dump files created build by cvs2git
# Then checkout and push to the github and gitlab
#
echo
echo -- Step 3. Recreating Git repository in ${LOCAL_GIT_DIR}
rm -fr "${LOCAL_GIT_DIR}"
mkdir -p "${LOCAL_GIT_DIR}"
cd "${LOCAL_GIT_DIR}"
git init
cat ${PREFIX}/git-blob.dat ${PREFIX}/git-dump.dat | git fast-import
git checkout
java -jar ${PREFIX}/bfg-1.13.0.jar --delete-folders .git --delete-files .git --no-blob-protection ./
git remote add github git@github.com-starbnlbot:star-bnl/star-cvs.git
git push github --all
git push github --tags
git remote add gitlab git@gitlab.com-starbnlbot:star-bnl/star-cvs.git
git push gitlab --all
git push gitlab --tags
chmod -R g+w ./
echo -- Done

echo
echo -- Done with crontab job at
date

exit 0
