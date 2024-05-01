#!/usr/bin/env bash

echo "################### [WARNING] ##############################
 It is advised to configure your github credentials, e.g.
   git config --global credential.helper store
 Then create $HOME/.git-credentials and add
   https://YourGithubUser:YourGithubToken@github.com
 Finally, do:
   chmod 400 .git-credentials
############################################################"

DEEP_GITHUB_ORG="https://github.com/deephdc/"
AI4_GITHUB_ORG="https://github.com/ai4os-hub/"

SCRIPT_PATH="$(dirname "$(readlink -f "$0")")"

MIGRATION_WORKDIR="migration-child"
rm -rf $MIGRATION_WORKDIR
mkdir -p $MIGRATION_WORKDIR
cd $MIGRATION_WORKDIR

# function to check that URL exists
function check-url()
{
  url=$1
  if curl --output /dev/null --head --silent --fail $url
  then
     echo "Found $url"
  else
     echo "[ERROR] URL NOT FOUND, $url"
     exit 1
  fi
}

# function to get default branch
get_branch=$SCRIPT_PATH/get-branch.sh

# function to replace standard old URLs
replace_old_urls=$SCRIPT_PATH/replace-old-urls.sh

# function to find and replace a piece of text/paragraph
search_and_replace=$SCRIPT_PATH/search-and-replace.sh

## Let's start
# 1. Configure repo URLs, retrieve names of defaults branches
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "1. Configure Repos: configure old (deephdc) and new (ai4os) repo URL   "
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
read -p "Press enter to continue"

read -p "deephdc code repo (\"child\" app, usually has 'DEEP-OC' in the name): " DEEP_CODE_REPO
export DEEP_CODE_REPO="${DEEP_CODE_REPO%/}"  # strip trailing slash (if any)
export DEEP_CODE_REPO_URL=${DEEP_GITHUB_ORG}${DEEP_CODE_REPO}
check-url ${DEEP_CODE_REPO_URL}
export DEEP_CODE_REPO_BRANCH=$($get_branch ${DEEP_CODE_REPO_URL})
echo "Found Default Branch: ${DEEP_CODE_REPO_BRANCH}"

echo ""
read -p "NEW ai4os-hub code repo (has to be created first, empty! e.g. ai4os-demo-app): " AI4_CODE_REPO
export AI4_CODE_REPO="${AI4_CODE_REPO%/}"  # strip trailing slash (if any)
export AI4_CODE_REPO_URL=${AI4_GITHUB_ORG}${AI4_CODE_REPO}
check-url ${AI4_CODE_REPO_URL}
export AI4_CODE_REPO_BRANCH=${DEEP_CODE_REPO_BRANCH}
read -p "Do you want to rename default branch (${DEEP_CODE_REPO_BRANCH})? (e.g. to 'main')? (Y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]
then
   read -p "Please, give new name of the branch: " AI4_CODE_REPO_BRANCH
fi

echo ""
read -p "deephdc PARENT Docker image (check Dockerfile, row \"FROM deephdc/xyz\", NO TAG): " DEEP_FROM_DOCKERIMAGE

echo ""
read -p "NEW ai4oshub PARENT Docker image (e.g. ai4oshub/ai4os-image-classification-tf): " AI4_FROM_DOCKERIMAGE

# Mirror old code repo to ai4os-hub
echo ""
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "2. Combine old deephdc code:"
echo " * mirror ${DEEP_CODE_REPO_URL} to ${AI4_CODE_REPO_URL}"
echo " * rename branch, if requested"
echo " * commmit changes to ${AI4_CODE_REPO_URL}"   
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
read -p "Press enter to continue"
echo "[INFO] We bare clone $DEEP_CODE_REPO_URL"
git clone --bare $DEEP_CODE_REPO_URL
# go into cloned repo
cd ${DEEP_CODE_REPO}.git
echo "[INFO] Pushing now this repo to $AI4_CODE_REPO_URL"
git push --mirror $AI4_CODE_REPO_URL
cd ..
echo "[INFO] Cleaning now local directory ${DEEP_CODE_REPO}.git"
rm -rf ${DEEP_CODE_REPO}.git

