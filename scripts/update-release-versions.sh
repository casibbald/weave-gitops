#!/bin/bash
# Script to update all version references after Release Please updates go.mod
# This is called by Release Please to keep all version references in sync

set -e

VERSION=$1

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 v1.2.3"
    exit 1
fi

# Remove 'v' prefix if present for some files
VERSION_NO_V=${VERSION#v}

echo "Updating versions to: $VERSION (no-v: $VERSION_NO_V)"

# Update package.json
if [ -f "package.json" ]; then
    jq ".version = \"$VERSION_NO_V\"" package.json > package.json.tmp
    mv package.json.tmp package.json
    echo "✓ Updated package.json"
fi

# Update Chart.yaml appVersion and optionally increment chart version
if [ -f "charts/gitops-server/Chart.yaml" ]; then
    # Update appVersion
    yq eval ".appVersion = \"$VERSION\"" -i charts/gitops-server/Chart.yaml
    
    # For stable releases (not pre-releases), increment chart version
    if [[ "$VERSION" != *"-"* ]]; then
        CURRENT_CHART_VERSION=$(yq eval '.version' charts/gitops-server/Chart.yaml)
        # Increment patch version
        NEW_CHART_VERSION=$(echo "$CURRENT_CHART_VERSION" | awk -F. -v OFS=. '{$3++; print}')
        yq eval ".version = \"$NEW_CHART_VERSION\"" -i charts/gitops-server/Chart.yaml
        echo "✓ Updated Chart.yaml (appVersion: $VERSION, version: $NEW_CHART_VERSION)"
    else
        echo "✓ Updated Chart.yaml (appVersion: $VERSION) [pre-release, chart version unchanged]"
    fi
fi

# Update values.yaml image tag
if [ -f "charts/gitops-server/values.yaml" ]; then
    yq eval ".image.tag = \"$VERSION\"" -i charts/gitops-server/values.yaml
    echo "✓ Updated values.yaml image.tag"
fi

# Update README.md download links (stable releases only)
if [[ "$VERSION" != *"-"* ]]; then
    if [ -f "README.md" ]; then
        sed -i.bak "s#\(weave-gitops/releases/download/\)[^/]\+\(/gitops-\)#\1$VERSION\2#" README.md
        rm -f README.md.bak
        echo "✓ Updated README.md download links"
    fi
fi

echo "Version update complete: $VERSION"
