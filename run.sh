#!/bin/bash

### Source config
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "${script_dir}/config.sh"

### Set container name
container_name="${IMAGE_NAME}"
container_name_suffix=${1}

if [ -n "${container_name_suffix}" ]; then
    container_name="${container_name}_${container_name_suffix}"
fi

mkdir ${HOME}/triton/ 2>/dev/null
mkdir ${HOME}/aiter/ 2>/dev/null
# Remove older files
rm -rf ${HOME}/triton/{*,.*} 2>/dev/null
rm -rf ${HOME}/aiter/{*,.*} 2>/dev/null

### Run after mount
# Move files to mounted folders and delete the temp ones
bash_command="mv /triton_dev/triton_default/{*,.*} /triton_dev/triton/ 2>/dev/null; "
bash_command+="mv /triton_dev/aiter_default/{*,.*} /triton_dev/aiter/ 2>/dev/null; "
bash_command+="rm -rf /triton_dev/triton_default/ 2>/dev/null; "
bash_command+="rm -rf /triton_dev/aiter_default/ 2>/dev/null; "
# Install AITER and change ownership
bash_command+="cd /triton_dev/aiter && python setup.py develop && cd /triton_dev; " 
bash_command+="chown -R ${USER_NAME}:${GROUP_ID} /triton_dev/aiter; "
# Keep running
bash_command+="bash"

docker run \
    -it \
    -d \
    --network host \
    --ipc host \
    --name "${container_name}" \
    --device /dev/kfd \
    --device /dev/dri \
    --security-opt seccomp=unconfined \
    --cap-add SYS_PTRACE \
    --group-add video \
    --shm-size=16G \
    --ulimit memlock=-1 \
    --ulimit stack=67108864 \
    --mount "type=bind,source=${HOME},target=/triton_dev/hhome" \
    --mount "type=bind,source=${HOME}/triton,target=/triton_dev/triton" \
    --mount "type=bind,source=${HOME}/aiter,target=/triton_dev/aiter" \
    --mount "type=bind,source=${HOME}/.ssh,target=/root/.ssh,readonly" \
    "${IMAGE_NAME}" -c "${bash_command}"

 