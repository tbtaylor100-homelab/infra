#!/bin/bash
set -euo pipefail

: "${FORGEJO_URL:?FORGEJO_URL must be set}"
: "${FORGEJO_TOKEN:?FORGEJO_TOKEN must be set}"
: "${GEMINI_API_KEY:?GEMINI_API_KEY must be set}"
REPOWISE_UPDATE_INTERVAL="${REPOWISE_UPDATE_INTERVAL:-3600}"

discover_repos() {
    curl -sf \
        -H "Authorization: token ${FORGEJO_TOKEN}" \
        "${FORGEJO_URL}/api/v1/repos/search?limit=50&token=${FORGEJO_TOKEN}" \
        | jq -r '.data[].full_name'
}

clone_and_init() {
    local REPO="$1"
    local OWNER NAME DEST
    OWNER=$(echo "$REPO" | cut -d/ -f1)
    NAME=$(echo "$REPO" | cut -d/ -f2)
    DEST="/data/${OWNER}/${NAME}"
    mkdir -p "/data/${OWNER}"

    if [ ! -d "${DEST}/.git" ]; then
        echo "[repowise] Cloning ${REPO}"
        git clone "http://${FORGEJO_TOKEN}@$(echo "$FORGEJO_URL" | sed 's|http://||')/${REPO}.git" "${DEST}"
    fi

    if [ ! -d "${DEST}/.repowise" ]; then
        echo "[repowise] Running init for ${REPO} (~25 min)"
        repowise init "${DEST}"
    else
        echo "[repowise] ${REPO} already indexed, skipping init"
    fi
}

init_repos() {
    echo "[repowise] Discovering repos from Forgejo..."
    while IFS= read -r REPO; do
        [ -z "$REPO" ] && continue
        clone_and_init "$REPO"
    done < <(discover_repos)
    echo "[repowise] Init complete"
}

update_loop() {
    while true; do
        sleep "${REPOWISE_UPDATE_INTERVAL}"
        echo "[repowise] Running update cycle..."
        while IFS= read -r REPO; do
            [ -z "$REPO" ] && continue
            OWNER=$(echo "$REPO" | cut -d/ -f1)
            NAME=$(echo "$REPO" | cut -d/ -f2)
            DEST="/data/${OWNER}/${NAME}"
            if [ ! -d "${DEST}/.git" ]; then
                echo "[repowise] New repo detected: ${REPO}"
                clone_and_init "$REPO"
            elif [ -d "${DEST}/.repowise" ]; then
                echo "[repowise] Updating ${REPO}"
                cd "${DEST}" && git pull && repowise update
            fi
        done < <(discover_repos)
    done
}

(init_repos && update_loop) &

export REPOWISE_EMBEDDER=gemini

echo "[repowise] Starting repowise serve on :7337"
exec repowise serve --host 0.0.0.0
