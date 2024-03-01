#!/usr/bin/env bash

echo "################### [WARNING] ##############################
 It is advised to configure your github credentials, e.g.
   git config --global credential.helper store
 Than create $HOME/.git-credentials and add
   https://YourGithubUser:YourGithubToken@github.com
 Finally, do:
   chmod 400 .git-credentials
############################################################"

DEEP_GITHUB_ORG="https://github.com/deephdc/"
AI4_GITHUB_ORG="https://github.com/ai4os-hub/"

SCRIPT_PATH="$(dirname "$(readlink -f "$0")")"

MIGRATION_WORKDIR="migration"
rm -rf $MIGRATION_WORKDIR
mkdir -p $MIGRATION_WORKDIR
cd $MIGRATION_WORKDIR

# function to check URL exists
function check-url()
{
  url=$1
  if curl --output /dev/null --head --silent --fail $url
  then
     echo "[OK] Found $url"
  else
     echo "[ERROR] URL NOT FOUND, $url"
     exit 1
  fi
}

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

# Configure repo URLs, retrieve names of defaults branches
read -p "deephdc code repo (e.g. demo_app): " DEEP_CODE_REPO
DEEP_CODE_REPO_URL=${DEEP_GITHUB_ORG}${DEEP_CODE_REPO}
check-url ${DEEP_CODE_REPO_URL}
DEEP_CODE_REPO_BRANCH=$(get-branch ${DEEP_CODE_REPO_URL})
echo "Default Branch: ${DEEP_CODE_REPO_BRANCH}"

echo ""
read -p "deephdc Dockerfile repo (usually has 'DEEP-OC' in the name, e.g. DEEP-OC-demo_app): " DEEP_DOCKERFILE_REPO
DEEP_DOCKERFILE_REPO_URL=${DEEP_GITHUB_ORG}${DEEP_DOCKERFILE_REPO}
check-url ${DEEP_DOCKERFILE_REPO_URL}
DEEP_DOCKERFILE_REPO_BRANCH=$(get-branch ${DEEP_DOCKERFILE_REPO_URL})
echo "Default Branch: ${DEEP_DOCKERFILE_REPO_BRANCH}"

echo ""
read -p "(new) ai4os-hub code repo (has to be created first, empty! e.g. ai4os-demo-app): " AI4_CODE_REPO
AI4_CODE_REPO_URL=${AI4_GITHUB_ORG}${AI4_CODE_REPO}
check-url ${AI4_CODE_REPO_URL}
AI4_CODE_REPO_BRANCH=${DEEP_CODE_REPO_BRANCH}
read -p "Do you want to rename default branch (${DEEP_CODE_REPO_BRANCH})? (e.g. to 'main')? (Y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]
then
   read -p "Please, give new name of the default branch: " AI4_CODE_REPO_BRANCH
fi
echo ${AI4_CODE_REPO_BRANCH}

# Mirror old code repo to ai4os-hub
echo ""
echo "[INFO] We bare clone now $DEEP_CODE_REPO_URL"
git clone --bare $DEEP_CODE_REPO_URL
# go into cloned repo
cd ${DEEP_CODE_REPO}.git
echo "[INFO] Pushing now this repo to $AI4_CODE_REPO_URL"
git push --mirror $AI4_CODE_REPO_URL
cd ..
read -p "Delete now local directory ${DEEP_CODE_REPO}.git (advised)? (Y/N) " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
   rm -rf ${DEEP_CODE_REPO}.git
fi

# Copy original Dockerfile, metadata.json to the code repo
echo ""
echo "[INFO] We clone now ${DEEP_DOCKERFILE_REPO_URL}"
git clone ${DEEP_DOCKERFILE_REPO_URL}
echo "... and "
git clone ${AI4_CODE_REPO_URL}
cd ${AI4_CODE_REPO}
# swtich to default for the DEEP_CODE_REPO
git checkout ${DEEP_CODE_REPO_BRANCH}
# rename default branch, if needed
if [ "${DEEP_CODE_REPO_BRANCH}" != "${AI4_CODE_REPO_BRANCH}" ]; then
  git branch -m ${AI4_CODE_REPO_BRANCH}
  git push origin :${DEEP_CODE_REPO_BRANCH} ${AI4_CODE_REPO_BRANCH}
  git push origin -u ${AI4_CODE_REPO_BRANCH}
fi
echo "[INFO] Copy now original Dockerfile, metadata.json from ../${DEEP_DOCKERFILE_REPO}"
cp ../${DEEP_DOCKERFILE_REPO}/Dockerfile ./
cp ../${DEEP_DOCKERFILE_REPO}/metadata.json ./
mkdir docker
touch docker/.gitkeep
git add Dockerfile metadata.json docker/*
git commit -a -m "feat: migration-1, Add original Dockerfile, metadata.json"
echo "[INFO] Added original Dockerfile, metadata.json, now pushing changes to ai4os-hub/"
git push origin

# Delete: .stestr.conf, Jenkinsfile, tox.ini
git rm .stestr.conf
git rm Jenkinsfile
git rm tox.ini

# Copy/Paste files: Jenkinsfile
cp ${SCRIPT_PATH}/cp-Jenkinsfile ./Jenkinsfile
git add Jenkinsfile

# Can UPDATE automatically, EXISTING files:
# metadata.json : replace dockerfile_repo, docker_registry_repo, code, jenkins_badge, jenkins_url
DEEP_JENKINS_BADGE="https://jenkins.indigo-datacloud.eu/buildStatus/icon?job=Pipeline-as-code/DEEP-OC-org/${DEEP_DOCKERFILE_REPO}/${DEEP_DOCKERFILE_REPO_BRANCH}"
DEEP_JENKINS_URL="https://jenkins.indigo-datacloud.eu/job/Pipeline-as-code/job/DEEP-OC-org/job/${DEEP_DOCKERFILE_REPO}/job/${DEEP_DOCKERFILE_REPO_BRANCH}"
AI4OS_JENKINS_BADGE="https://jenkins.services.ai4os.eu/buildStatus/icon?job=AI4OS-hub/${AI4_CODE_REPO}/${AI4_CODE_REPO_BRANCH}"
AI4OS_JENKINS_URL="https://jenkins.services.ai4os.eu/job/Pipeline-as-code/job/AI4OS-hub/job/${AI4_CODE_REPO}/job/${AI4_CODE_REPO_BRANCH}/"
sed -i -e "s:${DEEP_DOCKERFILE_REPO_URL}:${AI4_CODE_REPO_URL}:g" \
-e "s:deephdc\/${DEEP_CODE_REPO}:ai4oshub\/${AI4_CODE_REPO}:g" \
-e "s:${DEEP_CODE_REPO_URL}:${AI4_CODE_REPO_URL}:g" \
-e "s:${DEEP_JENKINS_BADGE}:${AI4OS_JENKINS_BADGE}:g" \
-e "s:${DEEP_JENKINS_URL}:${AI4OS_JENKINS_URL}:g" \
metadata.json

exit 1

# setup.cfg
sed -i "s//" setup.cfg
# README.md
sed -i "s//" README.md

# Can create with replacement:
# tox.ini
# .sqa/config.yml
# .sqa/docker-compose.yml
# JenkinsConstants.groovy


# Need to UPDATE MANUALLY:
# Dockerfile
# requirements.txt
# test-requirements.txt
# OR requirements-test.txt

