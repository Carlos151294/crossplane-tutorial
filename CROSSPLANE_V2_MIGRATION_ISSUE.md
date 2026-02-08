# Crossplane v2 Migration Issue Investigation

## Problem Summary

The `crossplane-sql` and `crossplane-app` Configurations are unhealthy, preventing the `SQLClaim` and `AppClaim` CRDs from being installed. This blocks Argo CD from syncing resources that depend on these CRDs.

## Root Cause

**Version Mismatch**: The Configuration packages were built for Crossplane v1, but the cluster is running Crossplane v2.1.4.

### Current State
- **Crossplane Version**: v2.1.4 (installed)
- **dot-sql Package**: `xpkg.upbound.io/devops-toolkit/dot-sql:v0.8.77`
  - Specifies: `version: ">=v1.14.0"` (v1 constraint)
- **dot-application Package**: `xpkg.upbound.io/devops-toolkit/dot-application:v0.5.45`
  - Specifies: `version: ">=v1.14.0"` (v1 constraint)

### Error Details

```
Package revision health is "False" with message: 
cannot establish control of object: Composition.apiextensions.crossplane.io "local-k8s-postgresql" is invalid: 
spec: Invalid value: an array of pipeline steps is required in Pipeline mode
```

**For `crossplane-app`:**
```
Package revision health is "False" with message: 
cannot establish control of object: Composition.apiextensions.crossplane.io "app-frontend" is invalid: 
spec: Invalid value: an array of pipeline steps is required in Pipeline mode
```

## What Changed in Crossplane v2

Crossplane v2 introduced stricter validation for Pipeline mode Compositions:
- If `mode: Pipeline` is set, the `pipeline:` array **must** contain at least one step
- Empty or missing `pipeline:` arrays are now rejected

The packages contain Compositions with `mode: Pipeline` but empty/missing pipeline arrays, which worked in v1 but fails in v2.

## Impact

1. **CRDs Not Installed**: `SQLClaim` and `AppClaim` CRDs are not available
2. **Argo CD Sync Fails**: Resources using these CRDs show "Resource not found" errors
3. **Application Blocked**: The `a-team/intro.yaml` application cannot sync `SQLClaim` and `AppClaim` resources

## Solution Options

### Option 1: Wait for v2-Compatible Package Versions (Recommended)
- Check for newer versions of `dot-sql` and `dot-application` packages that support Crossplane v2
- Update `providers/dot-sql.yaml` and `providers/dot-app.yaml` with new versions
- Monitor the package repository for v2-compatible releases

### Option 2: Downgrade Crossplane to v1 (Not Recommended)
- Downgrade Crossplane from v2.1.4 to v1.14.0 or later v1.x version
- This would require reverting other v2-specific changes made to the setup
- Not recommended as v2 is the future direction

### Option 3: Manual Package Fix (Advanced)
- Extract and patch the problematic Compositions from the packages
- Add proper pipeline steps or change mode to `Resources`
- Rebuild and use custom packages
- This is complex and not recommended unless you control the package source

## Recommended Next Steps

1. **Check for Package Updates**:
   ```bash
   # Check if newer versions exist
   # Look for packages with version constraints like ">=v2.0.0"
   ```

2. **Contact Package Maintainers**:
   - The packages are maintained by `devops-toolkit` (Viktor Farcic)
   - Check GitHub issues/releases for v2 compatibility updates
   - Repository: `github.com/vfarcic/crossplane-tutorial`

3. **Temporary Workaround**:
   - For now, the Secret resource should work (namespace fixed)
   - SQLClaim and AppClaim will remain unavailable until Configurations are healthy

## Files Affected

- `providers/dot-sql.yaml` - Package version: `v0.8.77`
- `providers/dot-app.yaml` - Package version: `v0.5.45`
- `setup/00-intro.sh` - Installs these packages (lines 103, 105)

## Verification Commands

```bash
# Check Configuration health
kubectl get configuration.pkg.crossplane.io -o wide

# Check for CRDs
kubectl get crd | grep -E "sqlclaim|appclaim"

# Check Configuration details
kubectl describe configuration.pkg.crossplane.io crossplane-sql
kubectl describe configuration.pkg.crossplane.io crossplane-app
```

## Status

- ✅ **Investigation Complete**: Root cause identified
- ⏳ **Waiting for Solution**: Need v2-compatible package versions or alternative approach
- ⚠️ **Workaround Available**: Secret resource works, but SQLClaim/AppClaim are blocked
