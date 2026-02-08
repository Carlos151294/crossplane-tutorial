# API Migration Guide: devopstoolkitseries.com → devopstoolkit.live

## Summary of Changes

The new package versions (dot-sql v2.2.11, dot-app v3.0.46) use a different API group and structure:

### Old API (v0.x packages)
- **API Group**: `devopstoolkitseries.com/v1alpha1`
- **Resources**: `SQLClaim`, `AppClaim`, `ClusterClaim`
- **Structure**: Claim-based (namespaced resources that reference composite resources)
- **Package versions**: dot-sql v0.8.77, dot-app v0.5.45

### New API (v2.x/v3.x packages)
- **API Group**: `devopstoolkit.live/v1beta1`
- **Resources**: `SQL`, `App`, `ClusterClaim` (still uses old API group)
- **Structure**: Direct composite resources (no claims)
- **Package versions**: dot-sql v2.2.11, dot-app v3.0.46

## ✅ Confirmed API Structure

Based on CRD inspection, here are the confirmed field structures:

## Key Differences

### 1. SQL Resource

**Old (SQLClaim):**
```yaml
apiVersion: devopstoolkitseries.com/v1alpha1
kind: SQLClaim
metadata:
  name: my-db
spec:
  id: my-db
  compositionSelector:
    matchLabels:
      provider: google
      db: postgresql
  parameters:
    version: "13"
    size: small
    databases:
      - silly-demo-db
```

**New (SQL):**
```yaml
apiVersion: devopstoolkit.live/v1beta1
kind: SQL
metadata:
  name: my-db
spec:
  size: small  # required
  version: "13"  # optional
  databases:
    - silly-demo-db
  crossplane:
    compositionSelector:
      matchLabels:
        provider: google
        db: postgresql
```

**Changes:**
- No `id` field (uses `metadata.name` instead)
- `parameters` → moved to top-level `spec`
- `compositionSelector` → moved under `spec.crossplane.compositionSelector`
- `size` is now required (not optional)

### 2. App Resource

**Old (AppClaim):**
```yaml
apiVersion: devopstoolkitseries.com/v1alpha1
kind: AppClaim
metadata:
  name: silly-demo
spec:
  id: silly-demo
  compositionSelector:
    matchLabels:
      type: backend-db
      location: remote
  parameters:
    namespace: production
    image: c8n.io/vfarcic/silly-demo:1.4.52
    port: 8080
    host: silly-demo.acme.com
    dbSecret:
      name: silly-demo-db
      namespace: a-team
    kubernetesProviderConfigName: cluster-01
```

**New (App):**
```yaml
apiVersion: devopstoolkit.live/v1beta1
kind: App
metadata:
  name: silly-demo
spec:
  namespace: production
  image: c8n.io/vfarcic/silly-demo:1.4.52
  port: 8080
  host: silly-demo.acme.com
  dbSecret:
    name: silly-demo-db
    namespace: a-team
  kubernetesProviderConfigName: cluster-01
  crossplane:
    compositionSelector:
      matchLabels:
        type: backend-db
        location: remote
```

**Changes:**
- No `id` field (uses `metadata.name` instead)
- `parameters` → moved to top-level `spec`
- `compositionSelector` → moved under `spec.crossplane.compositionSelector`

### 3. ClusterClaim (Unchanged)

`ClusterClaim` still uses the old API group:
```yaml
apiVersion: devopstoolkitseries.com/v1alpha1
kind: ClusterClaim
```

## Migration Steps

1. **Update API version**: `devopstoolkitseries.com/v1alpha1` → `devopstoolkit.live/v1beta1`
2. **Change resource kind**: `SQLClaim` → `SQL`, `AppClaim` → `App`
3. **Remove `id` field**: Use `metadata.name` instead
4. **Move `parameters` to top-level `spec`**: All parameter fields go directly under `spec`
5. **Move `compositionSelector`**: Put it under `spec.crossplane.compositionSelector`
6. **Remove `spec.parameters` wrapper**: Parameters are now direct fields in `spec`

## Example Migration

### Before (a-team/intro.yaml)
```yaml
apiVersion: devopstoolkitseries.com/v1alpha1
kind: SQLClaim
metadata:
  name: silly-demo-db
spec:
  id: silly-demo-db
  compositionSelector:
    matchLabels:
      provider: google
      db: postgresql
  parameters:
    version: "13"
    size: small
    databases:
      - silly-demo-db
```

### After
```yaml
apiVersion: devopstoolkit.live/v1beta1
kind: SQL
metadata:
  name: silly-demo-db
spec:
  size: small
  version: "13"
  databases:
    - silly-demo-db
  crossplane:
    compositionSelector:
      matchLabels:
        provider: google
        db: postgresql
```
