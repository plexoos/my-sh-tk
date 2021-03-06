Vim
===

Substitute all characters in a visual block with spaces:

    :%s/\%V.\%V/ /g


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

To show a list of commits on one branch but not another:

    $ git log oldbranch ^newbranch --no-merges


find
====

Find files with name matching a regex

    $ find . -regextype posix-egrep -regex ".*\.(h|hh|cxx|cpp|cc|c|inc)$"


ssh
===

Forward jupyter notebook server running on remotehost:8888

    ssh login@gateway
    ssh -N -f -L 8888:localhost:8888 login@remotehost


LaTeX
=====

Recursively find and convert all .png files in current directory `.` to
efficient eps3 format:

    $ find . -name *.png -printf "%p\n" | awk -F ".png" '{print "convert "$1".png "$1".eps3; mv "$1".eps3 "$1".eps"}' | sh

How to pass and recognize user options in a latex file. For example, in myfile.tex:

    \ifdefined\isdraft
       \documentclass[25pt, landscape, draft]{foils}
    \else
       \documentclass[25pt, landscape, final]{foils}
    \fi

    $ latex "\def\isdraft{1} \input{myfile.tex}"


Code Profiling: callgrind, qcachegrind
======================================

For profiling studies on Mac OS it helps to have a few tools installed. I use
`macports` to instal the following useful ports:

* qcachegrind
* python3.4
* py34-pip
* graphviz
* gprof2dot

Produce a pdf call graph in two steps:

    $ gprof2dot -f callgrind -s -o callgrind.dot ./callgrind.out.#####
    $ dot -Tpdf -o callgrind.pdf callgrind.dot

`perf` is another useful utility to time a program. It can provide statistical
results from a few independent runs:

    $perf stat -r10


rclone
======

Nice utility for copying files to Google Drive using command line in linux.
Straightforward configuration and usage:

    $ rclone config
    $ rclone copy my_dir/sub_dir gdrive:public/my_dir/sub_dir


ffmpeg
======

To trim an mp3 file:

    $ ffmpeg -ss 00:01:10 -i input_file.mp3 -t 00:04:30 -acodec copy output_file.mp3

To re-map audio streams:

    $ ffmpeg -fflags genpts -i input_file.avi -map 0:0 -map 0:2 -map 0:1 -c:v copy -c:a:0 copy -c:a:1 copy output_file.mkv

To re-encode video using a different codec and keeping audio intact:

    $ ffmpeg  -i input_file.avi -b:v 1280k -vcodec mpeg4 -acodec copy output_file.avi
