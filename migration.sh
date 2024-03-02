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

# function to replace standard old URL
function replace-old-urls()
{
   sed -i -e "s,${DEEP_DEEPAAS_REPO_URL},${AI4_DEEPAAS_REPO_URL},gI" \
   -e "s,${DEEP_DOCKERFILE_REPO_URL},${AI4_CODE_REPO_URL},gI" \
   -e "s,deephdc/${DEEP_DOCKERFILE_REPO},ai4oshub/${AI4_CODE_REPO},gI" \
   -e "s,${DEEP_CODE_REPO_URL},${AI4_CODE_REPO_URL},gI" \
   -e "s,${DEEP_DOCKERFILE_REPO_JENKINS_BADGE},${AI4_CODE_REPO_JENKINS_BADGE},gI" \
   -e "s,${DEEP_DOCKERFILE_REPO_JENKINS_URL},${AI4_CODE_REPO_JENKINS_URL},gI" \
   -e "s,${DEEP_CODE_REPO_JENKINS_BADGE},${AI4_CODE_REPO_JENKINS_BADGE},gI" \
   -e "s,${DEEP_CODE_REPO_JENKINS_URL},${AI4_CODE_REPO_JENKINS_URL},gI" $1
}

# function to check for any mention of nc.deep-hybrid-datacloud.eu
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
    read -p "Press enter to continue"
  fi
  return $found # 0 - found, 1 - not found
}

# 1. Configure repo URLs, retrieve names of defaults branches
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "1. Configure Repos: configure old (deephdc) and new (ai4os) repos URLs   "
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
read -p "Press enter to continue"

read -p "deephdc code repo (e.g. demo_app): " DEEP_CODE_REPO
DEEP_CODE_REPO_URL=${DEEP_GITHUB_ORG}${DEEP_CODE_REPO}
DEEP_CODE_REPO_URL="${DEEP_CODE_REPO_URL%/}"  # strip trailing slash (if any)
check-url ${DEEP_CODE_REPO_URL}
DEEP_CODE_REPO_BRANCH=$(get-branch ${DEEP_CODE_REPO_URL})
echo "Found Default Branch: ${DEEP_CODE_REPO_BRANCH}"

echo ""
read -p "deephdc Dockerfile repo (usually has 'DEEP-OC' in the name, e.g. DEEP-OC-demo_app): " DEEP_DOCKERFILE_REPO
DEEP_DOCKERFILE_REPO_URL=${DEEP_GITHUB_ORG}${DEEP_DOCKERFILE_REPO}
DEEP_DOCKERFILE_REPO_URL="${DEEP_DOCKERFILE_REPO_URL%/}"  # strip trailing slash (if any)
check-url ${DEEP_DOCKERFILE_REPO_URL}
DEEP_DOCKERFILE_REPO_BRANCH=$(get-branch ${DEEP_DOCKERFILE_REPO_URL})
echo "Found Default Branch: ${DEEP_DOCKERFILE_REPO_BRANCH}"

