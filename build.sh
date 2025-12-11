#!/bin/bash
set -e

# Build script for devcontainer images - works locally and in CI
# Usage:
#   ./build.sh                              # Build all combinations
#   ./build.sh --go 1.23.2 --python 3.12.7  # Build specific version
#   ./build.sh --push                       # Build and push to registry

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSIONS_FILE="${SCRIPT_DIR}/versions.json"

# Default values
PUSH=false
REGISTRY="${REGISTRY:-ghcr.io}"
REPOSITORY="${REPOSITORY:-$(git config --get remote.origin.url | sed 's/.*[:/]\([^/]*\/[^.]*\).*/\1/' | tr '[:upper:]' '[:lower:]')}"
SPECIFIC_GO=""
SPECIFIC_PYTHON=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --push)
      PUSH=true
      shift
      ;;
    --go)
      SPECIFIC_GO="$2"
      shift 2
      ;;
    --python)
      SPECIFIC_PYTHON="$2"
      shift 2
      ;;
    --registry)
      REGISTRY="$2"
      shift 2
      ;;
    --repo)
      REPOSITORY="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --push              Push images to registry after building"
      echo "  --go VERSION        Build only specific Go version"
      echo "  --python VERSION    Build only specific Python version"
      echo "  --registry URL      Registry URL (default: ghcr.io)"
      echo "  --repo NAME         Repository name (default: auto-detected from git)"
      echo "  --help              Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Function to build an image
build_image() {
  local go_version=$1
  local python_version=$2
  local platforms=$3

  # Create tag
  local tag="${REGISTRY}/${REPOSITORY}:go${go_version}-py${python_version}"
  local latest_tag="${REGISTRY}/${REPOSITORY}:latest"

  echo ""
  echo "=========================================="
  echo "Building Go ${go_version} + Python ${python_version}"
  echo "Tag: ${tag}"
  echo "Platforms: ${platforms}"
  echo "=========================================="
  echo ""

  # Detect architecture for single-platform builds
  local arch=$(uname -m)
  if [ "$arch" = "x86_64" ]; then
    arch="amd64"
  elif [ "$arch" = "aarch64" ] || [ "$arch" = "arm64" ]; then
    arch="arm64"
  fi

  # Build arguments
  local build_args=(
    --build-arg "GO_VERSION=${go_version}"
    --build-arg "PYTHON_VERSION=${python_version}"
    --file "${SCRIPT_DIR}/base/Dockerfile"
    --tag "${tag}"
  )

  # Add platform-specific args
  if [ "$PUSH" = true ]; then
    # Multi-platform build for push
    build_args+=(
      --platform "${platforms}"
      --push
    )
    docker buildx build "${build_args[@]}" "${SCRIPT_DIR}/base"
  else
    # Local single-platform build
    build_args+=(
      --platform "linux/${arch}"
      --load
    )
    docker buildx build "${build_args[@]}" "${SCRIPT_DIR}/base"

    echo ""
    echo "Successfully built: ${tag}"
    echo "Image loaded locally and ready to use"
  fi
}

# Check if docker buildx is available
if ! docker buildx version &> /dev/null; then
  echo "Error: docker buildx is required but not available"
  echo "Please install Docker with buildx support"
  exit 1
fi

# Ensure buildx builder exists
if ! docker buildx inspect multi-platform &> /dev/null; then
  echo "Creating buildx builder 'multi-platform'..."
  docker buildx create --name multi-platform --use --platform linux/amd64,linux/arm64 || true
fi

docker buildx use multi-platform || docker buildx use default

echo "Registry: ${REGISTRY}"
echo "Repository: ${REPOSITORY}"
echo "Push: ${PUSH}"
echo ""

# Read and parse versions.json
if [ ! -f "$VERSIONS_FILE" ]; then
  echo "Error: versions.json not found at ${VERSIONS_FILE}"
  exit 1
fi

# Build images based on filters
if [ -n "$SPECIFIC_GO" ] || [ -n "$SPECIFIC_PYTHON" ]; then
  # Build specific version(s)
  echo "Building specific version combination..."

  # Parse JSON and filter
  combinations=$(jq -c '.combinations[]' "$VERSIONS_FILE")

  while IFS= read -r combo; do
    go_ver=$(echo "$combo" | jq -r '.go_version')
    py_ver=$(echo "$combo" | jq -r '.python_version')
    platforms=$(echo "$combo" | jq -r '.platforms | join(",")')

    # Check if this combination matches our filters
    if [ -z "$SPECIFIC_GO" ] || [ "$go_ver" = "$SPECIFIC_GO" ]; then
      if [ -z "$SPECIFIC_PYTHON" ] || [ "$py_ver" = "$SPECIFIC_PYTHON" ]; then
        build_image "$go_ver" "$py_ver" "$platforms"
      fi
    fi
  done <<< "$combinations"
else
  # Build all combinations
  echo "Building all version combinations from versions.json..."

  combinations=$(jq -c '.combinations[]' "$VERSIONS_FILE")

  while IFS= read -r combo; do
    go_ver=$(echo "$combo" | jq -r '.go_version')
    py_ver=$(echo "$combo" | jq -r '.python_version')
    platforms=$(echo "$combo" | jq -r '.platforms | join(",")')

    build_image "$go_ver" "$py_ver" "$platforms"
  done <<< "$combinations"
fi

echo ""
echo "=========================================="
echo "Build complete!"
echo "=========================================="

if [ "$PUSH" = false ]; then
  echo ""
  echo "Images built locally. To push to registry, run:"
  echo "  $0 --push"
fi
