#!/usr/bin/env bash
LOCATION=europe-west1
SERVICE_NAME=cloudops-logging-google
PROJECT_ID='manucalop'
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='get(projectNumber)')
REPOSITORY_NAME="docker-repository"
ROOT_PATH="${LOCATION}-docker.pkg.dev"
IMAGE_NAME="${SERVICE_NAME}"
IMAGE_FULL_PATH="${ROOT_PATH}/${PROJECT_ID}/${REPOSITORY_NAME}/${IMAGE_NAME}"
SERVICE_ACCOUNT=cloudops-logging-google-service-account
SCHEDULER_SERVICE_ACCOUNT=scheduler-service-account
PORT=5000   

function setup() {
  echo "Setting up project to ${PROJECT_ID}..."
  gcloud config set project ${PROJECT_ID}

  echo "Setting up location to ${LOCATION}..."
  gcloud config set run/region ${LOCATION}
}

setup

function create_artifact_repository(){
    echo "Creating artifact repository ${REPOSITORY_NAME}..."
    gcloud artifacts repositories create ${REPOSITORY_NAME} \
        --repository-format=docker \
        --location=${LOCATION} \
        --project=${PROJECT_ID}
}

function create_etl_service_account(){
    echo "Creating service account ${SERVICE_ACCOUNT}..."
    gcloud iam service-accounts create ${SERVICE_ACCOUNT} \
        --display-name="ETL Service Account" \
        --project=${PROJECT_ID}

    echo "Adding permissions to service account ${SERVICE_ACCOUNT}..."
    gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member serviceAccount:${SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com \
        --role roles/bigquery.admin

    gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member serviceAccount:${SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com \
        --role roles/secretmanager.admin

    gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member serviceAccount:${SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com \
        --role roles/pubsub.publisher

    gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member serviceAccount:${SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com \
        --role roles/pubsub.subscriber

    gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member serviceAccount:${SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com \
        --role roles/errorreporting.writer
}


function docker_build_gcp(){
    echo "Building docker image on ${IMAGE_FULL_PATH}..."
    gcloud builds submit --tag ${IMAGE_FULL_PATH} .
    
}

# Test docker image locally
##############################################################################################
function setup_docker_auth(){
    gcloud auth configure-docker gcr.io
    gcloud auth configure-docker ${ROOT_PATH}
}

function docker_delete(){
    docker kill ${SERVICE_NAME}
    docker rm -f ${SERVICE_NAME}
}

function docker_build(){
    echo "Building docker image"
    docker image build -t ${SERVICE_NAME} .
}

function docker_run(){
    docker_build
    echo "Running docker image"
    docker run -p ${PORT}:${PORT} --name ${SERVICE_NAME} -t ${SERVICE_NAME}
    docker rm -f ${SERVICE_NAME}
}
##############################################################################################

function docker_deploy(){
    docker_build
    echo "Deploying docker image"

    # Tag image
    docker tag "${SERVICE_NAME}:latest" "${IMAGE_FULL_PATH}:latest"

    docker push "${IMAGE_FULL_PATH}:latest"

    gcloud run deploy ${SERVICE_NAME} \
        --image ${IMAGE_FULL_PATH}:latest \
        --service-account ${SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com \
        --region ${LOCATION} \
        --port ${PORT} \
        --no-allow-unauthenticated
    SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} --format='value(status.address.url)')
}

function setup_scheduler_service_account(){
    echo "Setting up scheduler"

    gcloud services enable cloudscheduler.googleapis.com

    gcloud iam service-accounts create ${SCHEDULER_SERVICE_ACCOUNT} \
       --display-name "Scheduler Service Account" \
       --project=${PROJECT_ID}

    gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member serviceAccount:${SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com \
        --role roles/run.invoker

    # Give cloud run invoker role to the scheduler service account
    # gcloud run services add-iam-policy-binding ${SERVICE_NAME} \
    #    --member serviceAccount:${SCHEDULER_SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com \
    #    --role=roles/run.invoker
}

function create_scheduler(){
    echo "Creating cloud scheduler"

    gcloud scheduler jobs create http ${SERVICE_NAME}-job \
        --schedule "0 5 * * *" \
        --http-method=GET \
        --uri=${SERVICE_URL} \
        --oidc-service-account-email=${SCHEDULER_SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com \
        --oidc-token-audience=${SERVICE_URL} \
        --location=${LOCATION}
}

function run_cloud_scheduler(){
    echo "Running cloud scheduler"
    gcloud scheduler jobs run ${SERVICE_NAME}-job
}
