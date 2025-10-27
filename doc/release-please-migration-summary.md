# Release Please Migration - Quick Summary

## Current Process (What You Have Now)

### Workflow Overview
1. **Manual Trigger**: Developer runs `prepare-release.yaml` with version input
2. **Prep Workflow**: Automatically creates PR with version updates
3. **Approval**: Maintainer reviews and approves PR
4. **Release Workflow**: Builds and publishes all artifacts
5. **Auto-Merge**: PR automatically merges after release

### Pain Points
- ❌ Manual version input (error-prone)
- ❌ Complex multi-file updates
- ❌ Manual changelog editing
- ❌ 25-47 minutes per release
- ❌ Requires GitHub Actions UI access
- ❌ Risk of version mismatches

### Files Involved
- `.github/workflows/prepare-release.yaml` (manual trigger)
- `.github/workflows/release.yaml` (auto-trigger on approval)
- `package.json` (NPM version)
- `charts/gitops-server/Chart.yaml` (chart version)
- `charts/gitops-server/values.yaml` (image tag)
- Multiple docs and README files

---

## Proposed Process (Release Please)

### Workflow Overview
1. **Automatic**: Release Please analyzes commits on push to main
2. **Auto PR**: Creates release PR with calculated version
3. **Review**: Maintainer reviews and edits release notes
4. **Merge**: Maintainer merges PR
5. **Auto Release**: Tag triggers build and publish workflow

### Key Advantages
- ✅ Version from conventional commits (no manual input)
- ✅ Auto-updated changelogs
- ✅ Auto-calculated version bumps
- ✅ 10-15 minutes per release
- ✅ No manual UI interaction needed
- ✅ Eliminates version mismatches
- ✅ Industry best practice (Google standard)

### Files Needed
- `.github/workflows/release-please.yaml` (new)
- `.github/workflows/release-please-publish.yaml` (new)
- `release-please-config.json` (new)
- Modify `.github/workflows/release.yaml` (tag trigger)
- Keep existing build processes (GoReleaser, Docker, etc.)

---

## Conventional Commits Format

All commits must follow this format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types
- `feat: Add feature` → Minor version (v1.2.0)
- `fix: Fix bug` → Patch version (v1.2.1)
- `feat!: Breaking change` → Major version (v2.0.0)
- `chore: Maintenance` → No version bump
- `docs: Documentation` → No version bump

### Examples

```
feat(cli): Add cluster health check command

Implements new command to check cluster health status.
Returns detailed information about cluster resources.

Closes #123
```

```
fix(api): Resolve authentication timeout issue

The authentication logic was timing out after 30 seconds.
Extended timeout to 60 seconds and added retry logic.

Fixes #456
```

```
feat!: Change default workspace directory

BREAKING CHANGE: Default workspace directory changed from
~/.gitops to ~/.weave-gitops. Users must migrate existing
workspaces.

Closes #789
```

---

## Migration Steps

### 1. Add Release Please Configuration

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
        with:
          token: ${{ secrets.WEAVE_GITOPS_BOT_ACCESS_TOKEN }}
```

### 2. Create Config File

Create `release-please-config.json`:
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
  }
}
```

### 3. Modify Release Workflow

Change `.github/workflows/release.yaml` trigger from:
```yaml
on:
  pull_request_review:
```
to:
```yaml
on:
  push:
    tags:
      - 'v*'
```

### 4. Keep All Existing Build Logic

No changes to:
- GoReleaser configuration
- Docker build process
- NPM publishing
- Helm chart release
- Homebrew updates

---

## Comparison Table

| Aspect | Legacy Process | Release Please |
|--------|---------------|----------------|
| **Trigger** | Manual UI | Automatic |
| **Version** | Manual input | Auto-calculated |
| **Time** | 25-47 min | 10-15 min |
| **Changelog** | Manual edit | Auto-generated |
| **Files to Update** | 5+ files | 0 (auto) |
| **Error Rate** | Medium | Low |
| **Learning Curve** | High | Low |

---

## Rollback Strategy

If issues occur:
1. Disable `release-please.yaml` workflow
2. Restore `prepare-release.yaml` workflow
3. Continue with manual releases while fixing issues

No data loss or repository damage.

---

## Next Steps

1. **Review** this document and the full analysis
2. **Test** Release Please in a feature branch
3. **Train** team on conventional commits
4. **Migrate** one release at a time
5. **Monitor** and adjust as needed

See `doc/legacy-release-process-analysis.md` for complete details.
