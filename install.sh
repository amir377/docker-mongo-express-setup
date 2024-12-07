#!/bin/bash

# Function to prompt user for input with a default value
prompt_user() {
    local prompt_text="$1"
    local default_value="$2"
    read -p "$prompt_text (Default: $default_value): " input
    echo "${input:-$default_value}"
}

# Prompt user for Mongo Express setup details
container_name=$(prompt_user "Enter the container name" "mongo-express")
network_name=$(prompt_user "Enter the network name" "general")
mongo_express_port=$(prompt_user "Enter the Mongo Express port" "8081")
mongodb_server=$(prompt_user "Enter the MongoDB server name" "mongodb")
admin_username=$(prompt_user "Enter the MongoDB admin username" "admin")
admin_password=$(prompt_user "Enter the MongoDB admin password" "admin123")
basic_auth_username=$(prompt_user "Enter the Mongo Express basic auth username" "user")
basic_auth_password=$(prompt_user "Enter the Mongo Express basic auth password" "pass")
allow_host=$(prompt_user "Enter the allowed host" "0.0.0.0")

# Generate the .env file
echo "Creating .env file for Mongo Express setup..."
cat > .env <<EOL
# Mongo Express container settings
CONTAINER_NAME=$container_name
NETWORK_NAME=$network_name
MONGO_EXPRESS_PORT=$mongo_express_port
ALLOW_HOST=$allow_host

# MongoDB credentials
ME_CONFIG_MONGODB_ADMINUSERNAME=$admin_username
ME_CONFIG_MONGODB_ADMINPASSWORD=$admin_password
ME_CONFIG_MONGODB_SERVER=$mongodb_server
ME_CONFIG_BASICAUTH_USERNAME=$basic_auth_username
ME_CONFIG_BASICAUTH_PASSWORD=$basic_auth_password
EOL

echo ".env file created successfully."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker and try again."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose is not installed. Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "Docker Compose installed successfully."
fi

# Create the network before building the container
echo "Creating Docker network $network_name if it does not already exist..."
docker network create $network_name || echo "Network $network_name already exists. Skipping creation."

# Use docker-compose.example.yaml to create docker-compose.yaml
echo "Generating docker-compose.yaml file from docker-compose.example.yaml..."
if [ -f "docker-compose.example.yaml" ]; then
    sed -e "s/\${CONTAINER_NAME}/$container_name/g" \
        -e "s/\${NETWORK_NAME}/$network_name/g" \
        -e "s/\${MONGO_EXPRESS_PORT}/$mongo_express_port/g" \
        -e "s/\${ALLOW_HOST}/$allow_host/g" \
        -e "s/\${ME_CONFIG_MONGODB_ADMINUSERNAME}/$admin_username/g" \
        -e "s/\${ME_CONFIG_MONGODB_ADMINPASSWORD}/$admin_password/g" \
        -e "s/\${ME_CONFIG_MONGODB_SERVER}/$mongodb_server/g" \
        -e "s/\${ME_CONFIG_BASICAUTH_USERNAME}/$basic_auth_username/g" \
        -e "s/\${ME_CONFIG_BASICAUTH_PASSWORD}/$basic_auth_password/g" \
        docker-compose.example.yaml > docker-compose.yaml
    echo "docker-compose.yaml file created successfully."
else
    echo "docker-compose.example.yaml file not found. Please ensure it exists in the current directory."
    exit 1
fi

# Start Docker Compose with build
echo "Starting Docker Compose with --build for Mongo Express..."
if docker-compose up -d --build; then
    echo "Checking container status..."
    if [ "$(docker inspect -f '{{.State.Running}}' $container_name)" = "true" ]; then
        echo "Mongo Express setup is complete and running on port $mongo_express_port."
    else
        echo "Container is not running. Fetching logs..."
        docker logs $container_name
    fi
else
    echo "Failed to start Docker Compose. Ensure Docker is running and try again."
    exit 1
fi
