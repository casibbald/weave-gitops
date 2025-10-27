# Legacy Release Process Analysis and Release Please Migration Plan

## Executive Summary

This document analyzes the current Weave GitOps release process and provides a migration plan to adopt Google's Release Please workflow for automated semantic versioning and releases.

**Current State:** Manual, multi-step release process requiring significant human intervention  
**Target State:** Fully automated, conventional commit-based release workflow  
**Benefits:** Reduced manual work, fewer errors, consistent releases, automated changelogs

---

## Current Legacy Process Analysis

### Overview

The current release process consists of **two primary workflows**:
1. **`prepare-release.yaml`** - Manual trigger, creates release preparation PR
2. **`release.yaml`** - Auto-triggered when release PR is approved

### Detailed Workflow Analysis

#### 1. Prepare Release Workflow (`.github/workflows/prepare-release.yaml`)

**Trigger:** Manual workflow dispatch with version input

**Process:**
1. User manually runs workflow, providing version (e.g., `v1.2.3-rc.4`)
2. Creates release branch: `releases/{version}`
3. Updates versions in multiple places:
   - NPM package.json (JavaScript library)
   - Helm Chart version and appVersion
   - Helm values.yaml image tag
   - Documentation via `update-docs.sh`
   - README.md download links
4. Generates changelog using `release-changelog-builder-action`
5. Creates PR with draft release notes
6. Locks PR with pending "release" status check

**Critical Files Modified:**
- `package.json` (NPM version)
- `charts/gitops-server/Chart.yaml` (chart version, appVersion)
- `charts/gitops-server/values.yaml` (Docker image tag)
- `website/` (docs versioning)
- `README.md` (download links)

#### 2. Release Workflow (`.github/workflows/release.yaml`)

**Trigger:** Pull request review with "approved" state on release branches

**Process:**
1. Extracts version from branch name (`releases/vX.Y.Z`)
2. Creates git tag with that version
3. Publishes NPM package to GitHub Packages
4. Builds and pushes Docker images (multi-platform: amd64, arm64)
5. Signs images with Cosign (keyless signing)
6. Runs GoReleaser to:
   - Build binaries for all platforms (Linux, macOS, Windows)
   - Publish to GitHub Releases
   - Optional Homebrew tap update (for stable releases only)
7. Automatically merges the release PR after successful release
8. Sets "release" status check to success to unlock merge

**Artifacts Produced:**
- Git tags (semantic versioning)
- GitHub Releases with binaries
- Docker images (ghcr.io/weaveworks/wego-app)
- NPM package (@weaveworks/weave-gitops)
- Helm chart (ghcr.io/weaveworks/charts)
- Homebrew formula update (weaveworks/homebrew-tap)

#### 3. PR Workflow (`.github/workflows/pr.yaml`)

**Triggers:** Push to main, PR events

**CI Jobs:**
- **ci-js:** JavaScript/UI tests and linting
- **ci-go:** Go unit tests
- **ci-static:** Format checking, linting, generated code validation
- **build-push-image:** Docker image builds (reusable workflow)
- **ci-upload-binary:** Binary artifacts (disabled on PRs)
- **ci-publish-js-lib:** NPM package on main branch only
- **release:** Status check marking (non-release PRs)

**Key Validations:**
- PR titles must follow Conventional Commits
- All generated code must be up-to-date
- go mod tidy must be run
- Proto files must be generated
- Fakes must be regenerated

#### 4. Supporting Workflows

**`lint-pr.yaml`**: Enforces Conventional Commits format on PR titles

**`trigger.yaml`**: Triggers enterprise workflow on releases/pushes

**`helm.yaml`**: Automatically releases Helm charts when chart version changes

**`scan.yaml`**: Security scanning (Trivy, CodeQL, FOSSA)

**`nightly.yaml`**: Playwright end-to-end tests

---

## Current Process Flow Diagram

