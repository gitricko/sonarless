[![Build and Test](https://github.com/gitricko/sonarless/actions/workflows/ci.yml/badge.svg)](https://github.com/gitricko/sonarless/actions/workflows/ci.yml)

# Sonarless V0

This action enable sonarqube scanning for your repository without a need of a dedicated sonarqube server. This action will boot up a sonarqube docker instance and enable developers to scan checkout code and give you a metric json for you to check the quality of the code.

# Usage

<!-- start usage -->
```yaml
- uses: gitricko/sonarless@v0
  with:
    # Folder path to scan from git-root
    # Default: . (git root)
    sonar-source-path: ''

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


## Sonar scan all files from git root directory

```yaml
jobs:
  Sonarless-Scan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Sonarless Scan
        uses: gitricko/sonarless@v0
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
        uses: gitricko/sonarless@v0
        with:
          sonar-source-path: 'src'
```