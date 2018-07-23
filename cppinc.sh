#!/usr/bin/env bash
#
# Prefix included header files in c++ code with relative path defined by an
# hierarchy of directories in some source directory `src_dir`. For example, if
# the source tree looks like this
#
#     src_dir/
#     |-- dirA1
#     |   |-- dirA2
#     |   |   `--fileA2.h
#     |   `-- dirA3
#     |       `--fileA3.h
#     `-- dirB1
#     |   `-- dirB2
#     |       `--fileB.h
#     `-- fileC.h
#
# and some source file `file.cxx` contains the following #include statements
#
#     cat file.cxx
#     ...
#     #include "dirA2/fileA2.h"
#     #include "dirA3/fileA3.h"
#     #include "fileB.h"
#     #include "src_dir/fileC.h"
#     ...
#
# Running `cppinc.sh` as
#
#     cppinc.sh /path/to/file.cxx /path/to/src_dir
#
# will modify the source file:
#
#     cat file.cxx
#     ...
#     #include "dirA1/dirA2/fileA2.h"
#     #include "dirA1/dirA3/fileA3.h"
#     #include "dirB1/dirB2/fileB.h"
#     #include "fileC.h"
#     ...


INPUT_FILE=$1
BASE_INC_DIR=$2


# Check user input
if [ ! -f "$INPUT_FILE" ]; then
   echo "Provided file \"$INPUT_FILE\" not found"
   exit 1
fi

if [[ -z "$BASE_INC_DIR" ]]
then
   BASE_INC_DIR=$(pwd)
   echo "Warning: Search directory was not provided"
   echo "Warning: Current directory \"$BASE_INC_DIR\" will be used to search for header files"
fi

if [ ! -d "$BASE_INC_DIR" ]; then
   echo "Provided directory \"$BASE_INC_DIR\" not found"
   exit 1
fi

echo
echo "File to modify: $INPUT_FILE"
echo "Base include directory: $BASE_INC_DIR"

# Parse input file for C++ #include statements
includes_str=$(gawk 'match($0,"#[[:space:]]*include[[:space:]]*([\"<])(.*)([\">])",a){printf a[0]","}' $INPUT_FILE)
headers_str=$(gawk 'match($0,"#[[:space:]]*include[[:space:]]*([\"<])(.*)([\">])",a){printf a[2]","}' $INPUT_FILE)

IFS=',' read -a includes <<< "$includes_str"
IFS=',' read -a headers  <<< "$headers_str"

# Loop over found #include statements and prepend with the path when necessary
for ((i=0; i<${#headers[@]}; ++i)); do

   current_header=${headers[i]}
   current_include=${includes[i]}

   echo
   echo -e "Found:\t${current_include} with ${current_header}"

   if [[ ${current_header} == *"/"* ]]
   then
      echo "This header already includes a path. Skipping...";
      continue;
   fi

   mycmd="find ${BASE_INC_DIR} -name ${current_header} -printf '%P\n' | head -n 1"
   new_header=$(eval $mycmd)

   if [[ -z "$new_header" ]]
   then
      echo "This header not found in base include directory. Skipping...";
      continue;
   fi

   # Escape slashes /
   new_header=$(sed -e 's/[\/&]/\\&/g' <<< "$new_header")

   mycmd="sed 's/${current_header}/${new_header}/g' <<< '${current_include}'"
   new_include=$(eval "${mycmd}")

   # Escape slashes /
   new_include_escaped=$(sed -e 's/[\/&]/\\&/g' <<< "${new_include}")

   mycmd="sed -i 's/${current_include}/${new_include_escaped}/g' $INPUT_FILE"
   echo -e "\t${current_include} ---> ${new_include}"
   eval "${mycmd}"
done
