SHELL := /bin/bash

export SONAR_CLI_VERSION ?= 5.0.1.3006
export SONAR_INSTANCE_NAME ?= sonar-server
export SONAR_PROJECT_NAME ?= $(shell basename `pwd`)
export SONAR_PROJECT_KEY ?= $(shell basename `pwd`)
export SONAR_GITROOT ?= $(shell echo `pwd`)
export SONAR_SOURCE_PATH ?= .
export SONAR_METRICS_PATH ?= ./sonar-metrics.json

sonar-start:
	./makefile.sh sonar-start

sonar-scan: sonar-start
	./makefile.sh sonar-scan

sonar-results:
	./makefile.sh sonar-results

sonar-stop: 
	docker rm -f $(SONAR_INSTANCE_NAME)

sonar-docker-deps-get:
	docker pull sonarsource/sonar-scanner-cli
	docker pull sonarqube

docker-clean:
	-docker rm -f $$(docker ps -qa)
	docker system prune -fa
	docker volume prune -fa