```
┌─────────────────────────────────────────────────────────┐
│                   MAIN BRANCH (main)                     │
│                                                          │
│  ┌────────────┐                                         │
│  │  PR.yaml   │ <- Runs on every PR and push to main    │
│  │            │    - Runs CI/CD tests                    │
│  │            │    - Builds and signs images            │
│  │            │    - Validates code quality             │
│  └────────────┘                                         │
└────────────────────┬────────────────────────────────────┘
                     │
                     │ When ready for release
                     ▼
┌─────────────────────────────────────────────────────────┐
│            Manual Trigger: prepare-release.yaml          │
│                                                          │
│  1. Creates release branch (releases/v1.2.3)             │
│  2. Updates all version numbers                          │
│  3. Updates documentation                               │
│  4. Generates changelog                                  │
│  5. Creates PR to main                                   │
└────────────────────┬────────────────────────────────────┘
                     │
                     │ PR approved by maintainer
                     ▼
┌─────────────────────────────────────────────────────────┐
│              Auto Trigger: release.yaml                  │
│                                                          │
│  1. Creates git tag                                     │
│  2. Publishes NPM package                                │
│  3. Builds and pushes Docker images                      │
│  4. Runs GoReleaser (binaries, GitHub Releases)         │
│  5. Updates Homebrew tap (stable releases only)         │
│  6. Automatically merges PR                              │
└─────────────────────────────────────────────────────────┘
```

---

## Current Process Pain Points

### 1. **Manual Trigger Required**
- Human must remember to run `prepare-release` workflow
- Easy to forget or make mistakes in version numbers
- Requires access to GitHub Actions UI

### 2. **Complex Multi-Step Process**
- Multiple files need updating (package.json, Chart.yaml, values.yaml, README, docs)
- Each step has potential for human error
- Documentation sync is easy to miss

### 3. **Release Notes Generation**
- Relies on PR labels and manual curation
- Template-based but requires significant manual editing
- Changelog generation depends on external action

### 4. **Version Management**
- No automated version bumping
- Chart version increments are manual calculations
- Risk of version mismatches between artifacts

### 5. **Branch Management**
- Creates temporary release branches that are merged back
- Git history can get cluttered
- Tag points to non-main branch (until merged)

### 6. **Pre-release Handling**
- Conditional logic for `-rc.x` releases
- Some steps skipped for pre-releases but manual
- Homebrew updates only for stable releases

---

## Google Release Please Approach

### What is Release Please?

**Release Please** is an open-source tool by Google that automates releases based on Conventional Commits. It:
- Analyzes commit history for semantic versioning cues
- Creates release PRs automatically
- Maintains CHANGELOG.md
- Handles multi-component projects
- Supports pre-releases and stable releases

### Key Advantages

1. **Conventional Commits Driven**: Release type determined from commit messages
   - `feat:` → minor version bump
   - `fix:` → patch version bump
   - `BREAKING CHANGE:` → major version bump

2. **Automated Changelog**: Generated from git history and conventional commits

3. **No Manual Versioning**: Version calculated automatically from commits

4. **Release Pull Requests**: Creates draft PRs ready for review

5. **Monorepo Support**: Handles multiple components with independent versions

---

## Migration Plan

### Phase 1: Setup Release Please Workflow

#### Step 1.1: Install Release Please Action

Create `.github/workflows/release-please.yaml`:

```yaml
name: release-please

on:
  push:
    branches:
      - main

permissions:
  contents: write
  pull-requests: write

jobs:
  release-please:
    runs-on: ubuntu-latest
    steps:
      - uses: google-github-actions/release-please-action@v4
        id: release
        with:
          # This tells release-please to treat our repo as a single package
          # For multi-component, we'd use multiple release-please-config.json files
          token: ${{ secrets.WEAVE_GITOPS_BOT_ACCESS_TOKEN }}
      
      # If a release PR is created or updated
      - if: steps.release.outputs.release_created
        run: |
          echo "Release PR created at: ${{ steps.release.outputs.pr_created }}"
```

#### Step 1.2: Configure Release Please

Create `release-please-config.json` in project root:

```json
{
  "packages": {
    "weave-gitops": {
      "release-type": "go",
      "changelog-path": "CHANGELOG.md",
      "version-file": "go.mod",
      "extra-files": [
        "package.json",
        "charts/gitops-server/Chart.yaml"
      ]
    }
  },
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json"
}
```

