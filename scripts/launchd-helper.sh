#!/usr/bin/env bash

SAMLKEYGEN_NAME="samlkeygen"
SAMLKEYGEN_PATH="${HOME}/samlkeygen-env/bin/${SAMLKEYGEN_NAME}"
SAMLKEYGEN_DIR="${HOME}/${SAMLKEYGEN_NAME}"
SAMLKEYGEN_LOGS_DIR="${SAMLKEYGEN_DIR}/logs"
SAMLKEYGEN_PLIST="${SAMLKEYGEN_NAME}.plist"
SAMLKEYGEN_ACCOUNT_NAME="${SAMLKEYGEN_NAME}"

function usage() {
    echo "Usage: $0 [options...]" >&2
    echo "  -s  check status of the samlkeygen process" >&2
    echo "  -l  load samlkeygen launchd plist file" >&2
    echo "  -u  unload samlkeygen launchd plist file" >&2
    echo "  -i  install samlkeygen launchd plist file" >&2
    echo "  -r  uninstall samlkeygen launchd plist file" >&2
    echo "  -a  specify keyring account service name" >&2
    echo "  -p  samlkeygen path, defaults to ${SAMLKEYGEN_PATH}" >&2
    echo >&2
    exit 2
}

samlkeygen_path=""
account_name=""

run_status=false
run_install_plist=false
run_uninstall_plist=false
run_load=false
run_unload=false

while getopts "h?slirua:e:" opt; do
    case "$opt" in
    h|\?)
        usage
        ;;
    s)
        run_status=true
        ;;
    i)
        run_install_plist=true
        ;;
    r)
        run_uninstall_plist=true
        ;;
    l)
        run_load=true
        ;;
    u)
        run_unload=true
        ;;
    e)
        samlkeygen_path=$OPTARG
        ;;
    a)
        account_name=$OPTARG
        ;;
    esac
done

if [[ ! -z "${account_name}" ]]; then
    SAMLKEYGEN_ACCOUNT_NAME="${account_name}"
fi

if [[ ! -z "${samlkeygen_path}" ]]; then
    SAMLKEYGEN_PATH="${samlkeygen_path}"
fi

SAMLKEYGEN_PLIST_XML=$(cat <<EOS
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>EnvironmentVariables</key>
    <dict>
      <key>ADFS_URL</key>
      <string>${ADFS_URL}</string>

      <key>ADFS_DOMAIN</key>
      <string>${ADFS_DOMAIN}</string>
    </dict>

    <key>KeepAlive</key>
    <true/>

    <key>Label</key>
    <string>com.turner.${SAMLKEYGEN_NAME}</string>

    <key>ProcessType</key>
    <string>Interactive</string>

    <key>Program</key>
    <string>${SAMLKEYGEN_PATH}</string>
    <key>ProgramArguments</key>
    <array>
      <string>${SAMLKEYGEN_PATH}</string>
      <string>authenticate</string>
      <string>--all-accounts</string>
      <string>--auto-update</string>
      <string>--keyring-account</string>
      <string>${SAMLKEYGEN_ACCOUNT_NAME}</string>
    </array>

    <key>RunAtLoad</key>
    <false/>

    <key>SessionCreate</key>
    <false/>

    <key>WorkingDirectory</key>
    <string>${HOME}</string>

    <key>StandardOutPath</key>
    <string>${SAMLKEYGEN_LOGS_DIR}/${SAMLKEYGEN_NAME}.log</string>

    <key>StandardErrorPath</key>
    <string>${SAMLKEYGEN_LOGS_DIR}/${SAMLKEYGEN_NAME}.log</string>
  </dict>
</plist>
EOS
)

function status() {
    if [[ -d "${HOME}/Library/LaunchAgents" && -e "${HOME}/Library/LaunchAgents/${SAMLKEYGEN_PLIST}" ]]; then
        launchctl list "com.turner.${SAMLKEYGEN_NAME}"
    else
        echo "Unable to check launchd ${SAMLKEYGEN_NAME} process status"
        exit 1
    fi
}

function load() {
    if [[ -d "${HOME}/Library/LaunchAgents" && -e "${HOME}/Library/LaunchAgents/${SAMLKEYGEN_PLIST}" ]]; then
        launchctl load -w ${HOME}/Library/LaunchAgents/${SAMLKEYGEN_PLIST}
        echo
        echo "stderr and stdout are located in the ${SAMLKEYGEN_LOGS_DIR} directory"
        echo
    else
        echo "Unable to load launchd ${SAMLKEYGEN_NAME} process"
        exit 1
    fi
}

function unload() {
    if [[ -d "${HOME}/Library/LaunchAgents" && -e "${HOME}/Library/LaunchAgents/${SAMLKEYGEN_PLIST}" ]]; then
        if launchctl list "com.turner.${SAMLKEYGEN_NAME}"; then
            launchctl unload -w ${HOME}/Library/LaunchAgents/${SAMLKEYGEN_PLIST}
        fi
    else
        echo "Unable to unload launchd ${SAMLKEYGEN_NAME} process"
        exit 1
    fi
}

function install_plist() {
    mkdir -p "${HOME}/Library/LaunchAgents"
    mkdir -p ${SAMLKEYGEN_DIR}
    mkdir -p ${SAMLKEYGEN_LOGS_DIR}
    echo "${SAMLKEYGEN_PLIST_XML}" > "${SAMLKEYGEN_DIR}/${SAMLKEYGEN_PLIST}"
    ln -f -s "${SAMLKEYGEN_DIR}/${SAMLKEYGEN_PLIST}" ${HOME}/Library/LaunchAgents/${SAMLKEYGEN_PLIST}
}

function uninstall_plist() {
    rm -f ${HOME}/Library/LaunchAgents/${SAMLKEYGEN_PLIST}
    rm -fr "${SAMLKEYGEN_DIR}"
}

if ${run_install_plist}; then
    install_plist
elif ${run_uninstall_plist}; then
    uninstall_plist
elif ${run_status}; then
    status
elif ${run_load}; then
    load
elif ${run_unload}; then
    unload
else
    usage
fi
