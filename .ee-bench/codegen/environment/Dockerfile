###############################################
# BASE IMAGE
###############################################
FROM 084828598639.dkr.ecr.us-west-2.amazonaws.com/docker-hub/library/python:3.12-slim

###############################################
# WORKING DIRECTORY
###############################################
RUN mkdir /app
WORKDIR /app

###############################################
# SYSTEM DEPENDENCIES
###############################################
RUN apt-get update && apt-get install -y \
    git \
    postgresql-client \
    build-essential \
    libpq-dev \
    libxml2-dev \
    libxslt-dev \
    libffi-dev \
    libjpeg-dev \
    libpng-dev \
    libfreetype6-dev \
    liblcms2-dev \
    libwebp-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libxcb1-dev \
    curl \
    parallel \
    zip \
    unzip \
    wget \
    gnupg \
    ca-certificates \
    python3 \
    python-is-python3 \
    xvfb \
    && rm -rf /var/lib/apt/lists/* \
    && python3 -m pip install --upgrade pip \
    && ln -sf /usr/bin/python3 /usr/bin/python

# Install Node.js LTS
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs

# Install Chrome for integration tests
RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

# Install ChromeDriver - use a stable version that works with Chrome
RUN CHROMEDRIVER_VERSION="114.0.5735.90" \
    && wget -O /tmp/chromedriver.zip "https://chromedriver.storage.googleapis.com/${CHROMEDRIVER_VERSION}/chromedriver_linux64.zip" \
    && unzip /tmp/chromedriver.zip -d /tmp/ \
    && mv /tmp/chromedriver /usr/local/bin/chromedriver \
    && chmod +x /usr/local/bin/chromedriver \
    && rm /tmp/chromedriver.zip

###############################################
# REPO SETUP
###############################################
RUN git clone https://github.com/dpaia/openlibrary.git .
RUN git checkout e8fc82d8aae8463b752a211156c5b7b59f349237

###############################################
# ENTRYPOINT / CMD
###############################################

# Write preprocess and build scripts
ENV PYTEST_ADDOPTS="--tb=short -v --continue-on-collection-errors --reruns=3"
ENV UV_HTTP_TIMEOUT=60

RUN cat <<'EOFPREP' > /preprocess.sh
#!/bin/bash

cd /app

git reset --hard f0341c0ba81c790241b782f5103ce5c9a6edf8e3
git clean -fdx
git checkout f0341c0ba81c790241b782f5103ce5c9a6edf8e3

cd /

EOFPREP
RUN chmod +x /preprocess.sh
RUN /preprocess.sh

RUN cat <<'EOFBUILD' > /build.sh
#!/bin/sh
pip install setuptools || true
pip install pypi-timemachine
pypi-timemachine 2025-08-26 --port 9876 &
pip config set global.index-url http://127.0.0.1:9876/
sleep 3
pip install pytest-rerunfailures
export PYTEST_ADDOPTS="--tb=short -v --continue-on-collection-errors --reruns=3"

cd /app
set -e

pip install -r requirements.txt
pip install -r requirements_test.txt

pip install selenium splinter pytest pytest-xdist

echo "Attempting npm install..."
npm install || (echo "npm install failed, trying with --ignore-scripts" && npm install --ignore-scripts) || echo "All npm install attempts failed, continuing without npm packages..."

export PYTHONPATH=/app:$PYTHONPATH
export OL_CONFIG=/app/conf/openlibrary.yml

git submodule init
git submodule sync  
git submodule update

cp /workspace/auth.yaml /app/auth.yaml || echo "auth.yaml not found, creating minimal version"
echo -e "username: test_user\npassword: test_password" > /app/auth.yaml

echo "================= 0909 BUILD START 0909 ================="
make css || echo "CSS build failed, continuing..."
make js || echo "JS build failed, continuing..."
echo "================= 0909 BUILD END 0909 ================="

EOFBUILD
RUN chmod +x /build.sh
RUN /build.sh

LABEL ee-bench.type="codegen"
LABEL ee-bench.version="1.0"
RUN rm -rf /app/.ee-bench/ 2>/dev/null || true
