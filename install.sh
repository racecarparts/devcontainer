#!/bin/bash
set -e

# Ephemeral installer for devcontainer setup
# Usage: curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/devcontainer/main/install.sh | bash

REPO_RAW="https://raw.githubusercontent.com/racecarparts/devcontainer/main"
REGISTRY="ghcr.io/racecarparts/devcontainer"

echo ""
echo "=========================================="
echo "Dev Container Setup"
echo "=========================================="
echo ""

# Check if .devcontainer already exists
if [ -d ".devcontainer" ]; then
    echo "⚠️  .devcontainer directory already exists!"
    read -p "Overwrite? (y/N): " -n 1 -r REPLY </dev/tty
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Fetch versions.json
echo "Fetching available versions..."
VERSIONS_JSON=$(curl -fsSL "${REPO_RAW}/versions.json")

if [ -z "$VERSIONS_JSON" ]; then
    echo "❌ Failed to fetch versions.json"
    exit 1
fi

# Parse and display versions
echo ""
echo "Available Go + Python combinations:"
echo ""

# Parse versions (compatible with bash 3.2+)
GO_VERSIONS=()
PY_VERSIONS=()

if command -v jq &> /dev/null; then
    # Use jq if available
    while IFS= read -r line; do
        GO_VERSIONS+=("$line")
    done < <(echo "$VERSIONS_JSON" | jq -r '.combinations[].go_version')

    while IFS= read -r line; do
        PY_VERSIONS+=("$line")
    done < <(echo "$VERSIONS_JSON" | jq -r '.combinations[].python_version')
else
    # Fallback: simple grep-based parsing
    while IFS= read -r line; do
        GO_VERSIONS+=("$line")
    done < <(echo "$VERSIONS_JSON" | grep -o '"go_version": "[^"]*"' | cut -d'"' -f4)

    while IFS= read -r line; do
        PY_VERSIONS+=("$line")
    done < <(echo "$VERSIONS_JSON" | grep -o '"python_version": "[^"]*"' | cut -d'"' -f4)
fi

# Build combinations array
COMBINATIONS=()
for i in "${!GO_VERSIONS[@]}"; do
    COMBINATIONS+=("Go ${GO_VERSIONS[$i]} + Python ${PY_VERSIONS[$i]}")
done

# Display options
i=1
for combo in "${COMBINATIONS[@]}"; do
    echo "  $i) $combo"
    ((i++))
done

echo ""
read -p "Select version (1-${#COMBINATIONS[@]}): " SELECTION </dev/tty

# Validate selection
if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt "${#COMBINATIONS[@]}" ]; then
    echo "❌ Invalid selection"
    exit 1
fi

# Get selected versions (array is 0-indexed)
IDX=$((SELECTION - 1))
GO_VERSION="${GO_VERSIONS[$IDX]}"
PY_VERSION="${PY_VERSIONS[$IDX]}"
IMAGE_TAG="${REGISTRY}:go${GO_VERSION}-py${PY_VERSION}"

echo ""
echo "Selected: ${COMBINATIONS[$IDX]}"
echo "Image: $IMAGE_TAG"
echo ""

# Prompt for project name
DEFAULT_PROJECT_NAME=$(basename "$PWD")
read -p "Project name (default: $DEFAULT_PROJECT_NAME): " PROJECT_NAME </dev/tty
PROJECT_NAME="${PROJECT_NAME:-$DEFAULT_PROJECT_NAME}"

echo ""

# Prompt for git config
read -p "Enter your Git name (e.g., John Doe): " GIT_NAME </dev/tty
read -p "Enter your Git email (e.g., john@example.com): " GIT_EMAIL </dev/tty

if [ -z "$GIT_NAME" ] || [ -z "$GIT_EMAIL" ]; then
    echo "⚠️  Git name and email are required"
    exit 1
fi

# Create .devcontainer directory
mkdir -p .devcontainer

# Download devcontainer.json
echo ""
echo "Downloading devcontainer.json..."
DEVCONTAINER_JSON=$(curl -fsSL "${REPO_RAW}/devcontainer.json")

if [ -z "$DEVCONTAINER_JSON" ]; then
    echo "❌ Failed to download devcontainer.json"
    exit 1
fi

# Update project name, image tag, and git config
# Simple sed replacement (works without jq)
UPDATED_JSON=$(echo "$DEVCONTAINER_JSON" | \
    sed "s/\"name\": \"Go + Python Development Container\"/\"name\": \"$PROJECT_NAME\"/g" | \
    sed "s|ghcr.io/racecarparts/devcontainer:go[0-9.]*-py[0-9.]*|$IMAGE_TAG|g" | \
    sed "s/\"GIT_USER_NAME\": \"Your Name\"/\"GIT_USER_NAME\": \"$GIT_NAME\"/g" | \
    sed "s/\"GIT_USER_EMAIL\": \"your.email@example.com\"/\"GIT_USER_EMAIL\": \"$GIT_EMAIL\"/g")

# Save to .devcontainer/devcontainer.json
echo "$UPDATED_JSON" > .devcontainer/devcontainer.json

echo ""
echo "=========================================="
echo "✅ Setup Complete!"
echo "=========================================="
echo ""
echo "Project: $PROJECT_NAME"
echo "Created: .devcontainer/devcontainer.json"
echo "Image: $IMAGE_TAG"
echo "Git: $GIT_NAME <$GIT_EMAIL>"
echo ""
echo "Next steps:"
echo "  1. Open this folder in VS Code"
echo "  2. When prompted, click 'Reopen in Container'"
echo "  3. Or press Cmd/Ctrl+Shift+P → 'Dev Containers: Reopen in Container'"
echo ""
echo "Customize .devcontainer/devcontainer.json if needed:"
echo "  - Uncomment mounts to use your host .gitconfig"
echo "  - Add custom post-create scripts"
echo "  - Modify VS Code settings and extensions"
echo ""
