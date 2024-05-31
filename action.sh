#!/bin/bash

function uri_wait(){
    set +e
    URL=$1
    SLEEP_INT=${2:-60}
    printf "Waiting for URI - ${URL} to be http-200 "
    for i in $(seq 1 ${SLEEP_INT}); do
        sleep 1
        printf .
        HTTP_CODE=$(curl -k -s -o /dev/null -I -w "%{http_code}" -H 'User-Agent: Mozilla/6.0' ${URL})
        [[ "${HTTP_CODE}" == "200" ]] && EXIT_CODE=0 || EXIT_CODE=-1
        [[ "${EXIT_CODE}" -eq 0 ]] && echo && return
    done
    echo
    set -e
    return ${EXIT_CODE}    
}

function sonar-start() {
    docker inspect ${SONAR_INSTANCE_NAME} 2>&1 > /dev/null 
    if [[ $? -ne 0 ]]; then
        docker run -d --name ${SONAR_INSTANCE_NAME} -p 9000:9000 sonarqube
    else
        docker start ${SONAR_INSTANCE_NAME} 2>&1 > /dev/null 
    fi

    # 1. Wait for services to be up
    uri_wait http://localhost:9000 60
    printf 'Waiting for sonarqube server to be up ' 
    for i in $(seq 1 180); do
        sleep 1
        printf .
        status_value=$(curl -s http://localhost:9000/api/system/status | jq -r '.status')

        # Check if the status value is "running"
        if [[ "$status_value" == "UP" ]]; then
            printf "\nSonarQube is running\n"
            break
        fi
    done

    # 2. Reset admin password to sonar
    curl -s -X POST -u "admin:admin" \
        -d "login=admin&previousPassword=admin&password=sonar" \
        http://localhost:9000/api/users/change_password
    echo "Local sonarqube URI: http://localhost:9000" 

    # 3. Create default project and set default fav
    curl -s -u "admin:sonar" -X POST "http://localhost:9000/api/projects/create?name=${SONAR_PROJECT_NAME}&project=${SONAR_PROJECT_NAME}" | jq
    curl -s -u "admin:sonar" -X POST "http://localhost:9000/api/users/set_homepage?type=PROJECT&component=${SONAR_PROJECT_NAME}"
    echo "Credentials: admin/sonar"

}

function sonar-scan() {
    # 1. Get internal IP for Sonar-Server
    export DOCKER_SONAR_IP=$(docker inspect ${SONAR_INSTANCE_NAME} | jq -r '.[].NetworkSettings.IPAddress')

    echo "SONAR_SOURCES: ${SONAR_SOURCES}"
    echo "SONAR_SOURCE_PATH: ${SONAR_SOURCE_PATH}"

    # 2. Create token and scan
    export SONAR_TOKEN=$(curl -s -X POST -u "admin:sonar" "http://${DOCKER_SONAR_IP}:9000/api/user_tokens/generate?name=$(date +%s%N)" | jq -r .token)
    docker run --rm \
        -e SONAR_HOST_URL="http://${DOCKER_SONAR_IP}:9000"  \
        -e SONAR_TOKEN=${SONAR_TOKEN} \
        -e SONAR_SCANNER_OPTS="-Dsonar.projectKey=${SONAR_PROJECT_NAME} -Dsonar.sources=${SONAR_SOURCE_PATH}" \
        -v "${SONAR_SOURCES}:/usr/src" \
        sonarsource/sonar-scanner-cli

    # 3. Wait for scanning to be done
    printf '\nWaiting for analysis ' 
    for i in $(seq 1 120); do
        sleep 1
        printf .
        status_value=$(curl -s -u "admin:sonar" http://${DOCKER_SONAR_IP}:9000/api/qualitygates/project_status?projectKey=${SONAR_PROJECT_NAME} | jq -r .projectStatus.status)
        # Checking if the status value is not "NONE"
        if [[ "$status_value" != "NONE" ]]; then
            printf "\nSonarQube scanning done\n"
            printf "Use webui or 'make sonar-results' to get scan outputs\n"
            break
        fi
    done
}

function sonar-results() {
    # use this params to collect stats
    curl -s -u "admin:sonar" "http://localhost:9000/api/measures/component?component=${SONAR_PROJECT_NAME}&metricKeys=bugs,vulnerabilities,code_smells,quality_gate_details,violations,duplicated_lines_density,ncloc,coverage,reliability_rating,security_rating,security_review_rating,sqale_rating,security_hotspots,open_issues" | jq -r > sonar-results.json
    cat sonar-results.json
}

$*