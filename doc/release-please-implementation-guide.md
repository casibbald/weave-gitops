# Release Please Implementation Guide

## Quick Start

This guide walks you through implementing Release Please for Weave GitOps, replacing the legacy manual release process.

---

## Prerequisites

1. **GitHub CLI** installed (`gh`)
2. **yq** installed (YAML processor)
3. **jq** installed (JSON processor)
4. Write access to the repository
5. Team trained on Conventional Commits format

---

## Step 1: Add Release Please Configuration

### 1.1 Create Config File

The configuration file is already created at `.github/release-please-config.json`.

This file tells Release Please:
- Which files to manage
- How to generate changelogs
- Release type (go, python, node, etc.)
- Extra files to update

### 1.2 Key Configuration Options

```json
{
  "packages": {
    "weave-gitops": {
      "release-type": "go",              // Go module release
      "changelog-path": "CHANGELOG.md",  // Generate CHANGELOG
      "version-file": "go.mod",          // Primary version file
      "extra-files": [                   // Additional files to update
        "package.json",
        "charts/gitops-server/Chart.yaml"
      ]
    }
  }
}
```

### 1.3 Create the Workflow

The workflow file is already created at `.github/workflows/release-please.yaml`.

This workflow:
- Runs on every push to main
- Creates or updates release PR
- Generates changelog
- Manages version bumps

---

## Step 2: Update Release Workflow

### 2.1 Modify Trigger

Edit `.github/workflows/release.yaml` to trigger on tags instead of PR approval:

```yaml
name: release

on:
  push:
    tags:
      - 'v*'  # Match all version tags

permissions:
  contents: write  # Need to create GitHub releases
  packages: write  # Need to push Docker images
  id-token: write  # Need for Cosign signing

jobs:
  # Keep all existing jobs
```

### 2.2 Update Job to Use Tag Context

Modify the `tag-release` job:

```yaml
jobs:
  tag-release:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.extract-version.outputs.version }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Need full history
      
      - name: Extract version from tag
        id: extract-version
        run: |
          VERSION=${GITHUB_REF#refs/tags/}
          echo "version=$VERSION" >> $GITHUB_OUTPUT
          echo "Releasing version: $VERSION"
```

### 2.3 Keep All Other Jobs

No changes needed to:
- `publish_npm_package`
- `build-and-push-image`
- `goreleaser`
- Any other artifact publishing

---

## Step 3: Handle Multi-Component Versioning

### The Challenge

Weave GitOps has multiple components:
1. **Go Module** (`go.mod`) - Primary version
2. **NPM Package** (`package.json`) - JavaScript library
3. **Helm Chart** (`charts/gitops-server/Chart.yaml`) - Chart + appVersion
4. **Docker Image** (`charts/gitops-server/values.yaml`) - Image tag

### The Solution

Create an update script that Release Please can call.

Add to `.github/release-please-config.json`:

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
      "versioning-strategy": "always-bump-patch"
    }
  }
}
```

Add a custom step to the release workflow:

```yaml
jobs:
  update-versions:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Update all versions
        run: |
          VERSION=${{ github.ref_name }}
          ./scripts/update-release-versions.sh "$VERSION"
      
      - name: Commit version updates
        run: |
          git config user.name weave-gitops-bot
          git config user.email weave-gitops-bot@weaveworks.org
          git add -A
          git commit -m "chore: update versions to ${{ github.ref_name }}" || exit 0
          git push
```

---

## Step 4: Train Team on Conventional Commits

### 4.1 Commit Format

All commits must follow:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### 4.2 Types

| Type | Description | Version Bump |
|------|-------------|--------------|
| `feat` | New feature | Minor (1.2.0) |
| `fix` | Bug fix | Patch (1.1.1) |
| `feat!` or `fix!` | Breaking change | Major (2.0.0) |
| `docs` | Documentation | None |
| `chore` | Maintenance | None |
| `refactor` | Code refactoring | None |
| `test` | Tests | None |

### 4.3 Examples

#### Feature (Minor Version)

```bash
feat(cli): Add cluster health check command

Adds a new `wego health check` command that validates
cluster health and resource status.

Closes #123
```

#### Bug Fix (Patch Version)

```bash
fix(api): Resolve authentication timeout

Extended timeout from 30 to 60 seconds and added retry logic.

Fixes #234
```

#### Breaking Change (Major Version)

```bash
feat!: Change default workspace directory

BREAKING CHANGE: Default workspace changed from ~/.gitops
to ~/.weave-gitops. Users must migrate existing workspaces.

Migration guide: docs/migration.md

Closes #456
```

### 4.4 Code Review Checklist

PR reviewers should verify:
- ✅ Commit messages follow conventional format
- ✅ All commits include type prefix
- ✅ Breaking changes marked with `!`
- ✅ PR title follows same format

---

## Step 5: Migration Testing

### 5.1 Test Branch Setup

```bash
# Create a test branch
git checkout -b test/release-please

# Create test commits
git commit -m "feat: Add test feature"
git commit -m "fix: Fix test bug"
git commit -m "feat!: Test breaking change"

