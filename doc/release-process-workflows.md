# Release Process Workflow Diagrams

## Current Legacy Process

### Phase 1: Prepare Release

```
┌─────────────────────────────────────────────────────────────┐
│                    MAIN BRANCH (main)                       │
│  • Active development branch                                │
│  • All PRs merge here                                        │
│  • CI runs on every PR                                      │
└─────────────────────────────────────────────────────────────┘
                    ▲
                    │
         [Manual trigger by maintainer]
                    │
                    │ Input: v1.2.3-rc.1
                    │
┌─────────────────────────────────────────────────────────────┐
│              prepare-release.yaml Workflow                  │
├─────────────────────────────────────────────────────────────┤
│ 1. Create branch: releases/v1.2.3-rc.1                      │
│                                                             │
│ 2. Update package.json version                             │
│ 3. Update Chart.yaml version & appVersion                  │
│ 4. Update values.yaml image.tag                            │
│ 5. Update docs (run update-docs.sh)                       │
│ 6. Update README.md download links                         │
│                                                             │
│ 7. Generate changelog from git history                     │
│ 8. Create PR to main with draft release notes              │
│                                                             │
│ 9. Lock PR with "release: pending" status                  │
└─────────────────────────────────────────────────────────────┘
                    │
                    │ Creates PR
                    ▼
┌─────────────────────────────────────────────────────────────┐
│            Review and Approve Release PR                    │
│  • Maintainer reviews changes                              │
│  • Edits release notes                                      │
│  • Manually verifies all version updates                   │
│  • Approves PR                                              │
└─────────────────────────────────────────────────────────────┘
```

### Phase 2: Execute Release

```
                    │ [PR Approval triggers release.yaml]
                    ▼
┌─────────────────────────────────────────────────────────────┐
│                  release.yaml Workflow                      │
├─────────────────────────────────────────────────────────────┤
│ Job: tag-release                                            │
│  • Extract version from branch name                         │
│  • Create git tag v1.2.3-rc.1                               │
│  • Push tag to origin                                       │
└────────────────────────────────┬────────────────────────────┘
                                 │
                    ┌────────────┴────────────┐
                    ▼                         ▼
    ┌───────────────────────┐    ┌───────────────────────┐
    │ publish_npm_package  │    │ build-and-push-image  │
    │ • Build UI library   │    │ • Build Docker image  │
    │ • Publish to NPM     │    │ • Multi-platform      │
    │ • @weaveworks scope  │    │ • Sign with Cosign    │
    └───────────────────────┘    └───────────────────────┘
                    │                         │
                    └────────────┬────────────┘
                                 ▼
                ┌──────────────────────────────────┐
                │        goreleaser Job           │
                │  • Build binaries (all OS/arch)  │
                │  • Create GitHub Release         │
                │  • Publish assets                │
                │  • Update Homebrew (if stable)   │
                └────────────────┬─────────────────┘
                                 │
                                 ▼
                ┌──────────────────────────────────┐
                │       merge-pr Job              │
                │  • Unlock release status           │
                │  • Merge PR to main              │
                └──────────────────────────────────┘
```

---

## Proposed Release Please Process

### Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    MAIN BRANCH (main)                       │
│                                                             │
│  Commit Message: feat(cli): Add health check                │
│                  fix: Resolve auth timeout                  │
│                  feat!: Change default workspace            │
│                                                             │
└────────────────────────────────┬────────────────────────────┘
                                 │
                    ┌────────────┴────────────┐
                    ▼                         ▼
    ┌─────────────────────────┐  ┌─────────────────────────┐
    │   PR Workflow (CI/CD)   │  │  Release Please Workflow│
    │  • Run tests           │  │  • Analyze commits      │
    │  • Build artifacts     │  │  • Calculate version    │
    │  • Validate code       │  │  • Generate changelog   │
    └─────────────────────────┘  │  • Create release PR   │
                                 └────────────┬──────────────┘
                                              │
                                              ▼
                    ┌────────────────────────────────────────┐
                    │      Auto-Created Release PR          │
                    │                                        │
                    │  PR Title: chore: release v1.3.0      │
                    │                                        │
                    │  Changes:                              │
                    │  • go.mod version                      │
                    │  • package.json version                │
                    │  • Chart.yaml versions                │
                    │  • CHANGELOG.md                        │
                    │                                        │
                    │  Release Notes:                        │
                    │  ## 🚀 Enhancements                   │
                    │  - Add health check command            │
                    │                                        │
                    │  ## 🐛 Bug Fixes                      │
                    │  - Resolve auth timeout               │
                    │                                        │
                    │  ## ⚠️ Breaking Changes               │
                    │  - Change default workspace dir        │
                    └────────────────────┬───────────────────┘
                                         │
                  Maintainer Reviews & Approves
                                         │
                                         ▼
                    ┌────────────────────────────────────────┐
                    │    GitHub Release Event Triggered      │
                    │          (git tag: v1.3.0)             │
                    └────────────────────┬───────────────────┘
                                         │
                                         ▼
                    ┌────────────────────────────────────────┐
                    │      release.yaml Workflow            │
                    │                                        │
                    │  1. Build Docker images                │
                    │  2. Run GoReleaser                     │
                    │  3. Publish NPM package                │
                    │  4. Update Helm chart                  │
                    │  5. Update Homebrew                    │
                    └────────────────────────────────────────┘
