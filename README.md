# Multi-Version Devcontainer Base Images

Pre-built devcontainer images with various combinations of Go and Python versions, automatically built and published to GitHub Container Registry.

## Quick Setup

Add a devcontainer to your project in one command:

```bash
curl -sSL https://raw.githubusercontent.com/racecarparts/devcontainer/main/install.sh | bash
```

Or with wget:
```bash
wget -qO- https://raw.githubusercontent.com/racecarparts/devcontainer/main/install.sh | bash
```

The script will:
1. Show available Go + Python version combinations
2. Let you select your preferred versions
3. Prompt for your Git name and email
4. Create `.devcontainer/devcontainer.json` configured for your project
5. Ready to open in VS Code!

**Then:**
- Open your project in VS Code
- Click "Reopen in Container" when prompted
- Your dev environment is ready!

## Available Images

Images are tagged with the Go and Python versions they contain:

```
ghcr.io/<your-username>/devcontainer:go<GO_VERSION>-py<PYTHON_VERSION>
```

### Current Version Combinations

See [versions.json](./versions.json) for the complete list of available combinations.

Example tags:
- `ghcr.io/<your-username>/devcontainer:go1.23.2-py3.12.7`
- `ghcr.io/<your-username>/devcontainer:go1.23.2-py3.11.10`
- `ghcr.io/<your-username>/devcontainer:go1.22.8-py3.12.7`
- `ghcr.io/<your-username>/devcontainer:go1.22.8-py3.11.10`

All images are built for both `linux/amd64` and `linux/arm64` platforms.

## Features

Each image includes:

- **Go**: Specified version installed in `/usr/local/go`
- **Python**: Specified version managed via pyenv
- **Development Tools**: git, curl, wget, gcc, g++, make, cmake, ninja, etc.
- **Python Tools**: pip, setuptools, pre-commit, black, flake8, debugpy
- **Shell**: Zsh with Oh My Zsh, Powerlevel10k theme
- **Plugins**: zsh-autosuggestions, zsh-syntax-highlighting
- **Node.js & npm**: For additional tooling
- **Rust & Cargo**: For Rust-based tools

## Using Pre-built Images in Your Projects

### Manual Setup

Create a `.devcontainer/devcontainer.json` in your project:

```json
{
  "name": "My Project",
  "image": "ghcr.io/<your-username>/devcontainer:go1.23.2-py3.12.7",
  "customizations": {
    "vscode": {
      "extensions": [
        "golang.go",
        "ms-python.python"
      ]
    }
  }
}
```

### With Project Services (Postgres, Redis, etc.)

The devcontainer automatically starts services from your `docker-compose.yml` if it exists.

Just add services to your existing `docker-compose.yml`:

Create `.devcontainer/devcontainer.json`:

```json
{
  "name": "My Project",
  "dockerComposeFile": "docker-compose.yml",
  "service": "app",
  "workspaceFolder": "/workspace"
}
```

Create `.devcontainer/docker-compose.yml`:

```yaml
services:
  app:
    image: ghcr.io/<your-username>/devcontainer:go1.23.2-py3.12.7
    volumes:
      - ..:/workspace:cached
    command: sleep infinity

  postgres:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: postgres
```

### Option 3: Extending the Base Image

Create `.devcontainer/Dockerfile`:

```dockerfile
FROM ghcr.io/<your-username>/devcontainer:go1.23.2-py3.12.7

# Install project-specific dependencies
RUN pip install django fastapi
RUN go install github.com/cosmtrek/air@latest

# Add custom configuration
COPY requirements.txt /tmp/
RUN pip install -r /tmp/requirements.txt
```

Then reference it in `.devcontainer/devcontainer.json`:

```json
{
  "name": "My Project",
  "build": {
    "dockerfile": "Dockerfile"
  }
}
```

## Building Images Locally

### Prerequisites

- Docker with buildx support
- jq (for JSON parsing)

### Build All Versions

```bash
./build.sh
```

### Build Specific Version

```bash
./build.sh --go 1.23.2 --python 3.12.7
```

### Build and Push to Registry

```bash
./build.sh --push
```

### Build Specific Version and Push

```bash
./build.sh --go 1.23.2 --python 3.12.7 --push
```

### Custom Registry

