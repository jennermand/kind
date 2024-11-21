
# Find container-ID for KIND-clusteret
$CONTAINER_ID = docker ps -q --filter "name=kind-control-plane"

Write-Host "Container-ID: $CONTAINER_ID"

# Create the folder inside the container
docker exec -it $CONTAINER_ID bash -c "mkdir -p /var/log/mylogs"

# Create a Docker volume
docker volume create mylogs_volume
$PWD = pwd
# Mount the volume to the created folder in the container
docker run  -v mylogs_volume/logs:/var/log/mylogs -it $CONTAINER_ID busybox 

