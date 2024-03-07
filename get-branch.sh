# function to get default branch
function get-branch()
{
  dir_orig=$PWD
  local url=$1
  url="${url%/}"   # strip trailing slash (if any)
  local repo=$(basename $url)
  cd /tmp
  git clone --depth 1 -q $url
  cd $repo
  branch=$(git remote show $url | sed -n '/HEAD branch/s/.*: //p')
  cd ..
  rm -rf $repo
  cd $dir_orig
  echo $branch
}

# call the function
# example: get-branch https://github.com/deephdc/demo_app
get-branch $1
