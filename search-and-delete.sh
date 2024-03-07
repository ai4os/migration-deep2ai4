#!/usr/bin/env bash

# function to find a piece of text/paragraph
function search-and-delete()
{
  local file="$1"
  local before="$2"
  local after="$3"
  local pattern="$4"

  cp $file $file.bkp # make file backup
  # read file line-by-line
  while IFS= read -r line ; do
    lines[$index]="$line"
    index=$(($index+1))
  done < $file

  # search for the pattern, find array index
  local found=0
  i=0
  while [ "$found" == 0 ] && [ "$i" -le ${#lines[@]} ]
  do
    res=$(echo "${lines[$i]}" | awk "$pattern")
    found=${#res} # if length of $res > 0, the string is found
    i_p=$i
    let i=i+1
  done

  if [ "$found" != 0 ]; then
    # delete lines "before" and "after" the pattern
    let i_p_b=i_p-before
    let i_p_a=i_p+after
  
    # print selected lines
    echo ""
    echo "[Found following lines]:"
    for (( i=$i_p_b; i<=$i_p_a; i++ )); do echo "${lines[$i]}"; done
    read -p "[Do you want to delete them?] (Y/N) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      for (( i=$i_p_b; i<=$i_p_a; i++ )); do unset lines[$i]; done
    fi
  fi

  # save new version of the file
  (IFS=$'\n'; echo "${lines[*]}") > $file
}

# call the function
# example: search-and-delete Dockerfile 1 0 '^(?=.*ARG)(?=.*jlab=)'
search-and-delete "$1" "$2" "$3" "$4"
