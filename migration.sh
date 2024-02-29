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

# Configure repo URLs
read -p "deephdc code repo (e.g. demo_app): " DEEP_CODE_REPO
DEEP_CODE_REPO_URL=${DEEP_GITHUB_ORG}${DEEP_CODE_REPO}
check-url ${DEEP_CODE_REPO_URL}
echo ""
read -p "deephdc Dockerfile repo (usually contains DEEP-OC, e.g. DEEP-OC-demo_app): " DEEP_DOCKERFILE_REPO
DEEP_DOCKERFILE_REPO_URL=${DEEP_GITHUB_ORG}${DEEP_DOCKERFILE_REPO}
check-url ${DEEP_DOCKERFILE_REPO_URL}
echo ""
read -p "new ai4os-hub code repo (has to be created first, empty! e.g. ai4os-demo-app): " AI4_CODE_REPO
AI4_CODE_REPO_URL=${AI4_GITHUB_ORG}${AI4_CODE_REPO}
check-url ${AI4_CODE_REPO_URL}

# Clone old repo
echo ""
echo "[INFO] We bare clone now $DEEP_CODE_REPO_URL"
git clone --bare $DEEP_CODE_REPO_URL
# go into cloned repo
cd ${DEEP_CODE_REPO}.git
echo "[INFO] Pushing now this repo to $AI4_CODE_REPO_URL"
git push --mirror $AI4_CODE_REPO_URL
cd ..
read -p "Delete now local directory ${DEEP_CODE_REPO}.git (advised)? (Y/N)" -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
   rm -rf ${DEEP_CODE_REPO}.git
fi

echo ""
echo "[INFO] We clone now ${DEEP_DOCKERFILE_REPO_URL}"
git clone ${DEEP_DOCKERFILE_REPO_URL}
echo "... and "
git clone ${AI4_CODE_REPO_URL}
cd ${AI4_CODE_REPO}
echo "[INFO] Copy now original Dockerfile, metadata.json from ../${DEEP_DOCKERFILE_REPO}"
cp ../${DEEP_DOCKERFILE_REPO}/Dockerfile ./
cp ../${DEEP_DOCKERFILE_REPO}/metadata.json ./
mkdir docker
touch docker/.gitkeep
git add Dockerfile metadata.json docker/*
git commit -a -m "feat: migration-1, Add original Dockerfile, metadata.json"
echo "[INFO] Added original Dockerfile, metadata.json, now pushing changes to ai4os-hub/"
git push origin

