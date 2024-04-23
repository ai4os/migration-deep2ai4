#!/usr/bin/env bash

# function to read file into variable
function read-file()
{
  local -n arr=$2
  # read file line-by-line
  while IFS= read -r line ; do
    arr[$index]="$line"
    index=$(($index+1))
  done < $1
}

# function to find a piece of text/paragraph
function search-and-replace()
{
  local file="$1"
  local pattern="$2"

  read-file $file lines

  # search for the pattern, find array index
  local found=0
  local match=0
  i=0
  local i_pattern=-1
  local i_empty=-1
  local i_before=-1
  local i_after=-1
  while [ "$found" == 0 ] && [ "$i" -le ${#lines[@]} ]
  do
    line=$(echo "${lines[$i]}" |tr -d " \t\n\r") # remove all spaces, tabs
    if [ "${#line}" == 0 ]; then i_empty=$i; fi

    res=$(echo "${lines[$i]}" | awk "$pattern")
    match=${#res} # if length of $res > 0, the string is found, there is match
    if [ "$match" != 0 ]; then i_pattern=$i; i_before=$i_empty; fi
    if [ "$i_empty" -gt "$i_pattern" ] && [ "$i_pattern" -ge 0 ]; then i_after=$i_empty; found=1; fi

    let i=i+1
  done

  # optionally, one can define "lines before and after"
  if [ ! -z "$3" ]; then let "i_before=$i_pattern-$3"; fi
  if [ ! -z "$4" ]; then let "i_after=$i_pattern+$4"; fi

  # if search lines found, delete them
  if [ "$found" != 0 ]; then
    # print selected lines
    echo ">>>>> Found following block ($i_before:$i_pattern:$i_after):"
    for (( i=$i_before; i<=$i_after; i++ )); do echo "${lines[$i]}"; done
    read -p "<<<<< Do you want to delete it? (Y/N) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      for (( i=$i_before; i<=$i_after; i++ )); do unset lines[$i]; done
    fi
  fi

  # save new version of the file
  # if a file for "replacement" is provided, add info from this file
  if [ ! -z "$5" ]; then
    (IFS=$'\n'; echo "${lines[*]:0:$i_before}") > $file
    cat $5 >> $file
    echo "" >> $file
    (IFS=$'\n'; echo "${lines[*]:$i_before}") >> $file
  else
    (IFS=$'\n'; echo "${lines[*]}") > $file
  fi
}

# call the function:
# positional arguments: 
# 1 - file to search for replacement
# 2 - pattern to search for
# 3 - (optional) how many lines before the found line to include for replacement
# 4 - (optional) how many lines after the found line to include for replacement
# 5 - (optional) file containing replacement text
# search-and-replace Dockerfile "/RUN/ && /jlab/ && /true/"
# (optionally) one can define "lines before and after":
# search-and-replace Dockerfile "/RUN/ && /jlab/ && /true/" 1 0
# (optionally) one can define file with replacement:
# search-and-replace Dockerfile "/RUN/ && /jlab/ && /true/" "" "" tmpl-cmd.docker
search-and-replace "$1" "$2" "$3" "$4" "$5"
