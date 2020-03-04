#!/bin/bash
#Script Vars:
#---------------------
REPONAME="caas.lbgsandbox.com:8500/poc0154-dev-ns"
IMAGENAME="csppush"
IMG="openjdk"
TAG="11-jre-slim"
ENV="sandbox"

TAGVERSION=$1
template="kubes/push.templ"
#--------------------
#check pre-reqs
if [ "$1" == "" ]; then
    echo "Need a Version number"
    exit 1
fi
if [ -d "build" ]; then
    rm -rf build
fi
# Functions
checkExitCode() {
  if [ $? -eq 0 ]
  then
    echo "$1"
    else
    echo "$2"
    exit 1
  fi
}

gradle --version > /dev/null 2>&1
checkExitCode \
  "Gradle Installed" \
  "Gradle not installed, run 'brew install gradle' and restart script"

docker --version > /dev/null 2>&1
checkExitCode \
  "Docker Installed" \
  "Docker not installed, install Docker Desktop and restart script"

#Run Gradle test and proceed of passed
echo "Running Gradle Tests"
gradle test  > /dev/null 2>&1
checkExitCode \
  "Gradle tests passed" \
  "Gradle Tests failed"

# Build Version of Application with version number given
gradle build -x test #run build without tests
# Build Dockerfile for CSPPush with version & application that was just built.
docker build -t $REPONAME/$IMAGENAME:$1 --build-arg IMG=$IMG --build-arg TAG=$TAG --build-arg JAR_FILE=/build/libs/fpr-kafka-xfer.jar .
checkExitCode \
  "Docker Build passed" \
  "Docker Build failed"
# Upload to Docker Repo
#docker login #only used for external Docker
docker push $REPONAME/$IMAGENAME:$1
# Deploy into Kubernetes
eval "echo \"$(cat "${template}")\"" > kubes/csppush.yaml
cat kubes/env_sandbox.templ >> kubes/csppush.yaml
helm upgrade --install --values values-$ENV.yaml --namespace poc0154-dev-ns csp-push charts/csp-push/.