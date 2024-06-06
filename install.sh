#!/bin/bash
#
#   Copyright 2024 gitricko
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#

set -e

track_last_command() {
    last_command=$current_command
    current_command=$BASH_COMMAND
}
trap track_last_command DEBUG

echo_failed_command() {
    local exit_code="$?"
	if [[ "$exit_code" != "0" ]]; then
		echo "'$last_command': command failed with exit code $exit_code."
	fi
}
trap echo_failed_command EXIT

# Global variables
export SONARLESS_SOURCES="https://raw.githubusercontent.com/gitricko/sonarless/main/makefile.sh"  # URL where makefile.sh is hosted

if [ -z "$SONARLESS_DIR" ]; then
    SONARLESS_DIR="$HOME/.sonarless"
fi
export SONARLESS_DIR

# Local variables
sonarless_bashrc="${HOME}/.bashrc"
sonarless_zshrc="${HOME}/.zshrc"


echo ''
echo '                                               _ '                
echo '               ___   ___   _ __    __ _  _ __ | |  ___  ___  ___ '
echo '              / __| / _ \ | "_ \  / _` || "__|| | / _ \/ __|/ __| '
echo '              \__ \| (_) || | | || (_| || |   | ||  __/\__ \\__ \ '
echo '              |___/ \___/ |_| |_| \__,_||_|   |_| \___||___/|___/ '
echo ''
echo ''
echo '                                                     Now attempting installation...'
echo ''                                                                 


# Sanity checks

echo "Looking for a previous installation of SONARLESS..."
if [ -d "$SONARLESS_DIR" ]; then
	echo "SONARLESS found."
	echo ""
	echo "======================================================================================================"
	echo " You already have SONARLESS installed."
	echo " SONARLESS was found at:"
	echo ""
	echo "    ${SONARLESS_DIR}"
	echo ""
	echo " Please consider uninstalling and reinstall."
	echo ""
	echo "    $ sonarless uninstall "
	echo ""
	echo "               or "
	echo ""
	echo "    $ rm -rf ${SONARLESS_DIR}"
	echo ""
	echo "======================================================================================================"
	echo ""
	exit 0
fi

echo "Looking for docker..."
if ! command -v docker > /dev/null; then
	echo "Not found."
	echo "======================================================================================================"
	echo " Please install docker on your system using your favourite package manager."
	echo ""
	echo " Restart after installing docker."
	echo "======================================================================================================"
	echo ""
	exit 1
fi

echo "Looking for jq..."
if ! command -v jq > /dev/null; then
	echo "Not found."
	echo "======================================================================================================"
	echo " Please install jq on your system using your favourite package manager."
	echo ""
	echo " Restart after installing jq."
	echo "======================================================================================================"
	echo ""
	exit 1
fi

echo "Looking for sed..."
if ! command -v sed > /dev/null; then
	echo "Not found."
	echo "======================================================================================================"
	echo " Please install sed on your system using your favourite package manager."
	echo ""
	echo " Restart after installing sed."
	echo "======================================================================================================"
	echo ""
	exit 1
fi

echo "Installing Sonarless helper scripts..."

# Create directory structure
mkdir -p "${SONARLESS_DIR}"

set +e
# Download makefile.sh depending which env (git or over curl)
# Check if you are in sonarless git
if [[ ! -d ./.git ]] || git remote get-url origin | grep -q sonarless; then
	echo "* Copying from local git..."
	cp -f ./makefile.sh "${SONARLESS_DIR}"
else
	echo "* Downloading..."
	curl --fail --location --progress-bar "${SONARLESS_SOURCES}" > "${SONARLESS_DIR}/makefile.sh"
	chmod +x "${SONARLESS_DIR}/makefile.sh"
fi

# Create alias in ~/.bashrc ~/.zshrc if available
if [[ ! -s "${sonarless_bashrc}" ]] || ! grep -q 'sonarless' "${sonarless_bashrc}" ;then 
	echo "alias sonarless='$HOME/.sonarless/makefile.sh'" >> "${sonarless_bashrc}"
fi

if [[ ! -s "${sonarless_zshrc}" ]] || ! grep -q 'sonarless' "${sonarless_zshrc}"; then 
	echo "alias sonarless='$HOME/.sonarless/makefile.sh'" >> "${sonarless_zshrc}"
fi

# Dynamically create the alias during installation so that use can use it
if ! command -v sonarless > /dev/null; then
	alias sonarless='$HOME/.sonarless/makefile.sh'
fi

echo ""
echo "Please open a new terminal, or run the following in the existing one:"
echo ""
echo "    alias sonarless='$HOME/.sonarless/makefile.sh' "
echo ""
echo "Then issue the following command:"
echo ""
echo "    sonarless help"
echo ""
echo "Enjoy!!!"