#### Step 1.3: Add GitHub Release workflow

Create `.github/workflows/release-please-publish.yaml`:

```yaml
name: Release Please Publish

on:
  workflow_dispatch:

permissions:
  contents: write
  pull-requests: write

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: google-github-actions/release-please-action@v4
        id: release-please
        with:
          token: ${{ secrets.WEAVE_GITOPS_BOT_ACCESS_TOKEN }}
```

### Phase 2: Integrate with Existing Build Processes

#### Step 2.1: Modify Release Workflow to Use Release Please Tags

Modify `.github/workflows/release.yaml` to trigger on tags from release-please:

```yaml
on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      # Trigger GoReleaser
      - uses: goreleaser/goreleaser-action@v3
        with:
          version: latest
          args: release --clean
        env:
          GITHUB_TOKEN: ${{ secrets.WEAVE_GITOPS_BOT_ACCESS_TOKEN }}
      
      # Build Docker images
      - uses: ./.github/workflows/build-push-image.yaml
        # ... existing configuration
```

#### Step 2.2: Preserve Existing Artifacts

Keep all existing artifact generation:
- GoReleaser for binaries
- Docker multi-platform builds
- NPM package publishing
- Helm chart releases
- Homebrew updates

### Phase 3: Handle Multi-Component Versioning

#### Challenge: Version Alignment

The project has multiple components that need version alignment:
1. **Go Module**: Primary version (`go.mod`)
2. **NPM Package**: JavaScript library version (`package.json`)
3. **Helm Chart**: Chart version (`charts/gitops-server/Chart.yaml`)
4. **Docker Image**: Image tags (`charts/gitops-server/values.yaml`)

#### Solution: Custom Update Script

Create `scripts/update-versions.sh` that Release Please can call:

```bash
#!/bin/bash
VERSION=$1
# Update go.mod module version (handled by Release Please)
# Update package.json
jq ".version = \"$VERSION\"" package.json > package.json.tmp && mv package.json.tmp package.json

# Update Chart.yaml appVersion
yq eval ".appVersion = \"$VERSION\"" -i charts/gitops-server/Chart.yaml

# Update values.yaml image tag
yq eval ".image.tag = \"$VERSION\"" -i charts/gitops-server/values.yaml
```

Add to `release-please-config.json`:

```json
{
  "packages": {
    "weave-gitops": {
      "release-type": "go",
      "changelog-path": "CHANGELOG.md",
      "version-file": "go.mod",
      "extra-files": [
        "package.json",
        "charts/gitops-server/Chart.yaml"
      ],
      "bump-minor-pre-major": true,
      "extra-changelog-sections": [
        {
          "type": "feat",
          "section": "## 🚀 Enhancements"
        },
        {
          "type": "fix",
          "section": "## 🐛 Bug Fixes"
        },
        {
          "type": "docs",
          "section": "## 📖 Documentation"
        }
      ]
    }
  }
}
```

### Phase 4: Documentation Updates

Create or update `doc/release-process.md`:

```markdown
# Release Process

## Automated Releases with Release Please

Weave GitOps uses [Release Please](https://github.com/googleapis/release-please) for automated semantic versioning.

### How It Works

1. **Conventional Commits**: All commits must follow [Conventional Commits](https://www.conventionalcommits.org/)
   - `feat: Add new feature` → Minor version bump
   - `fix: Fix bug` → Patch version bump
   - `feat!: Breaking change` → Major version bump

2. **Automatic PR Creation**: Release Please creates release PRs when changes are ready

3. **Review and Merge**: Maintainers review and merge the release PR

4. **Automatic Release**: When merged, all artifacts are published:
   - GitHub Releases
   - Docker images
   - NPM package
   - Helm charts
   - Homebrew tap (stable releases only)

### Pre-Releases

For pre-releases (RCs), create a release PR and add `-rc.1` suffix to the version
in the PR description. Release Please will handle pre-release tags.

### Manual Release

For emergency releases, use `workflow_dispatch` to trigger the release process.

## Development Guidelines

### Commit Messages

Always use conventional commit format:

```
feat(cmd): Add new gitops check command