# 3. Automatically UPDATE EXISTING files to replace URLs of:
# deepaas_repo, dockerfile_repo, docker_registry_repo, code, jenkins_badge, jenkins_url
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "3. Update existing files for AI4OS URL values of:"
echo "   deepaas_repo, dockerfile_repo, docker_registry_repo, code, jenkins_badge, jenkins_url, in: "
echo " * metadata.json"
echo " * README.md"
echo " * commit changes to ${AI4_CODE_REPO_URL}"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
read -p "Press enter to continue"
export DEEP_DEEPAAS_REPO_URL="https://github.com/indigo-dc/DEEPaaS"
export DEEP_DOCKERFILE_REPO=${DEEP_CODE_REPO} # to keep compatibility with migration.sh
export DEEP_DOCKERFILE_REPO_URL=${DEEP_CODE_REPO_URL} # to keep compatibility with migration.sh
export DEEP_DOCKERFILE_REPO_JENKINS_BADGE="https://jenkins.indigo-datacloud.eu/buildStatus/icon?job=Pipeline-as-code/DEEP-OC-org/${DEEP_CODE_REPO}/${DEEP_CODE_REPO_BRANCH}"
export DEEP_DOCKERFILE_REPO_JENKINS_URL="https://jenkins.indigo-datacloud.eu/job/Pipeline-as-code/job/DEEP-OC-org/job/${DEEP_CODE_REPO}/job/${DEEP_CODE_REPO_BRANCH}"
export DEEP_CODE_REPO_JENKINS_BADGE="https://jenkins.indigo-datacloud.eu/buildStatus/icon?job=Pipeline-as-code/DEEP-OC-org/${DEEP_CODE_REPO}/${DEEP_CODE_REPO_BRANCH}"
export DEEP_CODE_REPO_JENKINS_URL="https://jenkins.indigo-datacloud.eu/job/Pipeline-as-code/job/DEEP-OC-org/job/${DEEP_CODE_REPO}/job/${DEEP_CODE_REPO_BRANCH}"
export AI4_DEEPAAS_REPO_URL="https://github.com/ai4os/DEEPaaS"
export AI4_CODE_REPO_JENKINS_BADGE="https://jenkins.services.ai4os.eu/buildStatus/icon?job=AI4OS-hub/${AI4_CODE_REPO}/${AI4_CODE_REPO_BRANCH}"
export AI4_CODE_REPO_JENKINS_URL="https://jenkins.services.ai4os.eu/job/AI4OS-hub/job/${AI4_CODE_REPO}/job/${AI4_CODE_REPO_BRANCH}/"

echo ""
echo "[INFO] We clone now ${AI4_CODE_REPO_URL}"
git clone ${AI4_CODE_REPO_URL}
cd ${AI4_CODE_REPO}
# swtich to default for the DEEP_CODE_REPO
git checkout ${DEEP_CODE_REPO_BRANCH}
# rename default branch, if needed
if [ "${DEEP_CODE_REPO_BRANCH}" != "${AI4_CODE_REPO_BRANCH}" ]; then
  git branch -m ${AI4_CODE_REPO_BRANCH}
  git symbolic-ref HEAD refs/heads/${AI4_CODE_REPO_BRANCH}
  git push origin :${DEEP_CODE_REPO_BRANCH} ${AI4_CODE_REPO_BRANCH}
  git push origin -u ${AI4_CODE_REPO_BRANCH}
fi

### CHECK THAT THIS MODULE LOOKS LIKE A CHILD MODULE !!! ###
child_check=$(cat Dockerfile | grep "FROM")
if [[ ! $child_check =~ "deephdc/" ]]; then
 echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
 echo " ARE YOU SURE THIS IS A CHILD MODULE? "
 echo " Field \"FROM\" in Dockerfile does not containt \"deephdc/\""
 read -p " Press Y(es) to continue anyway or N(o) to stop (Y/N) " -n 1 -r
 if [[ $REPLY =~ ^[Nn]$ ]]; then
   echo ""
   echo "Exiting the script.."
   exit
 fi
fi

$replace_old_urls metadata.json

sed -i "s,%2F,/,gI" README.md # replace "%2F" code with "/"
sed -i -e "s,${DEEP_FROM_DOCKERIMAGE},${AI4_FROM_DOCKERIMAGE},gI" README.md
$replace_old_urls README.md

DEEP_NC="nc.deep-hybrid-datacloud.eu"
echo "[INFO] Checking for the old Nextcloud link ($DEEP_NC).."
grep -rnw './' -e $DEEP_NC
deep_nc_found=$?
if [ "$deep_nc_found" -eq 0 ]; then
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo "Found mention of the old Nextcloud, ${DEEP_NC}"
  echo "Please, consider manually updating corresponding files! (see above)"
  echo "Directory: $PWD"
  echo "FYI: AI4OS Nextcloud: https://share.services.ai4os.eu"
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  read -p "Press enter if you updated Nextcloud links or want to continue migration anyway"
  echo ""
fi
git commit -a -m "feat: migration-2, Update files with AI4OS URL values"

