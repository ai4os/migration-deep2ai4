function check-old-nc()
{
  local file=$1
  local old_nc="nc.deep-hybrid-datacloud.eu"
  DEEP_NEXTCLOUD_MENTION=$(cat $file |grep -i $old_nc)
  found=$?

  if (( found==0 )); then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "In the file ${file} found mention of the old Nextcloud, ${old_nc}"
    echo "Please, consider updating the following string:"
    echo " ${DEEP_NEXTCLOUD_MENTION}"
    echo "FYI: AI4OS Nextcloud: https://share.services.ai4os.eu"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    read -p "Do you want now manually modify $file (advised!)? (Y/N) " -n 1 -r
	if [[ $REPLY =~ ^[Yy]$ ]]; then
   	  "${EDITOR:-nano}" $file
    fi
  fi
  return $found # 0 - found, 1 - not found
}

# call the function
# example: check-old-nc README.md
check-old-nc $1
