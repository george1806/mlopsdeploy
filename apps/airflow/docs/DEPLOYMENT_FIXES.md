# Airflow 3.0.2 Deployment Fixes

This document outlines the critical fixes implemented for Apache Airflow 3.0.2 deployment on Kubernetes.

## Issues Fixed

### 1. API Server Crashes (CrashLoopBackOff)
**Problem**: Airflow 3.0.2 API server crashes with "Child process died" errors due to uvicorn worker processes dying.

**Root Cause**: Default 4 workers cause resource constraints in Kubernetes environment.

**Fix Applied**:
- Configured `--workers 1` in `values/airflow-values.yaml`
- Increased CPU resources: requests=400m, limits=800m
- Added `WEB_CONCURRENCY=1` environment variable

### 2. Authentication Setup Missing
**Problem**: Missing FAB (Flask AppBuilder) authentication tables causing 500 errors on login page.

**Root Cause**: Airflow 3.0 requires explicit FAB database initialization.

**Fix Applied**:
- Created `patches/init-fab-auth.sh` script to initialize FAB tables
- Integrated into main installation script `scripts/20-install.sh`
- Automatically creates admin user (admin/admin)

### 3. Architecture Changes in Airflow 3.0
**Problem**: Configuration incompatibilities with Airflow 3.0 architecture changes.

**Changes Made**:
- Webserver component merged into API server
- Helm chart 1.17.0 compatibility (downgraded from 1.18.0)
- Proper auth manager configuration: `airflow.providers.fab.auth_manager.fab_auth_manager.FabAuthManager`

## Critical Patches Preserved

### 1. `patches/init-fab-auth.sh`
Initializes FAB authentication system:
- Resets FAB database tables
- Creates admin user with proper permissions
- **Required**: Must run after every clean installation

### 2. `scripts/20-install.sh` (Modified)
Enhanced installation script:
- Includes FAB authentication initialization
- Proper secret management (let Helm handle webserver secret)
- Integrated migration and authentication setup

### 3. `values/airflow-values.yaml` (Modified)
Key configurations:
- API server worker count: 1
- CPU resources: 400m/800m
- WEB_CONCURRENCY environment variable
- Proper auth manager configuration

## Installation Process

1. **Preparation**: `./scripts/10-prep.sh`
   - Downloads Helm chart
   - Renders values file with environment variables

2. **Installation**: `./scripts/20-install.sh`
   - Creates namespace and secrets
   - Installs Airflow via Helm
   - Runs database migrations
   - Initializes FAB authentication
   - Creates admin user

## Manual Steps (None Required)

All critical patches have been integrated into the automated installation process. No manual intervention is needed after running the installation scripts.

## Verification

After installation, verify:
- All pods are Running: `kubectl get pods -n airflow`
- Login page accessible: HTTP 200 on `https://airflow.local/auth/login/`
- Admin user exists: `kubectl exec -n airflow deployment/airflow-api-server -- airflow users list`

## Access Credentials

- **URL**: https://airflow.local
- **Username**: admin
- **Password**: admin

## Notes

- The deprecation warning about secret_key configuration is harmless and does not affect functionality
- All authentication tables are properly initialized automatically
- The installation is fully reproducible with no manual steps required