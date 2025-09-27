# Keycloak Setup for Airflow OIDC Authentication

This guide explains how to prepare **Keycloak (v26.x)** for Airflow integration using **OpenID Connect (OIDC)**.  
Follow these steps **before deploying Airflow**.

---

## 1. Log in to Keycloak

-   Open: `https://keycloak.local`
-   Log in as: `admin` (Keycloak administrator)

---

## 2. Create a New Realm

1. In the left-hand menu, click **Realm selector → Create Realm**.
2. Enter:
    - **Realm name**: `mlops`
3. Click **Create**.

---

## 3. Create a Client for Airflow

1. Go to **Clients → Create Client**.
2. Fill in:
    - **Client ID**: `airflow-client`
    - **Client Protocol**: `openid-connect`
    - **Client Authentication**: **ON** (confidential client)
    - **Authorization**: leave **OFF**
3. Click **Save**.

---

## 4. Configure Client Settings

1. Open the newly created client (`airflow-client`).
2. Set the following:

-   **Root URL**
    https://airflow.local

-   **Valid Redirect URIs**

https://airflow.local/*

-   **Web Origins**  
    https://airflow.local

-   **Access Type**: `confidential`
-   **Authentication flow**:
-   ✅ Standard flow
-   ✅ Direct access grants (optional, for CLI/API login)
-   ❌ Leave all others disabled (Implicit, Service accounts, Device flow, CIBA)

3. Click **Save**.

---

## 5. Configure Client Credentials

1. Go to the **Credentials** tab.
2. Copy the generated **Client Secret**.
3. Save it in your Airflow `.env.local` file:

```bash
KEYCLOAK_CLIENT_SECRET=<secret_from_keycloak>
```
