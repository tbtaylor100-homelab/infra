#!/bin/bash
set -euo pipefail

: "${FORGEJO_URL:?FORGEJO_URL must be set}"
: "${FORGEJO_TOKEN:?FORGEJO_TOKEN must be set}"
: "${REPOWISE_REPOS:?REPOWISE_REPOS must be set}"
REPOWISE_UPDATE_INTERVAL="${REPOWISE_UPDATE_INTERVAL:-3600}"

init_repos() {
    echo "[repowise] Starting clone + init"
    IFS=',' read -r -a REPOS <<< "$REPOWISE_REPOS"
    for REPO in "${REPOS[@]}"; do
        REPO=$(echo "$REPO" | tr -d ' ')
        [ -z "$REPO" ] && continue
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
            repowise init --path "${DEST}"
        else
            echo "[repowise] ${REPO} already indexed, skipping init"
        fi
    done
    echo "[repowise] Init complete"
}

update_loop() {
    IFS=',' read -r -a REPOS <<< "$REPOWISE_REPOS"
    while true; do
        sleep "${REPOWISE_UPDATE_INTERVAL}"
        for REPO in "${REPOS[@]}"; do
            REPO=$(echo "$REPO" | tr -d ' ')
            [ -z "$REPO" ] && continue
            OWNER=$(echo "$REPO" | cut -d/ -f1)
            NAME=$(echo "$REPO" | cut -d/ -f2)
            DEST="/data/${OWNER}/${NAME}"
            if [ -d "${DEST}/.repowise" ]; then
                echo "[repowise] Updating ${REPO}"
                cd "${DEST}" && git pull && repowise update --path "${DEST}"
            fi
        done
    done
}

(init_repos && update_loop) &

echo "[repowise] Starting mcp-proxy on :8080"
exec mcp-proxy --port 8080 -- repowise serve
