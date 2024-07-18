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

MIGRATION_WORKDIR="migration"
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

function load-nano()
{ local file=$1
  read -p "Do you want now manually inspect ${file} (advised!)? (Y/N) " -n 1 -r
  if [[ $REPLY =~ ^[Yy]$ ]]; then
     "${EDITOR:-nano}" $file
  fi
}

function grep_remains()
{ local search_str=$1
  local found_this=127
  echo ">>> Now checking for \"${search_str}\" remaining mentions, see print-outs below:"

  grep -rnwi './' --exclude '*.bkp' --exclude-dir '.git' -e $search_str
  found_this=$?

  if [ "$found_this" -eq 0 ]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Found mention(s) of $search_str"
    echo "Please, consider manually updating corresponding files! (see above)"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    read -p "Press Enter if you updated necessary files or want to continue migration anyway"
    echo ""
  fi
}

# function to get default branch
get_branch=$SCRIPT_PATH/get-branch.sh

# function to replace standard old URLs
replace_old_urls=$SCRIPT_PATH/replace-old-urls.sh

# function to find and replace a piece of text/paragraph
search_and_replace=$SCRIPT_PATH/search-and-replace.sh

# function to update requirements.txt with relevant versions
update_reqs=$SCRIPT_PATH/update-reqs.sh

## Let's start
# 1. Configure repo URLs, retrieve names of defaults branches
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "1. Configure Repos: configure old (deephdc) and new (ai4os) repos URLs   "
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
read -p "Press enter to continue"

read -p "deephdc code repo (e.g. demo_app): " DEEP_CODE_REPO
export DEEP_CODE_REPO="${DEEP_CODE_REPO%/}"  # strip trailing slash (if any)
export DEEP_CODE_REPO_URL=${DEEP_GITHUB_ORG}${DEEP_CODE_REPO}
check-url ${DEEP_CODE_REPO_URL}
export DEEP_CODE_REPO_BRANCH=$($get_branch ${DEEP_CODE_REPO_URL})
echo "Found Default Branch: ${DEEP_CODE_REPO_BRANCH}"

echo ""
read -p "deephdc Dockerfile repo (usually has 'DEEP-OC' in the name, e.g. DEEP-OC-demo_app): " DEEP_DOCKERFILE_REPO
export DEEP_DOCKERFILE_REPO="${DEEP_DOCKERFILE_REPO%/}"  # strip trailing slash (if any)
export DEEP_DOCKERFILE_REPO_URL=${DEEP_GITHUB_ORG}${DEEP_DOCKERFILE_REPO}
check-url ${DEEP_DOCKERFILE_REPO_URL}
export DEEP_DOCKERFILE_REPO_BRANCH=$($get_branch ${DEEP_DOCKERFILE_REPO_URL})
echo "Found Default Branch: ${DEEP_DOCKERFILE_REPO_BRANCH}"

echo ""
read -p "(new) ai4os-hub code repo (has to be created first, empty! e.g. ai4os-demo-app): " AI4_CODE_REPO
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

# Mirror old code repo to ai4os-hub
echo ""
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "2. Combine old deephdc code:"
echo " * mirror ${DEEP_CODE_REPO_URL} to ${AI4_CODE_REPO_URL}"
echo " * copy Dockerfile and metadata.json from ${DEEP_DOCKERFILE_REPO_URL}"
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
  git symbolic-ref HEAD refs/heads/${AI4_CODE_REPO_BRANCH}
  git push origin :${DEEP_CODE_REPO_BRANCH} ${AI4_CODE_REPO_BRANCH}
  git push origin -u ${AI4_CODE_REPO_BRANCH}
