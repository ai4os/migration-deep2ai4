#!/usr/bin/env bash

# Quick and dirty move of images from deephdc to ai4oshub
# Script is based on https://forums.docker.com/t/how-to-move-existing-repository-to-an-organisation/123682

OLDHUB="deephdc"
NEWHUB="ai4oshub"

# !! CAREFUL! Positon in OLDREPOS and NEWREPOS have to correspond to each other! !!
# e.g. "deep-oc-yolov8_api" => "ai4os-yolov8-api"
#OLDREPOS=(
#"deep-oc-audio-classification-tf"
#"deep-oc-birds-audio-classification-tf"
#"deep-oc-conus-classification-tf"
#"deep-oc-image-classification-tf"
#"deep-oc-image-classification-tf-dicom"
#"deep-oc-phytoplankton-classification-tf"
#"deep-oc-seeds-classification-tf"
#"deep-oc-speech-to-text-tf"
#"deep-oc-fasterrcnn_pytorch_api"
#"deep-oc-mods"
#"deep-oc-neural_transfer"
#"deep-oc-retinopathy_test"
#"deep-oc-satsr"
#"deep-oc-semseg_vaihingen"
#"deep-oc-yolov8_api"
#)

#NEWREPOS=(
#"ai4os-audio-classification-tf"
#"birds-audio-classification-tf"
#"conus-classification-tf"
#"ai4os-image-classification-tf"
#"chest-xray-classification"
#"phytoplankton-classification-tf"
#"seeds-classification-tf"
#"ai4os-speech-to-text-tf"
#"ai4os-fasterrcnn-pytorch-api"
#"uc-mods"
#"neural-transfer"
#"uc-retinopathy_test"
#"uc-satsr"
#"uc-semseg_vaihingen"
#"ai4os-yolov8-api"
#)

OLDREPOS=(
"tensorflow:1.12.0-py36"
"tensorflow:1.12.0-gpu-py36"
"tensorflow:1.10.0-py36"
"tensorflow:1.10.0-gpu-py36"
)

NEWREPOS=(
"tensorflow"
"tensorflow"
"tensorflow"
"tensorflow"
)

array_size=${#OLDREPOS[@]}
for (( i=0; i<$array_size; i++ )); do 
   echo "${NEWREPOS[$i]}"
   OLD_REPO="$OLDHUB/${OLDREPOS[$i]}"
   NEW_REPO="$NEWHUB/${NEWREPOS[$i]}"
   docker pull $OLD_REPO
#   docker pull $OLD_REPO:cpu
#   docker pull $OLD_REPO:gpu
   docker image ls $OLD_REPO --format '{{ .Repository }}:{{ .Tag }} {{ .Repository }}:{{ .Tag }}' | sed "s# .*:# $NEW_REPO:#" | xargs -L 1 -- docker tag
   docker push $NEW_REPO --all-tags
   docker rmi $OLD_REPO
#   docker rmi $OLD_REPO:cpu
#   docker rmi $OLD_REPO:gpu
   docker rmi $NEW_REPO
#   docker rmi $NEW_REPO:cpu
#   docker rmi $NEW_REPO:gpu
done

