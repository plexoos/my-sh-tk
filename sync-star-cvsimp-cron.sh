#
# This script can be called as a crontab job to sync two remote repositories
# hosted on github.com `star-soft` and `star-cvs`
# 
# 0 */2 * * * /home/smirnovd/my-sh-tk/sync-star-cvsgit-cron.sh &> /home/smirnovd/my-sh-tk/sync-star-cvsgit-cron.log
#

echo "----------------------------"
date
echo ""


export CVSROOT=/afs/rhic.bnl.gov/star/packages/repository
export PREFIX=/scratch/smirnovd/
export LOCAL_GIT_DIR=/scratch/smirnovd/star-bnl-readonly 

# Use default author list to map CVS committer login names to actual names and
# emails
/home/smirnovd/my-sh-tk/sync-star-cvsgit.sh soft

# Use CVS committer login names to author git commits
export CVSGIT_AUTHORS=none

/home/smirnovd/my-sh-tk/sync-star-cvsgit.sh cvs

echo -e "Done with crontab job"

exit 0
