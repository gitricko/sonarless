export SONAR_CLI_VERSION ?= 5.0.1
export SONAR_INSTANCE_NAME ?= sonar
export SONAR_PROJECT_NAME := $(shell basename `pwd`)


sonar-start:
	@bash ./action.sh sonar-start

sonar-scan: sonar-run
	@bash ./action.sh sonar-scan

sonar-stop: 
	docker rm -f $(SONAR_INSTANCE_NAME)