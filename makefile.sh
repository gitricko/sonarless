#!/bin/bash

export SONAR_INSTANCE_NAME=${SONAR_INSTANCE_NAME:-"sonar-server"}
export SONAR_INSTANCE_PORT=${SONAR_INSTANCE_PORT:-"9234"}
export SONAR_PROJECT_NAME="${SONAR_PROJECT_NAME:-$(basename "$(pwd)")}"
export SONAR_PROJECT_KEY="${SONAR_PROJECT_KEY:-$(basename "$(pwd)")}"
export SONAR_GITROOT=${SONAR_GITROOT:-"$(pwd)"}
export SONAR_SOURCE_PATH=${SONAR_SOURCE_PATH:-"."}
export SONAR_METRICS_PATH=${SONAR_METRICS_PATH:-"./sonar-metrics.json"}
export SONAR_EXTENSION_DIR="${HOME}/.sonarless/extensions"

export DOCKER_SONAR_CLI=${DOCKER_SONAR_CLI:-"sonarsource/sonar-scanner-cli:10.0"}
export DOCKER_SONAR_SERVER=${DOCKER_SONAR_SERVER:-"sonarqube:10.6-community"}

export CLI_NAME="sonarless"

function uri_wait(){
    set +e
    URL=$1
    SLEEP_INT=${2:-60}
    for _ in $(seq 1 "${SLEEP_INT}"); do
        sleep 1
        printf .
        HTTP_CODE=$(curl -k -s -o /dev/null -I -w "%{http_code}" -H 'User-Agent: Mozilla/6.0' "${URL}")
        [[ "${HTTP_CODE}" == "200" ]] && EXIT_CODE=0 || EXIT_CODE=-1
        [[ "${EXIT_CODE}" -eq 0 ]] && echo && return
    done
    echo
    set -e
    return "${EXIT_CODE}"    
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
    sonar-ext-get

    if ! docker inspect "${SONAR_INSTANCE_NAME}" > /dev/null 2>&1; then
        docker run -d --name "${SONAR_INSTANCE_NAME}" -p "${SONAR_INSTANCE_PORT}:9000" --network "${CLI_NAME}"  \
            -v "${SONAR_EXTENSION_DIR}:/opt/sonarqube/extensions/plugins" \
            -v "${SONAR_EXTENSION_DIR}:/usr/local/bin" \
            "${DOCKER_SONAR_SERVER}" > /dev/null 2>&1 
    else
        docker start "${SONAR_INSTANCE_NAME}" > /dev/null 2>&1 
    fi

    # 1. Wait for services to be up
    printf "Booting SonarQube docker instance "
    uri_wait "http://localhost:${SONAR_INSTANCE_PORT}" 60
    printf 'Waiting for SonarQube service availability ' 
    for _ in $(seq 1 180); do
        sleep 1
        printf .
        status_value=$(curl -s "http://localhost:${SONAR_INSTANCE_PORT}/api/system/status" | jq -r '.status')

        # Check if the status value is "running"
        if [[ "$status_value" == "UP" ]]; then
            echo
            break
        fi
    done

    status_value=$(curl -s "http://localhost:${SONAR_INSTANCE_PORT}/api/system/status" | jq -r '.status')
    # Check if the status value is "running"
    if [[ "$status_value" == "UP" ]]; then
        echo "SonarQube is running"
    else
        docker logs -f "${SONAR_INSTANCE_NAME}"
        echo "SonarQube is NOT running, exiting"
        exit 1
    fi

    # 2. Reset admin password to sonarless
    curl -s -X POST -u "admin:admin" \
        -d "login=admin&previousPassword=admin&password=sonarless" \
        "http://localhost:${SONAR_INSTANCE_PORT}/api/users/change_password"
    echo "Local sonarqube URI: http://localhost:${SONAR_INSTANCE_PORT}" 

    echo "Credentials: admin/sonarless"

}

function stop() {
    docker stop "${SONAR_INSTANCE_NAME}" > /dev/null 2>&1 && echo "Local SonarQube has been stopped"
}

