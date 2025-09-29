# Custom Airflow image with OAuth dependencies for Keycloak integration
# Base image from Harbor registry
FROM harbor.local:30002/mlops/airflow:3.0.2

# Switch to root for any system-level changes if needed
USER root

# Switch back to airflow user for pip installs
USER airflow

# Install OAuth dependencies for Keycloak integration
# Note: flask-oauthlib requires requests-oauthlib<1.2.0
RUN pip install --no-cache-dir \
    requests-oauthlib==1.1.0 \
    flask-oauthlib==0.9.6 \
    authlib==1.2.1

# Verify OAuth dependencies are installed correctly
RUN python -c "import flask_oauthlib; print('flask-oauthlib installed')" && \
    python -c "import authlib; print('authlib installed')" && \
    python -c "import requests_oauthlib; print('requests-oauthlib installed')" && \
    echo "All OAuth dependencies installed successfully"

# Set working directory
WORKDIR /opt/airflow

# Copy FAB webserver configuration
COPY --chown=airflow:root webserver_config.py /opt/airflow/webserver_config.py

# Ensure we're running as airflow user
USER airflow