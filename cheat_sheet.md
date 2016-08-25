Git
===

Print contributions to repository:

    $ git log --no-merges --pretty=format:"Author: %an" --shortstat | awk \
       'BEGIN {an="";} \
       {if ($1=="Author:") {$1=""; an=$0; cmits[an]+=1;} else {files[an]+=$1; ladd[an]+=$4; ldel[an]+=$6} } \
       END {             printf "%7s %30s   %7s |   %7s | %8s | %8s \n", "sort by", "", "commits", "files/c", "lines++", "lines--"; \
       for (an in cmits) printf "%7d %30s:  %7d | %9.1f | %8d | %8d \n", cmits[an], an, cmits[an], files[an]/cmits[an], ladd[an], ldel[an] | "sort -n -k1 -r"; }'

where awk variables are:

    an: current author name   cmits: number of commits                    ladd: lines added
                              files: number of non-unique files changed   ldel: lines deleted