# 4. Update Dockerfile, requirements, and test-requirements. very much MANUAL process!
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "4. Very much MANUAL process to Update: "
echo " * Dockerfile"
echo " * commit changes to ${AI4_CODE_REPO_URL}"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
read -p "Press enter to continue"
echo ""
echo "[INFO] Replacing and checking old URLs in Dockerfile..."
$replace_old_urls Dockerfile
# backup Dockerfile
cp Dockerfile Dockerfile.bkp
echo ""
echo "[INFO] Updating FROM field in the Dockefile"
sed -i -e "s,${DEEP_FROM_DOCKERIMAGE},${AI4_FROM_DOCKERIMAGE},gI" Dockerfile
echo ""
echo "[INFO] Removing old pyVer config..."
# delete old pyVer ARG
$search_and_replace Dockerfile "/ARG/ && /pyVer/"
sed -i "/# pyVer/d" Dockerfile
sed -i "s,\$pyVer,python3,gI" Dockerfile
echo ""
read -p "Do you want now manually inspect Dockerfile (advised!)? (Y/N) " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
   "${EDITOR:-nano}" Dockerfile
fi

git commit -a -m "feat: migration-3, update Dockerfile"
git push origin

# 5. Delete/Re-add Jenkinsfile
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "5. Re-create Jenkins CI/CD: "
echo " * re-create Jenkinsfile"
echo " * create .sqa/config.yml"
echo " * create .sqa/docker-compose.yml"
echo " * create JenkinsConstants.groovy"
echo " * commit changes to ${AI4_CODE_REPO_URL}"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
read -p "Press enter to continue"
cp Jenkinsfile Jenkinsfile.deep
# check for the base_cpu_tag
base_cpu_tag=$(cat ./Jenkinsfile |grep -i "base_cpu_tag" |head -n1 |tr -d ' ' |sed 's/"//g')
DOCKER_BASE_CPU_TAG=${base_cpu_tag#*=}
# check for the base_gpu_tag
base_gpu_tag=$(cat ./Jenkinsfile |grep -i "base_gpu_tag" |head -n1 |tr -d ' ' |sed 's/"//g')
DOCKER_BASE_GPU_TAG=${base_gpu_tag#*=}
# create JenkinsConstants.groovy from the template
sed -e "s,DOCKER_BASE_CPU_TAG,${DOCKER_BASE_CPU_TAG},g" \
    -e "s,DOCKER_BASE_GPU_TAG,${DOCKER_BASE_GPU_TAG},gI" \
    ${SCRIPT_PATH}/tmpl-JenkinsConstants.groovy > JenkinsConstants.groovy
# allow to manually modify the JenkinsConstants.groovy
read -p "Do you want now manually inspect JenkinsConstants.groovy (advised!)? (Y/N) " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
   "${EDITOR:-nano}" JenkinsConstants.groovy
fi
# create Jenkinsfile from the template
cp ${SCRIPT_PATH}/cp-Jenkinsfile-child ./Jenkinsfile
mkdir .sqa
# create .sqa/config.yml from the template
sed "s,AI4_CODE_REPO,${AI4_CODE_REPO},g" ${SCRIPT_PATH}/tmpl-sqa-config-child.yml > .sqa/config.yml
AI4_CICD_DOCKER_IMAGE="indigodatacloud/ci-images:python3.8"

# create .sqa/docker-compose.yml from the template
sed "s,AI4_CICD_DOCKER_IMAGE,${AI4_CICD_DOCKER_IMAGE},g" ${SCRIPT_PATH}/tmpl-sqa-docker-compose.yml > .sqa/docker-compose.yml

# Final check, if there is any mention of DEEPHDC anywhere
grep -irnw './' -e "deephdc"
deep_found=$?
if [ "$deep_found" -eq 0 ]; then
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo "Found mention(s) of \"deephdc\""
  echo "Please, consider manually updating corresponding files! (see above)"
  echo "Directory: $PWD"
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  read -p "Press Enter if you updated necessary files or want to continue migration anyway"
  echo ""
fi

git add Jenkinsfile JenkinsConstants.groovy .sqa/*
git commit -a -m "feat: migration-4, add Jenkins CI/CD with JePL2 (.sqa)"
git push origin

# 6. Try to build Docker image locally
AI4_DOCKER_REPO=$(echo "ai4oshub/${AI4_CODE_REPO}" | awk '{print tolower($0)}')
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
read -p "6. Do you want now try to build $AI4_DOCKER_REPO Docker image locally? (Y/N) " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
   docker build --no-cache -t $AI4_DOCKER_REPO .
fi