# Push to GitHub
git push -u origin test/release-please
```

### 5.2 Expected Behavior

Release Please should:
1. Analyze commits on main
2. Calculate version bump (major in this example)
3. Create release PR
4. Include all test commits in changelog
5. Update version files

### 5.3 Validate PR

Check the release PR contains:
- ✓ Correct version number
- ✓ Generated changelog
- ✓ Updated version files
- ✓ Categorized commits

---

## Step 6: Parallel Operation

### Week 1: Run Both Systems

1. Keep `prepare-release.yaml` as backup
2. Add `release-please.yaml` workflow
3. Monitor both for one release cycle
4. Compare outputs

### Week 2: Cutover

1. Disable `prepare-release.yaml`
2. Use only Release Please
3. Keep `prepare-release.yaml` in codebase for rollback

### Week 3: Validation

1. Complete 2-3 releases with Release Please
2. Verify all artifacts published correctly
3. Gather team feedback
4. Make adjustments as needed

---

## Step 7: Rollback Plan

If issues occur:

### Immediate Rollback (5 minutes)

```bash
# Disable Release Please
gh workflow disable ".github/workflows/release-please.yaml"

# Re-enable legacy workflow
gh workflow enable ".github/workflows/prepare-release.yaml"
```

### Emergency Release

```bash
# Manual trigger of legacy prepare-release
gh workflow run prepare-release.yaml \
  --field version=v1.2.3
```

---

## Step 8: Update Documentation

### Update These Files

1. **`README.md`**: Add conventional commits note
2. **`CONTRIBUTING.md`**: Add commit format guide
3. **`doc/release-process.md`**: Update with new process
4. **PR template**: Add commit format reminder

### Example: CONTRIBUTING.md Addition

```markdown
## Commit Messages

All commits must follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types
- `feat:` New feature (minor version)
- `fix:` Bug fix (patch version)
- `feat!:` Breaking change (major version)
- `docs:` Documentation only
- `chore:` Maintenance tasks

### Examples
- ✅ `feat(cli): Add health check command`
- ✅ `fix(api): Resolve timeout issue`
- ❌ `Updated files` (too vague)
- ❌ `WIP` (not descriptive)
```

---

## Common Issues and Solutions

### Issue 1: Release PR Not Created

**Symptom:** No release PR appears after pushing commits.

**Diagnosis:**
```bash
# Check workflow runs
gh run list --workflow release-please.yaml

# Check workflow logs
gh run view <run-id> --log
```

**Solution:**
- Verify configuration file is valid JSON
- Check GitHub Actions permissions
- Ensure commits follow conventional format
- Verify bot token has permissions

### Issue 2: Wrong Version Calculated

**Symptom:** Version doesn't match expected semver bump.

**Diagnosis:**
```bash
# Check recent commits
git log --oneline -10

# Look for conventional commit prefixes
```

**Solution:**
- Check commit messages for typos
- Verify breaking changes marked with `!`
- Review release-please-config.json settings

### Issue 3: Files Not Updated

**Symptom:** Version files missing updates.

**Solution:**
- Verify files in `extra-files` list
- Check file paths are correct
- Ensure script has execute permissions
- Review workflow logs for errors

### Issue 4: Changelog Issues

**Symptom:** Changelog missing or incorrectly formatted.

**Solution:**
- Check `extra-changelog-sections` configuration
- Verify commits have proper labels
- Review changelog template

---

## Validation Checklist

After migration, verify:

- [ ] Release Please PR created automatically
- [ ] Version calculated correctly from commits
- [ ] Changelog generated properly
- [ ] All version files updated
- [ ] Docker images built and published
- [ ] NPM package published
- [ ] Helm chart updated
- [ ] GitHub Releases created
- [ ] Homebrew tap updated (stable releases)
- [ ] Documentation updated

---

## Success Metrics

Track these post-migration:

### Time Metrics
- Pre: 25-47 minutes per release
- Post: 10-15 minutes per release
- **Target: 50% reduction**

### Error Metrics
- Pre: ~2-3 version errors per year
- Post: 0 version errors
- **Target: Zero manual errors**

### Quality Metrics
- Changelog consistency: 100%
- Version sync: 100%
- Artifact completeness: 100%

---

## Support and Resources

### Documentation
- [Release Please Docs](https://github.com/googleapis/release-please)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)

### Internal Resources
- `doc/legacy-release-process-analysis.md` - Full analysis
- `doc/release-please-migration-summary.md` - Quick reference
- `doc/release-process-workflows.md` - Visual diagrams

### Getting Help
- Review workflow logs: `gh run view <run-id>`
- Check Release Please issues: https://github.com/googleapis/release-please/issues
- Ask in #weave-gitops-dev Slack channel

---

## Next Steps

1. Review this guide with the team
2. Schedule training on conventional commits
3. Test in a feature branch
4. Get approval from maintainers
5. Execute migration plan
6. Monitor and refine

**Remember:** Start with one release cycle in parallel before full cutover.
