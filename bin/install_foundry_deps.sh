#!/usr/bin/env bash
#
# Zkolar Foundry Dependency Auto-Installer
# Automatically installs missing Foundry dependencies when container starts
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Checking Foundry dependencies...${NC}"

# Check if .gitmodules exists
if [ ! -f ".gitmodules" ]; then
    echo -e "${YELLOW}No .gitmodules found - skipping dependency check${NC}"
    exit 0
fi

# Check if lib/ directory is empty or has empty subdirectories
needs_install=false

while IFS= read -r line; do
    if [[ $line =~ path[[:space:]]*=[[:space:]]*(.*) ]]; then
        dep_path="${BASH_REMATCH[1]}"
        dep_path=$(echo "$dep_path" | xargs) # trim whitespace

        if [ ! -d "$dep_path" ] || [ -z "$(ls -A "$dep_path" 2>/dev/null)" ]; then
            echo -e "${YELLOW}Missing dependency: $dep_path${NC}"
            needs_install=true
        fi
    fi
done < .gitmodules

if [ "$needs_install" = true ]; then
    echo -e "${GREEN}Installing Foundry dependencies...${NC}"

    # Check if we're in a git repo
    if [ -d ".git" ] && git rev-parse --git-dir > /dev/null 2>&1; then
        # We have .git directory, use git submodule
        echo -e "${GREEN}Using git submodule...${NC}"
        git submodule update --init --recursive
    else
        # No .git directory, manually clone each dependency
        echo -e "${YELLOW}Not a git repository - manually cloning dependencies${NC}"

        # Parse .gitmodules more carefully
        current_path=""
        current_url=""

        while IFS= read -r line; do
            # Skip empty lines and comments
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

            # Detect new submodule section
            if [[ "$line" =~ ^\[submodule ]]; then
                # Process previous submodule if we have both path and url
                if [ -n "$current_path" ] && [ -n "$current_url" ]; then
                    if [ ! -d "$current_path" ] || [ -z "$(ls -A "$current_path" 2>/dev/null)" ]; then
                        echo -e "${GREEN}Cloning $current_url into $current_path${NC}"
                        mkdir -p "$(dirname "$current_path")"
                        rm -rf "$current_path"

                        if git clone --depth 1 "$current_url" "$current_path"; then
                            echo -e "${GREEN}✓ Cloned $current_path${NC}"
                        else
                            echo -e "${YELLOW}⚠ Failed to clone $current_path${NC}"
                        fi
                    fi
                fi
                # Reset for new submodule
                current_path=""
                current_url=""
            elif [[ "$line" =~ path[[:space:]]*=[[:space:]]*(.*) ]]; then
                current_path="${BASH_REMATCH[1]}"
                current_path=$(echo "$current_path" | tr -d '\r' | xargs) # trim whitespace and \r
            elif [[ "$line" =~ url[[:space:]]*=[[:space:]]*(.*) ]]; then
                current_url="${BASH_REMATCH[1]}"
                current_url=$(echo "$current_url" | tr -d '\r' | xargs) # trim whitespace and \r
            fi
        done < .gitmodules

        # Process the last submodule
        if [ -n "$current_path" ] && [ -n "$current_url" ]; then
            if [ ! -d "$current_path" ] || [ -z "$(ls -A "$current_path" 2>/dev/null)" ]; then
                echo -e "${GREEN}Cloning $current_url into $current_path${NC}"
                mkdir -p "$(dirname "$current_path")"
                rm -rf "$current_path"

                if git clone --depth 1 "$current_url" "$current_path"; then
                    echo -e "${GREEN}✓ Cloned $current_path${NC}"
                else
                    echo -e "${YELLOW}⚠ Failed to clone $current_path${NC}"
                fi
            fi
        fi
    fi

    echo -e "${GREEN}✓ All Foundry dependencies installed${NC}"
else
    echo -e "${GREEN}✓ All Foundry dependencies already present${NC}"
fi