# Custom Airflow Image with OAuth Support

This directory contains the build configuration for a custom Airflow image that extends the base Harbor image with OAuth dependencies required for Keycloak integration.

## Files

- **Dockerfile**: Extends the Harbor Airflow base image with OAuth libraries
- **build-custom-image.sh**: Build and push script for the custom image
- **README.md**: This documentation file

## OAuth Dependencies Added

- `flask-oauthlib==0.9.6`: Flask OAuth library for OAuth provider integration
- `authlib==1.2.1`: Modern OAuth/OIDC library
- `requests-oauthlib==1.3.1`: OAuth for HTTP requests

## Build Process

1. **Base Image**: Uses `harbor.local:30002/mlops/airflow:3.0.2` as base
2. **Dependencies**: Installs OAuth libraries via pip
3. **Target Image**: Creates `harbor.local:30002/mlops/airflow:3.0.2-oauth`

## Usage

```bash
# Build and push custom image
./build-custom-image.sh
```

## Integration

After building, update `values/airflow-values.yaml`:

```yaml
images:
  airflow:
    repository: harbor.local:30002/mlops/airflow
    tag: "3.0.2-oauth"
```

## Verification

The build script includes verification steps to ensure all OAuth dependencies are correctly installed and importable.