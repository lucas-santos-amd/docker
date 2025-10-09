### Source config
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "${script_dir}/config.sh"

container_name="${IMAGE_NAME}"

docker stop "${container_name}"
docker rm "${container_name}"
docker rmi "${IMAGE_NAME}"
