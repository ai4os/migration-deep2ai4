#!/usr/bin/env bash

# function to update requirements.txt
function update-reqs()
{  
  local file="$1"
  local file_tmp="${file}.tmp"
  local pip_freeze=$2

  # make tmp copy of requirements.txt
  cp $file $file_tmp
  echo "# The following is added by the migration.sh script #" > $file
  echo "# Versions are taken from the relevant docker image #" >> $file
  echo "#" >> $file 
  echo "# For old modules one may need to add:" >> $file
  echo "# aiohttp~=3.6.0" >> $file
  echo "# flask~=1.1.0" >> $file
  echo "# Jinja2~=2.11.0" >> $file
  echo "# deepaas>=1.3.0" >> $file
  echo "# flaat~=0.8.0" >> $file
  echo "" >> $file

  # extract first element of every line in $1 (file)
  awk '{print $1}' "$file_tmp" | while read line; do
    if [[ ! "$line" =~ ^"#" ]]; then
      pkg_name=$line
      if [[ "$line" =~ ">=" ]]; then pkg_name=${line%">="*}; fi
      if [[ "$line" =~ "==" ]]; then pkg_name=${line%"=="*}; fi
      if [[ "$line" =~ "~=" ]]; then pkg_name=${line%"~="*}; fi
      if [ ${#pkg_name} -gt 3 ]; then
        pkg_version=$(echo "${pip_freeze[*]}" |grep -i "${pkg_name}=") #IFS=$'\n'; 
        pkg_version=$(echo ${pkg_version/"=="/"~="})
        echo $pkg_version >> $file
      fi
    fi
  done

  # carriege return may appear at the line end, remove it
  sed -i -e "s,\r,,g" $file
  
  # now copy old content but commented
  echo "" >> $file
  echo "# Below is the old content of requirements.txt" >> $file
  echo "#" >> $file
  # read file line-by-line
  while IFS= read -r line ; do
    if [ ${#line} -gt 3 ]; then echo "#${line}" >> $file; fi
    index=$(($index+1))
  done < $file_tmp
  
  return_code=$?
  if [ "$return_code" -eq 0 ]; then rm $file_tmp; fi

}

# example call:
# update-reqs requirements.txt $PIP_FREEZE
update-reqs "$1" "$2"