fi
echo "[INFO] Copy now original Dockerfile, metadata.json from ../${DEEP_DOCKERFILE_REPO}"
cp ../${DEEP_DOCKERFILE_REPO}/Dockerfile ./
cp ../${DEEP_DOCKERFILE_REPO}/metadata.json ./
mkdir docker
touch docker/.gitkeep
git add Dockerfile metadata.json docker/*
echo "[INFO] Added original Dockerfile, metadata.json, now pushing changes to ai4os-hub/"
git commit -a -m "feat: migration-1, Add original Dockerfile, metadata.json"
git push origin

# 3. Automatically UPDATE EXISTING files to replace URLs of:
# deepaas_repo, dockerfile_repo, docker_registry_repo, code, jenkins_badge, jenkins_url
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "3. Update existing files for AI4OS URL values of:"
echo "   deepaas_repo, dockerfile_repo, docker_registry_repo, code, jenkins_badge, jenkins_url, in: "
echo " * metadata.json"
echo " * setup.cfg"
echo " * README.md"
echo " * commit changes to ${AI4_CODE_REPO_URL}"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
read -p "Press enter to continue"
export DEEP_DEEPAAS_REPO_URL="https://github.com/indigo-dc/DEEPaaS"
export DEEP_DOCKERFILE_REPO_JENKINS_BADGE="https://jenkins.indigo-datacloud.eu/buildStatus/icon?job=Pipeline-as-code/DEEP-OC-org/${DEEP_DOCKERFILE_REPO}/${DEEP_DOCKERFILE_REPO_BRANCH}"
export DEEP_DOCKERFILE_REPO_JENKINS_URL="https://jenkins.indigo-datacloud.eu/job/Pipeline-as-code/job/DEEP-OC-org/job/${DEEP_DOCKERFILE_REPO}/job/${DEEP_DOCKERFILE_REPO_BRANCH}"
export DEEP_CODE_REPO_JENKINS_BADGE="https://jenkins.indigo-datacloud.eu/buildStatus/icon?job=Pipeline-as-code/DEEP-OC-org/${DEEP_CODE_REPO}/${DEEP_CODE_REPO_BRANCH}"
export DEEP_CODE_REPO_JENKINS_URL="https://jenkins.indigo-datacloud.eu/job/Pipeline-as-code/job/DEEP-OC-org/job/${DEEP_CODE_REPO}/job/${DEEP_CODE_REPO_BRANCH}"
export AI4_DEEPAAS_REPO_URL="https://github.com/ai4os/DEEPaaS"
export AI4_CODE_REPO_JENKINS_BADGE="https://jenkins.services.ai4os.eu/buildStatus/icon?job=AI4OS-hub/${AI4_CODE_REPO}/${AI4_CODE_REPO_BRANCH}"
export AI4_CODE_REPO_JENKINS_URL="https://jenkins.services.ai4os.eu/job/AI4OS-hub/job/${AI4_CODE_REPO}/job/${AI4_CODE_REPO_BRANCH}/"

# update metadata.json
$replace_old_urls metadata.json
cp metadata.json metadata.bkp && jq '.sources += { "ai4_template": "ai4-template/1.9.9"}' metadata.bkp > metadata.json
load-nano metadata.json

if [ -e "setup.cfg" ]; then
  AI4_CODE_PYPKG=$(python3 ./setup.py --quiet --name)
  read -p "Do you want to replace setup.cfg and setup.py with pyproject.toml? (Y/N) " -n 1 -r
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    AI4_CODE_CAPITAL=$(echo "$AI4_CODE_PYPKG" | awk '{print toupper($0)}')
    AI4_CODE_AUTHORS="name = \"$(python3 ./setup.py --quiet --author)\", email = \"$(python3 ./setup.py --quiet --author-email)\""
    AI4_CODE_DESCRIPTION=$(python3 ./setup.py --quiet --description)
    AI4_CODE_LICENSE=$(python3 ./setup.py --quiet --license)
    sed -e "s,AI4_CODE_PYPKG,${AI4_CODE_PYPKG},gI" \
        -e "s,AI4_CODE_CAPITAL,${AI4_CODE_CAPITAL},gI" \
        -e "s,AI4_CODE_AUTHORS,${AI4_CODE_AUTHORS},gI" \
        -e "s,AI4_CODE_DESCRIPTION,${AI4_CODE_DESCRIPTION},gI" \
        -e "s,AI4_CODE_LICENSE,${AI4_CODE_LICENSE},gI" \
        ${SCRIPT_PATH}/tmpl-pyproject.toml > pyproject.toml
    git add pyproject.toml
    load_nano pyproject.toml
    rm setup.cfg setup.py
  else
    sed -i "s,http://github.com,https://github.com,gI" setup.cfg  # in case "http://" is wrongly given for github.com
    $replace_old_urls setup.cfg
  fi
fi

if [ -e "pyproject.toml" ]; then
  AI4_CODE_PYPKG=$(cat pyproject.toml | grep -A1 "deepaas.v2.model" \
    | cut -d"]" -f2 |cut -d"=" -f2 | tr -d '[:space:]' |tr -d '\"' |cut -d'.' -f1 )
fi

sed -i "s,%2F,/,gI" README.md # replace "%2F" code with "/"
$replace_old_urls README.md

DEEP_NC="nc.deep-hybrid-datacloud.eu"
echo "[INFO] Checking for the old Nextcloud link ($DEEP_NC).."
grep -rnw './' --exclude *.bkp -e $DEEP_NC
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
git push origin

# 4. Update Dockerfile, requirements, and test-requirements. very much MANUAL process!
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "4. Very much MANUAL process to Update: "
echo " * Dockerfile"
echo " * requirements.txt"
echo " * test-requirements.txt / requirements-test.txt"
echo " * commit changes to ${AI4_CODE_REPO_URL}"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
read -p "Press enter to continue"
echo ""
echo "[INFO] Replacing and checking old URLs in Dockerfile..."
$replace_old_urls Dockerfile
# backup Dockerfile
cp Dockerfile Dockerfile.bkp
echo ""
echo "[INFO] Removing old pyVer config..."
# delete old pyVer ARG
$search_and_replace Dockerfile "/ARG/ && /pyVer/"
sed -i "/# pyVer/d" Dockerfile
sed -i "s,\$pyVer,python3,gI" Dockerfile
# delete python3 link
$search_and_replace Dockerfile "/if/ && /python3/ && /then/" 0 5
echo ""
echo "[INFO] Updating default branch..."
sed -i "s,branch=$DEEP_CODE_REPO_BRANCH,branch=$AI4_CODE_REPO_BRANCH,gI" Dockerfile
echo ""
echo "[INFO] Removing old JupyterLab install..."
# delete old JupyterLab install
$search_and_replace Dockerfile "/ARG/ && /jlab/"
# delete old installation of Jupyterlab
$search_and_replace Dockerfile "/ENV/ && /JUPYTER_CONFIG_DIR/" 1 0
$search_and_replace Dockerfile "/RUN/ && /jlab/ && /true/" 0
echo ""
echo "[INFO] Removing ONEDATA installation..."
# delete old oneclient_ver ARG
$search_and_replace Dockerfile "/ARG/ && /oneclient_ver/" 1 0
# delete old oneclient installation
$search_and_replace Dockerfile "/RUN/ && /get.onedata.org/"
#$search_and_replace Dockerfile 2 4 '^(?=.*RUN)(?=.*jlab=)'
echo ""
echo "[INFO] Removing FLAAT installation via Dockerfile..."
$search_and_replace Dockerfile "/#/ && /FLAAT/" 1
echo ""
echo "[INFO] Replacing old install of deep-start..."
$search_and_replace Dockerfile "/RUN/ && /deep-start/" "" 2 ${SCRIPT_PATH}/tmpl-deep-start.docker
echo ""
echo "[INFO] Removing entries for ports...(will re-add later)"
$search_and_replace Dockerfile "/EXPOSE/ && /5000/" 1 0
$search_and_replace Dockerfile "/EXPOSE/ && /6000/" 1 0
$search_and_replace Dockerfile "/EXPOSE/ && /8888/" 1 0
echo ""
echo "[INFO] Re-add ports and Replacing old call for deepaas-run"
$search_and_replace Dockerfile "/CMD/ && /deepaas-run/" "" "" ${SCRIPT_PATH}/tmpl-ports-cmd.docker

load-nano Dockerfile

# find the name of "requirements.txt" file for tests
AI4_CODE_REPO_TEST_REQUIREMENTS="test-requirements.txt"
ls -1 |grep "requirements-test.txt"
[[ $? -eq 0 ]] && AI4_CODE_REPO_TEST_REQUIREMENTS="requirements-test.txt"

echo "[INFO] Getting list of pre-installed packages in the old Docker image"
DEEP_DOCKER_REPO=$(echo "deephdc/${DEEP_DOCKERFILE_REPO}" | awk '{print tolower($0)}')
DEEP_DOCKER_PIP_FREEZE=$(docker run --rm -ti "$DEEP_DOCKER_REPO" pip freeze)
echo "[INFO] Update requirements with relevant versions"
$update_reqs requirements.txt "${DEEP_DOCKER_PIP_FREEZE[*]}"
# allow to manually modify the requirements.txt file
load-nano requirements.txt

# allow to manually modify the (test-)requirements.txt file
load-nano $AI4_CODE_REPO_TEST_REQUIREMENTS

git commit -a -m "feat: migration-3, update Dockerfile, requirements(-test).txt files"
git push origin

# 5. Delete/Re-add Jenkinsfile
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "5. Re-create Jenkins CI/CD: "
echo " * re-create Jenkinsfile"
echo " * create .sqa/config.yml"
echo " * create .sqa/docker-compose.yml"
echo " * create JenkinsConstants.groovy"
echo " * re-create tox.ini"
echo " * commit changes to ${AI4_CODE_REPO_URL}"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
read -p "Press enter to continue"
# create Jenkinsfile from the template
cp ${SCRIPT_PATH}/cp-Jenkinsfile ./Jenkinsfile
# check for the base_cpu_tag
base_cpu_tag=$(cat ../${DEEP_DOCKERFILE_REPO}/Jenkinsfile |grep -i "base_cpu_tag" |head -n1 |tr -d ' ' |sed 's/"//g')
DOCKER_BASE_CPU_TAG=${base_cpu_tag#*=}
# check for the base_gpu_tag
base_gpu_tag=$(cat ../${DEEP_DOCKERFILE_REPO}/Jenkinsfile |grep -i "base_gpu_tag" |head -n1 |tr -d ' ' |sed 's/"//g')
DOCKER_BASE_GPU_TAG=${base_gpu_tag#*=}
# create JenkinsConstants.groovy from the template
sed -e "s,DOCKER_BASE_CPU_TAG,${DOCKER_BASE_CPU_TAG},g" \
    -e "s,DOCKER_BASE_GPU_TAG,${DOCKER_BASE_GPU_TAG},gI" \
    ${SCRIPT_PATH}/tmpl-JenkinsConstants.groovy > JenkinsConstants.groovy
# allow to manually modify the JenkinsConstants.groovy
load-nano JenkinsConstants.groovy

mkdir .sqa
# create .sqa/config.yml from the template
sed "s,AI4_CODE_REPO,${AI4_CODE_REPO},g" ${SCRIPT_PATH}/tmpl-sqa-config.yml > .sqa/config.yml
AI4_CICD_DOCKER_IMAGE="indigodatacloud/ci-images:python3.6"
echo "Please, provide CI/CD Image for the code testing, default is ${AI4_CICD_DOCKER_IMAGE}"
PS3='Please enter your choice: '
options=("indigodatacloud/ci-images:python3.6" "indigodatacloud/ci-images:python3.8" "indigodatacloud/ci-images:python3.10" "indigodatacloud/ci-images:python3.11" "Custom" "Use default")
select opt in "${options[@]}"
do
    case $opt in
        "indigodatacloud/ci-images:python3.6")
            AI4_CICD_DOCKER_IMAGE=$opt
            break
            ;;
        "indigodatacloud/ci-images:python3.8")
            AI4_CICD_DOCKER_IMAGE=$opt
            break
            ;;
        "indigodatacloud/ci-images:python3.10")
            AI4_CICD_DOCKER_IMAGE=$opt
            break
            ;;
        "indigodatacloud/ci-images:python3.11")
            AI4_CICD_DOCKER_IMAGE=$opt
            break
            ;;
        "Custom")
            read -p "Provide a custom CI/CD image (e.g. deephdc/ci_cd-obj_detect_pytorch): " AI4_CICD_DOCKER_IMAGE
            break
            ;;
        "Use default")
            break
            ;;
        *) echo "invalid option $REPLY";;
    esac
done
echo "[INFO] Configured CI/CD image for the code testing: ${AI4_CICD_DOCKER_IMAGE}"
# create .sqa/docker-compose.yml from the template
sed "s,AI4_CICD_DOCKER_IMAGE,${AI4_CICD_DOCKER_IMAGE},g" ${SCRIPT_PATH}/tmpl-sqa-docker-compose.yml > .sqa/docker-compose.yml
read -p "Do you want to recreate *tox.ini* file? (Y/N) " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
   # create tox.ini from the template
   # AI4_CODE_PYPKG is set above (stage 3)
   sed -e "s,AI4_CODE_REPO_TEST_REQUIREMENTS,${AI4_CODE_REPO_TEST_REQUIREMENTS},gI" \
       -e "s,AI4_CODE_PYPKG,${AI4_CODE_PYPKG},gI" ${SCRIPT_PATH}/tmpl-tox.ini > tox.ini
fi
# Delete: .stestr.conf as we don't use it anymore
git rm .stestr.conf

# Final check, if there is any mention of some old names anywhere
echo "#####################################################################################"
echo " Final checks if any mention of old names (deephdc, reponame, etc) remained anywhere "
echo " Searching in $PWD"
echo "#####################################################################################"
echo ""
grep_remains "deephdc"
echo ""
grep_remains $DEEP_CODE_REPO
echo ""
grep_remains "DEEP-OC"
echo ""

git add Jenkinsfile JenkinsConstants.groovy tox.ini .sqa/*
git commit -a -m "feat: migration-4, add Jenkins CI/CD with JePL2 (.sqa, tox.ini)"
git push origin

# 6. Try to build Docker image locally
AI4_DOCKER_REPO=$(echo "ai4oshub/${AI4_CODE_REPO}" | awk '{print tolower($0)}')
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
read -p "6. Do you want now try to build $AI4_DOCKER_REPO Docker image locally? (Y/N) " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
   docker build --no-cache -t $AI4_DOCKER_REPO .
fi

