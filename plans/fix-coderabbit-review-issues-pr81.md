# Plan: Fix CodeRabbit Review Issues (PR #81)

## Context

PR #81 addresses CodeRabbit review issues from PRs #78-80. Two CodeRabbit reviews were performed:
- Review 1 (bfc7505): 6 actionable comments, 4 nitpicks
- Review 2 (dc69f4d): 4 actionable comments, 3 nitpicks

Commit `d8c8e45` addressed most critical issues. This plan addresses remaining items.

---

## Issues to Fix

### Epic 1: Go Install Script Fixes

#### T1.1: Update gotestsum fallback version
- **File**: `.devcontainer/features/languages/go/install.sh:170`
- **Issue**: Fallback version `1.12.0` is outdated
- **Fix**: Update to `1.13.0` (latest stable)
- **Priority**: High (outdated version)

#### T1.2: (Optional) Add binary checksum verification
- **File**: `.devcontainer/features/languages/go/install.sh:92-130`
- **Issue**: Downloaded binaries not verified (unlike java/install.sh)
- **Fix**: Add checksum verification similar to Java
- **Priority**: Medium (security improvement, requires GitHub checksum API)
- **Deferred**: Requires fetching checksums from GitHub releases

### Epic 2: Dart/Flutter Install Script Fixes

#### T2.1: Fix grep check for PATH duplication
- **File**: `.devcontainer/features/languages/dart-flutter/install.sh:106`
- **Issue**: Checks `PUB_CACHE` but adds PATH for `$PUB_BIN`
- **Fix**: Check for `$PUB_BIN` or the comment `"Dart pub global binaries"`
- **Priority**: High (consistency with php/install.sh)

### Epic 3: (Optional) PHP Install Script Nitpick

#### T3.1: Capture Pest error output
- **File**: `.devcontainer/features/languages/php/install.sh:97`
- **Issue**: `2>/dev/null` suppresses useful debug info
- **Fix**: Capture error and log conditionally
- **Priority**: Low (optional improvement)

---

## Summary

| Epic | Tasks | Priority |
|------|-------|----------|
| 1: Go fixes | 1 required, 1 optional | High |
| 2: Dart fixes | 1 required | High |
| 3: PHP nitpicks | 1 optional | Low |

**Required changes**: 2 (T1.1, T2.1)
**Optional changes**: 2 (T1.2, T3.1)

---

## Files Modified

1. `.devcontainer/features/languages/go/install.sh` (line 170)
2. `.devcontainer/features/languages/dart-flutter/install.sh` (line 106)

---

## Test Plan

- [ ] Verify gotestsum 1.13.0 is installable
- [ ] Verify dart-flutter PATH is not duplicated on rebuild
- [ ] Run devcontainer build with affected languages