echo ""
read -p "(new) ai4os-hub code repo (has to be created first, empty! e.g. ai4os-demo-app): " AI4_CODE_REPO
AI4_CODE_REPO_URL=${AI4_GITHUB_ORG}${AI4_CODE_REPO}
AI4_CODE_REPO_URL="${AI4_CODE_REPO_URL%/}"  # strip trailing slash (if any)
check-url ${AI4_CODE_REPO_URL}
AI4_CODE_REPO_BRANCH=${DEEP_CODE_REPO_BRANCH}
read -p "Do you want to rename default branch (${DEEP_CODE_REPO_BRANCH})? (e.g. to 'main')? (Y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]
then
   read -p "Please, give new name of the default branch: " AI4_CODE_REPO_BRANCH
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
DEEP_DEEPAAS_REPO_URL="https://github.com/indigo-dc/DEEPaaS"
DEEP_DOCKERFILE_REPO_JENKINS_BADGE="https://jenkins.indigo-datacloud.eu/buildStatus/icon?job=Pipeline-as-code/DEEP-OC-org/${DEEP_DOCKERFILE_REPO}/${DEEP_DOCKERFILE_REPO_BRANCH}"
DEEP_DOCKERFILE_REPO_JENKINS_URL="https://jenkins.indigo-datacloud.eu/job/Pipeline-as-code/job/DEEP-OC-org/job/${DEEP_DOCKERFILE_REPO}/job/${DEEP_DOCKERFILE_REPO_BRANCH}"
DEEP_CODE_REPO_JENKINS_BADGE="https://jenkins.indigo-datacloud.eu/buildStatus/icon?job=Pipeline-as-code/DEEP-OC-org/${DEEP_CODE_REPO}/${DEEP_CODE_REPO_BRANCH}"
DEEP_CODE_REPO_JENKINS_URL="https://jenkins.indigo-datacloud.eu/job/Pipeline-as-code/job/DEEP-OC-org/job/${DEEP_CODE_REPO}/job/${DEEP_CODE_REPO_BRANCH}"
AI4_DEEPAAS_REPO_URL="https://github.com/ai4os/DEEPaaS"
AI4_CODE_REPO_JENKINS_BADGE="https://jenkins.services.ai4os.eu/buildStatus/icon?job=AI4OS-hub/${AI4_CODE_REPO}/${AI4_CODE_REPO_BRANCH}"
AI4_CODE_REPO_JENKINS_URL="https://jenkins.services.ai4os.eu/job/AI4OS-hub/job/${AI4_CODE_REPO}/job/${AI4_CODE_REPO_BRANCH}/"

replace-old-urls metadata.json
check-old-nc metadata.json

sed -i "s,http://github.com,https://github.com,gI" setup.cfg  # in case "http://" is wrongly given for github.com
replace-old-urls setup.cfg
sed -i "s,%2F,/,gI" README.md # replace "%2F" code with "/"
replace-old-urls README.md
check-old-nc README.md

git commit -a -m "feat: migration-2, Update files for AI4OS URL values"

# 4. Update Dockerfile, requirements, and test-requirements. MOSTLY MANUAL PROCESS!
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "4. PRETTY MUCH MANUAL PROCESS to Update: "
echo " * Dockerfile"
echo " * requirements.txt"
echo " * test-requirements.txt / requirements-test.txt"
echo " * commit changes to ${AI4_CODE_REPO_URL}"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
read -p "Press enter to continue"

replace-old-urls Dockerfile
check-old-nc Dockerfile
# find the name of "requirements.txt" file for tests
AI4_CODE_REPO_TEST_REQUIREMENTS="test-requirements.txt"
ls -1 |grep "requirements-test.txt"
[[ $? -eq 0 ]] && AI4_CODE_REPO_TEST_REQUIREMENTS="requirements-test.txt"
# ...........
# ...........
# ...........

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
export $(cat ../${DEEP_DOCKERFILE_REPO}/Jenkinsfile |grep -i "base_cpu_tag" |head -n1 |tr -d ' ' |sed 's/"//g')
# check for the base_gpu_tag
export $(cat ../${DEEP_DOCKERFILE_REPO}/Jenkinsfile |grep -i "base_gpu_tag" |head -n1 |tr -d ' ' |sed 's/"//g')
# create JenkinsConstants.groovy from the template
sed -e "s,DOCKER_BASE_CPU_TAG,${base_cpu_tag},g" \
    -e "s,DOCKER_BASE_GPU_TAG,${base_gpu_tag},gI" \
    ${SCRIPT_PATH}/tmpl-JenkinsConstants.groovy > JenkinsConstants.groovy
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
# create tox.ini from the template
sed -e "s,AI4_CODE_REPO_TEST_REQUIREMENTS,${AI4_CODE_REPO_TEST_REQUIREMENTS},gI" \
    -e "s,AI4_CODE_REPO,${AI4_CODE_REPO},gI" ${SCRIPT_PATH}/tmpl-tox.ini > tox.ini
# Delete: .stestr.conf as we don't use it anymore
git rm .stestr.conf
git add Jenkinsfile JenkinsConstants.groovy tox.ini .sqa/*
git commit -a -m "feat: migration-4, add Jenkins CI/CD with JePL2 (.sqa, tox.ini)"
git push origin