Adds a new check command to validate cluster state.
Implements X, Y, Z features.

Closes #123
```

### Breaking Changes

Mark breaking changes with `!` after the type:

```
feat!: Change API response format

BREAKING CHANGE: The API now returns JSON instead of YAML
```

## Versioning Policy

- **Major (v2.0.0)**: Breaking changes
- **Minor (v1.3.0)**: New features (backward compatible)
- **Patch (v1.2.1)**: Bug fixes only
```

### Phase 5: Migration Checklist

#### Week 1: Preparation
- [ ] Add Release Please configuration
- [ ] Test Release Please in staging branch
- [ ] Update contributor docs with commit message format
- [ ] Train team on conventional commits

#### Week 2: Parallel Running
- [ ] Run both systems in parallel
- [ ] Monitor Release Please PR generation
- [ ] Validate artifact quality
- [ ] Compare outputs with legacy releases

#### Week 3: Cutover
- [ ] Switch `release.yaml` to trigger on tags
- [ ] Remove `prepare-release.yaml` workflow
- [ ] Update release documentation
- [ ] Update Slack notifications

#### Week 4: Monitoring
- [ ] Monitor first automated releases
- [ ] Collect feedback from team
- [ ] Make adjustments as needed

---

## Comparison: Legacy vs Release Please

### Workflow Comparison

| Step | Legacy Process | Release Please |
|------|---------------|----------------|
| **Trigger** | Manual workflow dispatch | Automatic on push |
| **Version Calculation** | Manual input | Auto from commits |
| **Changelog** | External action + manual edit | Auto-generated |
| **Release PR** | Manual creation | Auto-created |
| **Version Updates** | Manual edits (5+ files) | Auto-updated |
| **Pre-releases** | Manual with dash check | Auto-supported |
| **Merge** | Auto after approval | Maintainer approval |
| **Artifact Build** | After PR approval | On tag push |

### Time Investment Comparison

**Legacy Process:**
- Trigger: 2 minutes
- Wait for prep: 3-5 minutes
- Review and edit release notes: 15-30 minutes
- Wait for release: 5-10 minutes
- **Total: 25-47 minutes per release**

**Release Please Process:**
- Trigger: Automatic
- Review auto-generated PR: 5 minutes
- Wait for release: 5-10 minutes
- **Total: 10-15 minutes per release**

**Savings: ~15-32 minutes per release**

### Risk Reduction

1. **No manual version errors**: Version calculated from commits
2. **Consistent changelogs**: Automated and standardized
3. **Fewer merge issues**: Release Please manages rebasing
4. **Better traceability**: Tags always point to main branch

---

## Implementation Roadmap

### Month 1: Setup and Testing
1. Add Release Please configuration
2. Test in feature branch
3. Create first release-please PR manually
4. Validate all artifacts

### Month 2: Parallel Operation
1. Run both systems
2. Compare outputs
3. Train team
4. Fix any issues

### Month 3: Cutover
1. Disable prepare-release.yaml
2. Update documentation
3. Complete first automated release
4. Monitor and optimize

---

## Rollback Plan

If issues arise:

1. **Immediate**: Disable release-please workflow, restore `prepare-release.yaml`
2. **Temporary**: Use manual `gh` CLI or GitHub UI for releases
3. **Long-term**: Keep legacy process as backup until fully validated

---

## Success Metrics

Track these metrics post-migration:

- Time to release (target: 50% reduction)
- Error rate (target: zero manual errors)
- Number of hot-fix releases (target: maintain current rate)
- Team satisfaction (target: positive feedback)

---

## Conclusion

The migration to Release Please will:
- ✅ Reduce manual work by 60-70%
- ✅ Eliminate version mismatches
- ✅ Provide consistent, automated changelogs
- ✅ Align with industry best practices
- ✅ Improve release quality and frequency

The legacy process works, but it's cumbersome and error-prone. Release Please provides a modern, automated alternative that scales with the team and reduces cognitive load on maintainers.
