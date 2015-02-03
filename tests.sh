#!/bin/bash

set -e

echo "Started."

function use_docker() {
	if [[ "$TEST_DOCKER" == "true" ]]; then
		if docker info > /dev/null 2>&1; then
			return 0
		else
			echo "Error: Docker not available (do you have non-root access?). Not using Docker."
		fi
	fi
	return 1
}

function finally() {
	echo "Cleaning up..."
	if use_docker; then
		docker rm -f gamocosm_container || echo "No Docker Gamocosm container to delete (this is ok)."
		echo "Your Docker images:"
		docker images
		echo "You can delete them with 'docker rmi IMAGE'"
		echo "You can delete all untagged images with 'docker rmi \$(docker images --filter \"dangling=true\" -q)'"
	fi
	echo "Done."
}
trap finally exit

source env.sh

if use_docker; then
	echo "Preparing Docker image and container..."
	pushd test-docker
	rm -f id_rsa
	rm -f id_rsa.pub
	cp "$DIGITAL_OCEAN_SSH_PRIVATE_KEY_PATH" id_rsa
	cp "$DIGITAL_OCEAN_SSH_PUBLIC_KEY_PATH" id_rsa.pub
	docker build -t gamocosm .
	docker run -d -p 22:22 -p 4022:4022 -p 5000:5000 -p 25565:25565/udp --name gamocosm_container gamocosm
	popd
	echo "Docker Gamocosm container running."
fi

echo "Starting tests..."
bundle exec rake test
echo "Done tests."
