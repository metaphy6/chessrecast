# Remove all unused volumes
docker volume prune

# Remove all unused volumes without confirmation
docker volume prune -f

# Remove all unused volumes and show reclaimed space
docker volume prune -a

# Force remove all unused volumes
docker volume prune -af

# List all volumes
docker volume ls

# List only dangling volumes (unused)
docker volume ls -f dangling=true

# Remove a specific volume
docker volume rm volume_name

# Remove multiple volumes
docker volume rm volume1 volume2 volume3

# Remove all volumes (WARNING: destructive)
docker volume prune -a -f

# Check volume details
docker volume inspect volume_name

# Remove volumes associated with stopped containers
docker container prune -f  # This removes stopped containers first, then volumes can be pruned