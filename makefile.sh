#!/bin/bash

export SONAR_INSTANCE_NAME=${SONAR_INSTANCE_NAME:-"sonar-server"}
export SONAR_PROJECT_NAME=${SONAR_PROJECT_NAME:-"$(basename `pwd`)"}
export SONAR_PROJECT_KEY=${SONAR_PROJECT_KEY:-"$(basename `pwd`)"}
export SONAR_GITROOT=${SONAR_GITROOT:-"$(pwd)"}
export SONAR_SOURCE_PATH=${SONAR_SOURCE_PATH:-"."}
export SONAR_METRICS_PATH=${SONAR_METRICS_PATH:-"./sonar-metrics.json"}

export DOCKER_SONAR_CLI=sonarsource/sonar-scanner-cli
export DOCKER_SONAR_SERVER=sonarqube

export CLI_NAME="sonarless"

function uri_wait(){
    set +e
    URL=$1
    SLEEP_INT=${2:-60}
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

function help() {
    echo ''
    echo '                                               _ '                
    echo '               ___   ___   _ __    __ _  _ __ | |  ___  ___  ___ '
    echo '              / __| / _ \ | "_ \  / _` || "__|| | / _ \/ __|/ __| '
    echo '              \__ \| (_) || | | || (_| || |   | ||  __/\__ \\__ \ '
    echo '              |___/ \___/ |_| |_| \__,_||_|   |_| \___||___/|___/ '
    echo ''
    echo ''
    echo "${CLI_NAME} help        : this help menu"
    echo ''
    echo "${CLI_NAME} scan        : to scan all code in current directory. Sonarqube Service will be started"
    echo "${CLI_NAME} results     : show scan results and download the metric json (sonar-metrics.json) in current directory"
    echo ''
    echo "${CLI_NAME} start       : start SonarQube Service docker instance with creds: admin/sonarless"
    echo "${CLI_NAME} stop        : stop SonarQube Service docker instance"
    echo ''
    echo "${CLI_NAME} uninstall   : uninstall all scriptlets and docker instances"
    echo "${CLI_NAME} docker-clean: remove all docker instances. Note any scan history will be lost as docker instance are deleted"
    echo ''
}

function start() {
    docker-deps-get

    docker inspect ${SONAR_INSTANCE_NAME} >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        docker run -d --name ${SONAR_INSTANCE_NAME} -p 9000:9000 sonarqube 2>&1 > /dev/null 
    else
        docker start ${SONAR_INSTANCE_NAME} 2>&1 > /dev/null 
    fi

    # 1. Wait for services to be up
    printf "Booting SonarQube docker instance "
    uri_wait http://localhost:9000 60
    printf 'Waiting for SonarQube service availability ' 
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
        -d "login=admin&previousPassword=admin&password=sonarless" \
        http://localhost:9000/api/users/change_password
    echo "Local sonarqube URI: http://localhost:9000" 

    # 3. Create default project and set default fav
    curl -s -u "admin:sonarless" -X POST "http://localhost:9000/api/projects/create?name=${SONAR_PROJECT_NAME}&project=${SONAR_PROJECT_NAME}" | jq
    curl -s -u "admin:sonarless" -X POST "http://localhost:9000/api/users/set_homepage?type=PROJECT&component=${SONAR_PROJECT_NAME}"
    echo "Credentials: admin/sonarless"

}

function stop() {
    docker stop ${SONAR_INSTANCE_NAME} >/dev/null 2>&1 && echo "Local SonarQube has been stopped"
}

function scan() {
    start

    # 1. Get internal IP for Sonar-Server
    export DOCKER_SONAR_IP=$(docker inspect ${SONAR_INSTANCE_NAME} | jq -r '.[].NetworkSettings.IPAddress')

    echo "SONAR_GITROOT: ${SONAR_GITROOT}"
    echo "SONAR_SOURCE_PATH: ${SONAR_SOURCE_PATH}"

    # 2. Create token and scan
    export SONAR_TOKEN=$(curl -s -X POST -u "admin:sonarless" "http://${DOCKER_SONAR_IP}:9000/api/user_tokens/generate?name=$(date +%s%N)" | jq -r .token)
    docker run --rm \
        -e SONAR_HOST_URL="http://${DOCKER_SONAR_IP}:9000"  \
        -e SONAR_TOKEN=${SONAR_TOKEN} \
        -e SONAR_SCANNER_OPTS="-Dsonar.projectKey=${SONAR_PROJECT_NAME} -Dsonar.sources=${SONAR_SOURCE_PATH}" \
        -v "${SONAR_GITROOT}:/usr/src" \
        sonarsource/sonar-scanner-cli

    # 3. Wait for scanning to be done
    printf '\nWaiting for analysis ' 
    for i in $(seq 1 120); do
        sleep 1
        printf .
        status_value=$(curl -s -u "admin:sonarless" http://${DOCKER_SONAR_IP}:9000/api/qualitygates/project_status?projectKey=${SONAR_PROJECT_NAME} | jq -r .projectStatus.status)
        # Checking if the status value is not "NONE"
        if [[ "$status_value" != "NONE" ]]; then
            printf "\nSonarQube scanning done\n"
            printf "Use webui http://localhost:9000 (admin/sonar) or 'sonarless results' to get scan outputs\n"
            break
        fi
    done
}

function results() {
    # use this params to collect stats
    curl -s -u "admin:sonarless" "http://localhost:9000/api/measures/component?component=${SONAR_PROJECT_NAME}&metricKeys=bugs,vulnerabilities,code_smells,quality_gate_details,violations,duplicated_lines_density,ncloc,coverage,reliability_rating,security_rating,security_review_rating,sqale_rating,security_hotspots,open_issues" \
        | jq -r > ${SONAR_GITROOT}/${SONAR_METRICS_PATH}
    cat ${SONAR_GITROOT}/${SONAR_METRICS_PATH}
    echo "Scan results written to  ${SONAR_GITROOT}/${SONAR_METRICS_PATH}"
}

function docker-deps-get() {
	( docker image inspect ${DOCKER_SONAR_SERVER} >/dev/null 2>&1 || echo "Downloading SonarQube..."; docker pull ${DOCKER_SONAR_SERVER} >/dev/null 2>&1 ) &
    ( docker image inspect ${DOCKER_SONAR_CLI} >/dev/null 2>&1 || echo "Downloading Sonar CLI..."; docker pull ${DOCKER_SONAR_CLI} >/dev/null 2>&1 ) &
    wait
}

function docker-clean() {
    docker rm -f ${SONAR_INSTANCE_NAME}
    docker image rm -f ${DOCKER_SONAR_CLI} ${DOCKER_SONAR_SERVER}
    docker image prune -f
    docker volume prune -f
}

function uninstall() {
    # Local variables
    sonarless_bashrc="${HOME}/.bashrc"
    sonarless_zshrc="${HOME}/.zshrc"

    docker-clean
    
    # Do not remove alias in rc files
    
    # [[ -s "${sonarless_bashrc}" ]] && grep 'sonarless' ${sonarless_bashrc}
    # if [ $? -eq 0 ];then 
    #     temp_file=$(mktemp)
    #     sed '/sonarless/{x;d;}' ${sonarless_bashrc} > ${temp_file}
    #     mv ${temp_file} ${sonarless_bashrc}
    # fi

    # [[ -s "${sonarless_zshrc}" ]] && grep 'sonarless' ${sonarless_zshrc}
    # if [ $? -eq 0 ];then 
    #     temp_file=$(mktemp)
    #     sed '/sonarless/{x;d;}' ${sonarless_zshrc} > ${temp_file}
    #     mv ${temp_file} ${sonarless_zshrc}
    # fi

    rm -rf ${HOME}/.${CLI_NAME}

}

$*