#!/bin/bash
# Veralux Analytics — workspace installer
# Usage: bash install.sh YOUR_TOKEN

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

IMAGE="lcroash/veralux-primary-05:latest"
CONTAINER="veralux"
WEB_PORT=3000
SSH_PORT=2222

# ── Token ─────────────────────────────────────────────────────────────────────
TOKEN="${1:-}"
if [ -z "$TOKEN" ]; then
  echo ""
  echo -e "${BOLD}Veralux Analytics — Workspace Setup${NC}"
  echo ""
  printf "Enter your candidate token: "
  read -r TOKEN
fi

if [ -z "$TOKEN" ]; then
  echo -e "${RED}Error: token is required.${NC}"
  exit 1
fi

# ── Check Docker ──────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Checking Docker…${NC}"
if ! command -v docker &>/dev/null; then
  echo -e "${RED}Docker not found.${NC}"
  echo "Install Docker Desktop from https://www.docker.com/products/docker-desktop"
  exit 1
fi

if ! docker info &>/dev/null; then
  echo -e "${RED}Docker is installed but not running.${NC}"
  echo "Start Docker Desktop and try again."
  exit 1
fi

echo -e "${GREEN}Docker is running.${NC}"

# ── Remove existing container if present ─────────────────────────────────────
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo -e "${YELLOW}Existing workspace found — removing it.${NC}"
  docker stop "$CONTAINER" &>/dev/null || true
  docker rm   "$CONTAINER" &>/dev/null || true
fi

# ── Pull image ────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Pulling workspace image…${NC}"
echo "(This may take a minute on first run)"
docker pull "$IMAGE"

# ── Start container ───────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Starting workspace…${NC}"

docker run -d \
  --name "$CONTAINER" \
  -e CANDIDATE_TOKEN="$TOKEN" \
  -e DEADLINE="${VERALUX_DEADLINE:-2026-05-03T17:00:00Z}" \
  -e SUBMISSION_ENDPOINT="${VERALUX_ENDPOINT:-https://submit.veralux.io/submit}" \
  -p "${WEB_PORT}:3000" \
  -p "${SSH_PORT}:2222" \
  "$IMAGE"

# ── Wait for web app ──────────────────────────────────────────────────────────
printf "Waiting for workspace"
for i in $(seq 1 15); do
  if curl -sf "http://localhost:${WEB_PORT}/api/config" &>/dev/null; then
    break
  fi
  printf "."
  sleep 1
done
echo ""

if ! curl -sf "http://localhost:${WEB_PORT}/api/config" &>/dev/null; then
  echo -e "${RED}Workspace didn't start in time.${NC}"
  echo "Check logs with: docker logs $CONTAINER"
  exit 1
fi

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}Workspace is ready.${NC}"
echo ""
echo -e "  Browser:  ${BOLD}http://localhost:${WEB_PORT}${NC}"
echo ""
echo -e "  SSH connection details:"
echo -e "    Host:     localhost"
echo -e "    Port:     ${SSH_PORT}"
echo -e "    User:     candidate"
echo -e "    Password: ${TOKEN}"
echo ""
echo -e "  Claude Code:  ${BOLD}claude ssh candidate@localhost -p ${SSH_PORT}${NC}"
echo -e "  Cursor/VSCode: Remote-SSH → candidate@localhost:${SSH_PORT} → /workspace"
echo ""

# Open browser automatically
if command -v open &>/dev/null; then
  open "http://localhost:${WEB_PORT}"
elif command -v xdg-open &>/dev/null; then
  xdg-open "http://localhost:${WEB_PORT}"
fi
