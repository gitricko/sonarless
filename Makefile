export SONAR_CLI_VERSION ?= 5.0.1.3006
export SONAR_INSTANCE_NAME ?= sonar
export SONAR_PROJECT_NAME ?= $(shell basename `pwd`)
export SONAR_SOURCES ?= $(shell `pwd`)

sonar-start:
	@bash ./action.sh sonar-start

sonar-scan: sonar-start
	echo "*** $$SONAR_PROJECT_NAME ***"
	echo "*** $$SONAR_PROJECT_KEY ***"

	./action.sh sonar-scan

sonar-results:
	@bash ./action.sh sonar-results

sonar-stop: 
	docker rm -f $(SONAR_INSTANCE_NAME)

sonar-action: sonar-scan