function scan() {
    start

    # 1. Create default project and set default fav
    curl -s -u "admin:sonarless" -X POST "http://localhost:${SONAR_INSTANCE_PORT}/api/projects/create?name=${SONAR_PROJECT_NAME}&project=${SONAR_PROJECT_NAME}" | jq
    curl -s -u "admin:sonarless" -X POST "http://localhost:${SONAR_INSTANCE_PORT}/api/users/set_homepage?type=PROJECT&component=${SONAR_PROJECT_NAME}"
    
    echo "SONAR_GITROOT: ${SONAR_GITROOT}"
    echo "SONAR_SOURCE_PATH: ${SONAR_SOURCE_PATH}"

    # 2. Create token and scan using internal-ip becos of docker to docker communication
    SONAR_TOKEN=$(curl -s -X POST -u "admin:sonarless" "http://localhost:${SONAR_INSTANCE_PORT}/api/user_tokens/generate?name=$(date +%s%N)" | jq -r .token)
    export SONAR_TOKEN
    
    docker run --rm --network "${CLI_NAME}" \
        -e SONAR_HOST_URL="http://${SONAR_INSTANCE_NAME}:9000"  \
        -e SONAR_TOKEN="${SONAR_TOKEN}" \
        -e SONAR_SCANNER_OPTS="-Dsonar.projectKey=${SONAR_PROJECT_NAME} -Dsonar.sources=${SONAR_SOURCE_PATH}" \
        -v "${SONAR_GITROOT}:/usr/src" \
        "${DOCKER_SONAR_CLI}";
    SCAN_RET_CODE="$?"

    # 3. Wait for scanning to be done
    if [[ "${SCAN_RET_CODE}" -eq "0" ]]; then
        printf '\nWaiting for analysis' 
        for _ in $(seq 1 120); do
            sleep 1
            printf .
            status_value=$(curl -s -u "admin:sonarless" "http://localhost:${SONAR_INSTANCE_PORT}/api/qualitygates/project_status?projectKey=${SONAR_PROJECT_NAME}" | jq -r .projectStatus.status)
            # Checking if the status value is not "NONE"
            if [[ "$status_value" != "NONE" ]]; then
                echo
                echo "SonarQube scanning done"
                echo "Use webui http://localhost:${SONAR_INSTANCE_PORT} (admin/sonarless) or 'sonarless results' to get scan outputs"
                break
            fi
        done
    else
        printf '\nSonarQube scanning failed!' 
    fi
}

function results() {
    # use this params to collect stats
    curl -s -u "admin:sonarless" "http://localhost:${SONAR_INSTANCE_PORT}/api/measures/component?component=${SONAR_PROJECT_NAME}&metricKeys=bugs,vulnerabilities,code_smells,quality_gate_details,violations,duplicated_lines_density,ncloc,coverage,reliability_rating,security_rating,security_review_rating,sqale_rating,security_hotspots,open_issues" \
        | jq -r > "${SONAR_GITROOT}/${SONAR_METRICS_PATH}"
    cat "${SONAR_GITROOT}/${SONAR_METRICS_PATH}"
    echo "Scan results written to  ${SONAR_GITROOT}/${SONAR_METRICS_PATH}"
}

function docker-deps-get() {
	( docker image inspect "${DOCKER_SONAR_SERVER}" > /dev/null 2>&1 || echo "Downloading SonarQube..."; docker pull "${DOCKER_SONAR_SERVER}" > /dev/null 2>&1 ) &
    ( docker image inspect "${DOCKER_SONAR_CLI}" > /dev/null 2>&1 || echo "Downloading Sonar CLI..."; docker pull "${DOCKER_SONAR_CLI}" > /dev/null 2>&1 ) &
    wait
    docker network inspect "${CLI_NAME}" > /dev/null 2>&1 || docker network create "${CLI_NAME}" > /dev/null 2>&1
}

function sonar-ext-get() {

    [ ! -d "${SONAR_EXTENSION_DIR}" ] && echo "Downloading SonarQube Extensions..."; mkdir -p "${SONAR_EXTENSION_DIR}"

    if [ ! -f "${SONAR_EXTENSION_DIR}/shellcheck" ]; then
        # src: https://github.com/koalaman/shellcheck/blob/master/Dockerfile.multi-arch
        arch="$(uname -m)"
        os="$(uname | sed 's/.*/\L&/')"
        tag="v0.10.0"

        if [ "${arch}" = 'armv7l' ]; then
            arch='armv6hf'
        fi

        if [ "${arch}" = 'arm64' ]; then
            arch='aarch64'
        fi

        url_base='https://github.com/koalaman/shellcheck/releases/download/'
        tar_file="${tag}/shellcheck-${tag}.${os}.${arch}.tar.xz"
        curl -s --fail --location --progress-bar "${url_base}${tar_file}" | tar xJf - 

        mv "shellcheck-${tag}/shellcheck" "${SONAR_EXTENSION_DIR}/"
        rm -rf "shellcheck-${tag}"
    fi

    SONAR_SHELLCHECK="sonar-shellcheck-plugin-2.5.0.jar"
    SONAR_SHELLCHECK_URL="https://github.com/sbaudoin/sonar-shellcheck/releases/download/v2.5.0/${SONAR_SHELLCHECK}"
    if [ ! -f "${SONAR_EXTENSION_DIR}/${SONAR_SHELLCHECK}" ]; then
        curl -s --fail --location --progress-bar "${SONAR_SHELLCHECK_URL}" > "${SONAR_EXTENSION_DIR}/${SONAR_SHELLCHECK}"
    fi

}

function docker-clean() {
    docker rm -f "${SONAR_INSTANCE_NAME}"
    docker image rm -f "${DOCKER_SONAR_CLI}" "${DOCKER_SONAR_SERVER}"
    docker volume prune -f
    docker network rm -f "${CLI_NAME}"
}

function uninstall() {
    docker-clean
    rm -rf "${HOME}/.${CLI_NAME}"
}

$*