```

### Detail: Release Please Workflow

```
┌─────────────────────────────────────────────────────────────┐
│            Release Please on Push to Main                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Analyze Git History                                     │
│     ┌───────────────────────────────────┐                  │
│     │ Recent commits:                   │                  │
│     │  feat: Add health check           │                  │
│     │  fix: Resolve auth timeout        │                  │
│     │  feat!: Change workspace dir      │                  │
│     └───────────────────────────────────┘                  │
│                                                             │
│  2. Calculate Version                                       │
│     ┌───────────────────────────────────┐                  │
│     │ Current: v1.2.5                   │                  │
│     │  + feat (minor)                   │                  │
│     │  + fix (patch)                    │                  │
│     │  + BREAKING (major)               │                  │
│     │ = v2.0.0                           │                  │
│     └───────────────────────────────────┘                  │
│                                                             │
│  3. Generate Changelog                                     │
│     ┌───────────────────────────────────┐                  │
│     │ - Categorize commits              │                  │
│     │ - Format release notes            │                  │
│     │ - Link PRs and issues              │                  │
│     └───────────────────────────────────┘                  │
│                                                             │
│  4. Check Release PR Status                                │
│     ┌───────────────────────────────────┐                  │
│     │ Is there an open release PR?      │                  │
│     │  NO → Create new PR               │                  │
│     │  YES → Update existing PR           │                  │
│     └───────────────────────────────────┘                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Detail: Release Trigger Flow

```
┌─────────────────────────────────────────────────────────────┐
│          Release PR Merged → GitHub Release Created         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Trigger: Push to main with new tag v2.0.0                  │
│                                                             │
└────────────────────────────────┬────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────┐
│                 release.yaml Workflow                       │
│            (Triggered by tag push)                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  Job: build-push-image                                │  │
│  │  • Build ghcr.io/weaveworks/wego-app:v2.0.0          │  │
│  │  • Multi-platform: amd64, arm64                      │  │
│  │  • Sign with Cosign                                  │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  Job: publish_npm_package                            │  │
│  │  • Build UI library                                  │  │
│  │  • Publish to npm as @weaveworks/weave-gitops:v2.0.0 │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  Job: goreleaser                                     │  │
│  │  • Build binaries for all platforms                 │  │
│  │    - Linux (amd64, arm64, arm)                      │  │
│  │    - macOS (amd64, arm64)                           │  │
│  │    - Windows (amd64)                                │  │
│  │  • Create GitHub Release with assets                │  │
│  │  • Update Homebrew tap                              │  │
│  │  • Sign artifacts with Cosign                       │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  Job: helm-release                                   │  │
│  │  • Package Helm chart                               │  │
│  │  • Push to ghcr.io/weaveworks/charts                │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Key Differences Summary

### Current Process
```
Developer → Manual Trigger → Prepare Release → Review → Approve → Release
              [Manual]       [15-30 min]      [5 min]  [5 min]    [10 min]
Total Time: 35-50 minutes
Manual Steps: 5
```

### Release Please Process
```
Developer → Conventional Commits → Auto PR → Review → Merge → Auto Release
                          [0 min]  [0 min]   [5 min]  [1 min]   [10 min]
Total Time: 16 minutes
Manual Steps: 1 (review only)
```

### Time Savings: 19-34 minutes per release

### Error Reduction

**Current Process:**
- Manual version input (can mismatch)
- Manual changelog curation
- Multiple file edits (can miss one)
- Branch management complexity

**Release Please:**
- Version auto-calculated (no errors)
- Changelog auto-generated (consistent)
- Files auto-updated (all or nothing)
- Single branch (main only)

---

## Migration Path

### Week 1: Setup
1. Add Release Please configuration
2. Create workflow files
3. Test in isolation

### Week 2: Parallel Run
1. Run both systems
2. Compare outputs
3. Train team

### Week 3: Cutover
1. Switch to Release Please
2. Keep legacy as backup
3. Monitor first release

### Week 4: Validation
1. Verify all artifacts
2. Collect feedback
3. Finalize migration

---

## Example Release Please PR

```markdown
# chore: release v2.0.0

## ⚠️ Breaking Changes

### Change Default Workspace Directory

The default workspace directory has been changed from `~/.gitops` to `~/.weave-gitops`.

**Migration:** Users should move their existing workspace directory:
```bash
mv ~/.gitops ~/.weave-gitops
```

Closes #789

## 🚀 Enhancements

### CLI: Add Health Check Command

New command to check cluster health and resource status:
```bash
wego health check --cluster prod
```

Returns detailed information about cluster resources, readiness, and issues.

Closes #123, #456

## 🐛 Bug Fixes

### API: Resolve Authentication Timeout

Extended authentication timeout from 30 to 60 seconds and added automatic retry logic.

Fixes #234

## 📖 Documentation

- Update installation guide with new workspace requirements
- Add troubleshooting section for common issues

Closes #567
```

---

## Pre-Release Example

For RC releases, the process is identical but with version suffix:

```
Version: v2.0.0-rc.1
Branch: releases/v2.0.0-rc.1
Tag: v2.0.0-rc.1
Artifacts: All published
Homebrew: NOT updated (only on stable releases)
```

This is automatically handled by Release Please based on semantic versioning.
