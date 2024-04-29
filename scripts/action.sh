#!/bin/bash

function uri_wait(){
    set +e
    URL=$1
    SLEEP_INT=${2:-60}
    printf "Waiting for URI:${URL} to be http-200 "
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

function hello-world() {
    echo "Hello ${INPUT_NAME}"
    docker ps -a
}

$*