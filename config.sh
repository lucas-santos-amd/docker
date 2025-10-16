#!/bin/bash

### User information:
export USER_REAL_NAME='Lucas Santos'
export USER_EMAIL='Lucas.Santos@amd.com'

USER_ID=$(id --user)
export USER_ID
USER_NAME=$(id --user --name)
export USER_NAME
GROUP_ID=$(id --group)
export GROUP_ID
GROUP_NAME=$(id --group --name)
export GROUP_NAME

### Image / container information:
export TRITON_DEV_NAME='triton_dev_rocm7.0'
export IMAGE_NAME="${USER_NAME}_${TRITON_DEV_NAME}"