```bash
./build.sh --registry docker.io --repo myusername/devcontainer --push
```

### Script Options

```
Usage: ./build.sh [OPTIONS]

Options:
  --push              Push images to registry after building
  --go VERSION        Build only specific Go version
  --python VERSION    Build only specific Python version
  --registry URL      Registry URL (default: ghcr.io)
  --repo NAME         Repository name (default: auto-detected from git)
  --help              Show this help message
```

## Adding New Version Combinations

1. Edit `versions.json` to add new combinations:

```json
{
  "combinations": [
    {
      "go_version": "1.24.0",
      "python_version": "3.13.0",
      "platforms": ["linux/amd64", "linux/arm64"]
    }
  ]
}
```

2. Commit and push:

```bash
git add versions.json
git commit -m "Add Go 1.24.0 + Python 3.13.0"
git push
```

3. GitHub Actions will automatically build and push the new images

## Automated Builds

Images are automatically built and pushed to GitHub Container Registry when:

- Changes are pushed to `main` branch
- Changes are made to `Dockerfile`, `versions.json`, or workflow files
- Manually triggered via GitHub Actions workflow

### Manual Trigger

Go to Actions → "Build and Push Devcontainer Images" → "Run workflow"

You can optionally specify:
- **Go version**: Build only specific Go version
- **Python version**: Build only specific Python version

## GitHub Container Registry Setup

### Making Images Public

1. Go to your repository on GitHub
2. Click on "Packages" in the right sidebar
3. Click on your package (devcontainer)
4. Go to "Package settings"
5. Scroll to "Danger Zone"
6. Click "Change visibility" and select "Public"

### Pulling Images Without Authentication

Once public, anyone can pull:

```bash
docker pull ghcr.io/<your-username>/devcontainer:go1.23.2-py3.12.7
```

### Pulling Private Images

For private packages:

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u <your-username> --password-stdin
docker pull ghcr.io/<your-username>/devcontainer:go1.23.2-py3.12.7
```

## Environment Variables

When building locally, the script uses:

- `REGISTRY`: Default `ghcr.io`
- `REPOSITORY`: Auto-detected from git remote

Override with environment variables:

```bash
REGISTRY=docker.io REPOSITORY=myuser/devcontainer ./build.sh --push
```

## Development

### Project Structure

```
.
├── base/                           # Base image source
│   ├── Dockerfile                  # Multi-version base image
│   ├── git-cfg/                    # Git configuration files
│   └── p10k-cfg/                   # Powerlevel10k theme config
├── versions.json                   # Version matrix configuration
├── build.sh                        # Build script (local & CI)
├── install.sh                      # Quick setup script for end-users
├── devcontainer.json               # Template for end-users
├── .github/
│   └── workflows/
│       └── build-and-push.yml     # CI/CD workflow
└── README.md                       # This file
```

### Testing Changes Locally

1. Make changes to `base/Dockerfile` or `versions.json`
2. Build locally: `./build.sh --go 1.23.2 --python 3.12.7`
3. Test the image:
   ```bash
   docker run -it --rm ghcr.io/<your-username>/devcontainer:go1.23.2-py3.12.7 zsh
   ```
4. Verify Go and Python versions:
   ```bash
   go version
   python --version
   ```

### Testing in This Repository

The `devcontainer.json` at the root is for local development/testing of changes to the base image:

1. Make changes to files in `base/`
2. Open this repository in VS Code
3. Reopen in Container to test your changes
4. Once satisfied, build and push with `./build.sh --push`

## Troubleshooting

### Build fails with "no space left on device"

Clean up Docker:

```bash
docker system prune -a
```

### buildx not available

Ensure Docker Desktop is up to date, or install buildx:

```bash
docker buildx install
```

### Cannot push to registry

1. Authenticate with GitHub:
   ```bash
   echo $GITHUB_TOKEN | docker login ghcr.io -u <your-username> --password-stdin
   ```

2. Ensure you have package write permissions on the repository

### Image not pulling in devcontainer

1. Make sure the image is public or you're authenticated
2. Check the tag exists: `docker pull ghcr.io/<your-username>/devcontainer:go1.23.2-py3.12.7`
3. Verify the full image name in your devcontainer.json

## License

MIT
