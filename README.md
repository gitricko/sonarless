[![Test](https://github.com/gitricko/sonarless/actions/workflows/test.yml/badge.svg)](https://github.com/gitricko/sonarless/actions/workflows/test.yml)

# Sonarless v1

This action and its developer friendly helper scripts enable sonarqube scanning for your repository without a need of a dedicated hosted sonarqube server. It boots up a sonarqube docker instance and enable developers to scan checkout code and give a metric json so that you can check the quality of the code.

# What's new

Please refer to the [release page](https://github.com/gitricko/sonarless/releases/latest) for the latest release notes.

# Usage

<!-- start usage -->
```yaml
- uses: gitricko/sonarless@v1
  with:
    # Folder path to scan from git-root
    # Default: . 
    sonar-source-path: ''

    # Path to SonarQube metrics json from git-root
    # Default: ./sonar-metrics.json 
    sonar-metrics-path: ''

    # SonarQube Project Name
    # Default: ${{ github.event.repository.name }}
    sonar-project-name: ''

    # SonarQube Project Key
    # Default: ${{ github.event.repository.name }}
    sonar-project-key: ''
```
<!-- end usage -->

# Scenarios

- [Scan all files from git root directory](#Sonar-scan-all-files-from-git-root-directory)
- [Scan particular folder from git root directory](#Scan-particular-folder-from-git-root-directory)
- [Scan code and fail build if metrics is below expectation](#Scan-code-and-fail-build-if-metrics-is-below-expectation)

## Sonar scan all files from git root directory

```yaml
jobs:
  Sonarless-Scan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Sonarless Scan
        uses: gitricko/sonarless@v1
```

## Scan particular folder from git root directory

```yaml
jobs:
  Sonarless-Scan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Sonarless Scan
        uses: gitricko/sonarless@v1
        with:
          sonar-source-path: 'src'
```

## Scan code and fail build if metrics is below expectation

```yaml
jobs:
  Sonarless-Scan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Sonarless Scan
        uses: gitricko/sonarless@v1
        with:
          sonar-source-path: 'src'
          sonar-metrics-path: './sonar-mymetrics.json'

      - name: Check Sonar Metrics - No Vulnerabilities
        run: |
          echo "Checking for any vulnerabilities in Sonar Metrics JSON"
          VULN=$(cat ./sonar-mymetrics.json | jq -r '.component.measures[] | select(.metric == "vulnerabilities").value')
          echo "# of vulnerabilities = ${VULN}"
          [ ${VULN} -eq "0" ]
```
# Use Sonarless in your Local Dev

To install automation scriptlets, paste and run the following in a terminal:
>  `curl -s "https://raw.githubusercontent.com/gitricko/sonarless/main/install.sh" | bash`

```ssh
                                               _ 
               ___   ___   _ __    __ _  _ __ | |  ___  ___  ___ 
              / __| / _ \ | "_ \  / _` || "__|| | / _ \/ __|/ __| 
              \__ \| (_) || | | || (_| || |   | ||  __/\__ \\__ \ 
              |___/ \___/ |_| |_| \__,_||_|   |_| \___||___/|___/ 


                                                                        Now attempting installation...

Looking for a previous installation of SONARLESS...
Looking for docker...
Looking for jq...
Looking for sed...
Installing Sonarless helper scripts...
* Downloading...

######################################################################## 100.0%

Please open a new terminal, or run the following in the existing one:

    alias sonarless='/home/runner/.sonarless/makefile.sh' 

Then issue the following command:

    sonarless help

Enjoy!!!
```
To understand the sub-commands, just run `sonarless help`

Usually, you only need to know 2 sub-commands
- `sonarless scan`: to start scanning your code in the current directory will be uploaded for scanning. When the scan is done, just login webui into your local personal instance of sonarqube via [http://localhost:9000](http://localhost:9000) to get details from SonarQube. The default password for `admin` is `sonarless`

- `sonarless results`: to generate `sonar-metrics.json` metrics file in your current directory

To clean up your sonar instance, just run `sonarless docker-clean`. SonarQube docker instance will be stop and all images removed.

This small scriptlet works perfectly with Github CodeSpace

# Coffee

If you find this small helper script and action helpful, buy me a [sip of coffee](https://ko-fi.com/gitricko) here to show your appreciation (only if you want to)