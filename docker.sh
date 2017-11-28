#!/bin/bash

DO_BUILD=1
DO_RUN=1

# this is for when we run without the "--net" option.
# Nginx doens't like it when it can't reach the launcher-backend
# and will fail to start. So we add a hosts entry of our own
# pointing to the docker host
DOCKER_HOST=$(ip -4 addr show docker0 | grep -Po 'inet \K[\d.]+')
EXTRA_OPTS="--add-host launcher-backend:$DOCKER_HOST"

# see if a "--net" option was passed, if so we'll connect the
# container to a private network (creating it if necessary)
NETWORK=default
DRUN_OPTS=""
for arg; do
    case $arg in
        --net)  NETWORK=launchernw
                # create a docker network for our app if it doesn't exist
                if ! docker network ls | grep -q $NETWORK; then docker network create $NETWORK; fi
                # override the connection URLs for the application
                LAUNCHPAD_BACKEND_URL=http://localhost:8088/launch/api
                LAUNCHPAD_MISSIONCONTROL_URL=ws://localhost:8088/launch
                EXTRA_OPTS=""
                ;;
        --build) DO_RUN=0
                ;;
        --run) DO_BUILD=0
                ;;
        --help) echo "Usage: docker.sh [options]"
                echo ""
                echo "Builds and runs this project's Docker image"
                echo ""
                echo "Options:"
                echo "   --build  : Only build the Docker image"
                echo "   --run    : Only run the Docker image"
                echo "   --net    : When run the Docker image will be attached to a private network"
                echo "   --help   : This help"
                echo ""
                echo "For all other available options see 'docker run --help'"
                exit
                ;;
        *)  DRUN_OPTS="$DRUN_OPTS ${arg}"
                ;;
    esac
done

if [[ $DO_BUILD -eq 1 ]]; then
	# remove any pre-existing image
	docker rm -f launcher-frontend >/dev/null 2>&1

	# build the image
	echo "Building image..."
	docker build -q -t fabric8/launcher-frontend -f Dockerfile.deploy .
fi

if [[ $DO_RUN -eq 1 ]]; then
	# run it
	echo "Running image..."
	docker run \
		--name launcher-frontend \
		--network $NETWORK \
		-t \
		-p8088:8080 \
		-eLAUNCHPAD_KEYCLOAK_URL=$LAUNCHPAD_KEYCLOAK_URL \
		-eLAUNCHPAD_KEYCLOAK_REALM=$LAUNCHPAD_KEYCLOAK_REALM \
		-eLAUNCHPAD_BACKEND_URL=$LAUNCHPAD_BACKEND_URL \
		-eLAUNCHPAD_MISSIONCONTROL_URL=$LAUNCHPAD_MISSIONCONTROL_URL \
		-eLAUNCHPAD_TRACKER_SEGMENT_TOKEN=$LAUNCHPAD_TRACKER_SEGMENT_TOKEN \
		$DRUN_OPTS \
		$EXTRA_OPTS \
		fabric8/launcher-frontend
fi
