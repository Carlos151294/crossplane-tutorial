# How to Check for v2-Compatible Package Versions

## Where to Check

### 1. GitHub Repository (Primary Source)
**Repository**: https://github.com/vfarcic/crossplane-tutorial

**What to check:**
- **Releases page**: https://github.com/vfarcic/crossplane-tutorial/releases
  - Look for releases with version numbers higher than current:
    - Current: `dot-sql:v0.8.77` → Look for `v0.9.x` or higher
    - Current: `dot-application:v0.5.45` → Look for `v0.6.x` or higher
  - Check release notes for "Crossplane v2" or "v2 compatibility" mentions

- **Issues**: https://github.com/vfarcic/crossplane-tutorial/issues
  - Search for: "v2", "crossplane v2", "pipeline mode", "v2 compatibility"
  - Look for open/closed issues discussing v2 migration

- **Pull Requests**: https://github.com/vfarcic/crossplane-tutorial/pulls
  - Search for PRs mentioning v2 updates or fixes

### 2. Upbound Package Registry
**Registry**: `xpkg.upbound.io/devops-toolkit/`

**Packages to check:**
- `xpkg.upbound.io/devops-toolkit/dot-sql`
- `xpkg.upbound.io/devops-toolkit/dot-application`

**How to check:**
Unfortunately, there's no direct web UI for the Upbound registry, but you can:

1. **Try different version tags** in your Configuration:
   ```yaml
   # Try incrementing the patch version
   package: xpkg.upbound.io/devops-toolkit/dot-sql:v0.8.78
   package: xpkg.upbound.io/devops-toolkit/dot-sql:v0.9.0
   package: xpkg.upbound.io/devops-toolkit/dot-sql:v0.10.0
   ```

2. **Use kubectl to test** (will fail if version doesn't exist, but gives you info):
   ```bash
   kubectl apply -f - <<EOF
   apiVersion: pkg.crossplane.io/v1
   kind: Configuration
   metadata:
     name: test-dot-sql
   spec:
     package: xpkg.upbound.io/devops-toolkit/dot-sql:v0.9.0
   EOF
   ```

### 3. Check Package Metadata
You can inspect the package metadata to see version constraints:

```bash
# Check what Crossplane version the package requires
# (This requires the package to be installed, but you can check the error messages)
kubectl describe configuration.pkg.crossplane.io crossplane-sql | grep -i version
```

### 4. Monitor for Updates
**Set up notifications:**
- **Watch the GitHub repo**: Click "Watch" on https://github.com/vfarcic/crossplane-tutorial
- **Check regularly**: Visit the releases page weekly
- **Subscribe to Crossplane announcements**: https://blog.crossplane.io/ for v2 migration guides

## Current Package Versions

### dot-sql
- **Current**: `xpkg.upbound.io/devops-toolkit/dot-sql:v0.8.77`
- **File**: `providers/dot-sql.yaml`
- **Version constraint**: `>=v1.14.0` (v1 only)

### dot-application
- **Current**: `xpkg.upbound.io/devops-toolkit/dot-application:v0.5.45`
- **File**: `providers/dot-app.yaml`
- **Version constraint**: `>=v1.14.0` (v1 only)

## What to Look For

When checking for v2-compatible versions, look for:

1. **Version constraint changes**: 
   - From: `version: ">=v1.14.0"`
   - To: `version: ">=v2.0.0"` or `version: ">=v1.14.0 || >=v2.0.0"`

2. **Release notes mentioning**:
   - "Crossplane v2 support"
   - "v2 compatibility"
   - "Pipeline mode fixes"
   - "Migration to v2"

3. **Issue/PR titles**:
   - "Add Crossplane v2 support"
   - "Fix pipeline mode validation"
   - "Update for v2 compatibility"

## Quick Check Script

You can create a script to test multiple versions:

```bash
#!/bin/bash
# test-package-versions.sh

PACKAGE="xpkg.upbound.io/devops-toolkit/dot-sql"
VERSIONS=("v0.8.78" "v0.8.90" "v0.9.0" "v0.10.0" "v1.0.0")

for version in "${VERSIONS[@]}"; do
  echo "Testing $PACKAGE:$version..."
  kubectl apply -f - <<EOF 2>&1 | head -5
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: test-dot-sql-$(echo $version | tr '.' '-')
spec:
  package: $PACKAGE:$version
EOF
  echo ""
done
```

## Alternative: Check This Repository

Since you're working with `github.com/vfarcic/crossplane-tutorial`, you might be able to:

1. **Check the local compositions**: Look in `compositions/` directory
   - The `sql-v11` version might have v2 compatibility
   - Check if `crossplane.yaml` in newer versions has `version: ">=v2.0.0"`

2. **Build from source**: If the repository has the package source, you could:
   - Build a v2-compatible version yourself
   - Submit a PR to fix the v2 compatibility issues

## Recommended Action Plan

1. **Immediate**: Check GitHub releases page for newer versions
2. **Short-term**: Open an issue on the GitHub repo asking about v2 compatibility
3. **Medium-term**: Monitor the repo for v2-compatible releases
4. **If needed**: Consider contributing a fix if you have the expertise

## Contact Information

- **Maintainer**: Viktor Farcic (@vfarcic)
- **Repository**: https://github.com/vfarcic/crossplane-tutorial
- **Open an issue**: https://github.com/vfarcic/crossplane-tutorial/issues/new
