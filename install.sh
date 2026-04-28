#!/bin/bash
# Veralux Analytics — workspace installer
# Usage: curl -fsSL https://raw.githubusercontent.com/vuelo-labs/cyborg_versions/main/install.sh | bash -s YOUR_TOKEN

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
  read -r TOKEN < /dev/tty
fi

if [ -z "$TOKEN" ]; then
  echo -e "${RED}Error: token is required.${NC}"
  exit 1
fi


# ── Check Docker ──────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Checking Docker…${NC}"
if ! command -v docker &>/dev/null; then
  echo -e "${YELLOW}Docker not found.${NC}"
  echo ""
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Installing Docker Desktop for Mac…"
    echo "This will download and open the installer. Follow the prompts."
    echo ""
    curl -fsSL -o /tmp/Docker.dmg "https://desktop.docker.com/mac/main/$(uname -m)/Docker.dmg"
    hdiutil attach /tmp/Docker.dmg -quiet
    cp -R "/Volumes/Docker/Docker.app" /Applications/ 2>/dev/null || {
      echo -e "${RED}Could not copy to Applications. Try dragging Docker.app manually.${NC}"
      open "/Volumes/Docker"
    }
    hdiutil detach "/Volumes/Docker" -quiet 2>/dev/null
    rm -f /tmp/Docker.dmg
    echo ""
    echo -e "${BOLD}Opening Docker Desktop — wait for it to start, then re-run this script.${NC}"
    open -a Docker
    exit 0
  else
    echo "Install Docker Desktop from https://www.docker.com/products/docker-desktop"
    echo "Then re-run this script."
    exit 1
  fi
fi

if ! docker info &>/dev/null; then
  echo -e "${YELLOW}Docker is installed but not running.${NC}"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Starting Docker Desktop…"
    open -a Docker
    printf "Waiting for Docker to start"
    for i in $(seq 1 30); do
      if docker info &>/dev/null; then break; fi
      printf "."
      sleep 2
    done
    echo ""
    if ! docker info &>/dev/null; then
      echo -e "${RED}Docker didn't start in time. Open Docker Desktop manually and try again.${NC}"
      exit 1
    fi
  else
    echo "Start Docker Desktop and try again."
    exit 1
  fi
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

DOCKER_ARGS=(
  -d
  --name "$CONTAINER"
  -e CANDIDATE_TOKEN="$TOKEN"
  -e SUBMISSION_ENDPOINT="${VERALUX_ENDPOINT:-https://linguist.vuelolabs.com/cyborg/submit}"
  -p "${WEB_PORT}:3000"
  -p "${SSH_PORT}:2222"
  -p "54545:54545"
)
# If VERALUX_DEADLINE is set, override the default 7-day window.
if [ -n "${VERALUX_DEADLINE:-}" ]; then
  DOCKER_ARGS+=(-e DEADLINE="${VERALUX_DEADLINE}")
fi

docker run "${DOCKER_ARGS[@]}" "$IMAGE"

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
