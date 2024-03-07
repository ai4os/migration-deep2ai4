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

# call the function
# example: replace-old-urls README.md
replace-old-urls $1
