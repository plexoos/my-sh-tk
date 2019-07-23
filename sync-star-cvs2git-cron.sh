#!/usr/bin/env bash
#
# This script can be run as a crontab job to sync STAR CVS repository with the
# remote Git repository github.com:star-bnl/star-cvs.git
# 
# 0 0,8,12,20 * * * /path/to/my-sh-tk/sync-star-cvs2git-cron.sh &> /path/to/my-sh-tk/sync-star-cvs2git-cron.log
#

echo -- Start crontab job at
date

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export CVSROOT="/afs/rhic.bnl.gov/star/packages/repository"
export PREFIX="/scratch/smirnovd/star-bnl-readonly"
export LOCAL_CVSROOT_DIR="${PREFIX}/star-cvs-local"

echo
echo -- Step 1. Updating local copy of CVS repository in ${LOCAL_CVSROOT_DIR}/cvs
${SCRIPT_DIR}/sync-star-cvsgit.sh cvs rsync
echo -- Done

echo
echo -- Step 1a. Clean up local copy of CVS repository in ${LOCAL_CVSROOT_DIR}/cvs
rm -fr ${LOCAL_CVSROOT_DIR}/cvs/StarDb/Geometry/tpc/tpcPadPlanes.dev2019.C,v
echo -- Done

echo
echo -- Step 2. Creating Git blob files from the local CVS repository
cvs2git --fallback-encoding=ascii --use-rcs --co=/usr/local/bin/co --force-keyword-mode=kept \
        --blobfile=${PREFIX}/git-blob.dat \
        --dumpfile=${PREFIX}/git-dump.dat \
        --username=cvs2git ${LOCAL_CVSROOT_DIR}/cvs &> ${PREFIX}/sync-star-cvs2git-cron-step2.log
echo -- Done

export LOCAL_GIT_DIR="${PREFIX}/star-bnl/star-cvs"
echo
echo -- Step 3. Recreating Git repository in ${LOCAL_GIT_DIR}
rm -fr "${LOCAL_GIT_DIR}"
mkdir -p "${LOCAL_GIT_DIR}"
cd "${LOCAL_GIT_DIR}"
git init
cat ${PREFIX}/git-blob.dat ${PREFIX}/git-dump.dat | git fast-import
git checkout
java -jar ${PREFIX}/bfg-1.13.0.jar --delete-folders .git --delete-files .git --no-blob-protection ./
git remote add origin git@github.com-starbnlbot:star-bnl/star-cvs.git
git push origin --all
git push origin --tags
chmod -R g+w ./
echo -- Done

echo
echo -- Done with crontab job at
date

exit 0
