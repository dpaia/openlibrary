###############################################
# BASE IMAGE
###############################################
FROM 084828598639.dkr.ecr.us-west-2.amazonaws.com/docker-hub/library/python:3.10-slim-bookworm

###############################################
# WORKING DIRECTORY
###############################################
RUN mkdir /app
WORKDIR /app

###############################################
# SYSTEM DEPENDENCIES
###############################################
ENV LANG en_US.UTF-8
ENV LC_ALL POSIX

RUN apt-get -qq update && apt-get install -y \
    git \
    postgresql-client \
    build-essential \
    libpq-dev \
    libxml2-dev \
    libxslt-dev \
    libffi-dev \
    curl \
    parallel \
    zip \
    unzip \
    wget \
    gnupg \
    python3 \
    python-is-python3 \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 16 (compatible with 2022 codebase)
RUN curl -fsSL https://deb.nodesource.com/setup_16.x | bash - \
    && apt-get install -y nodejs

# Install Chrome and chromedriver for integration tests
RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

# Install chromedriver using apt package manager (simpler and more reliable)
RUN apt-get update && apt-get install -y chromium-driver \
    && ln -s /usr/bin/chromedriver /usr/local/bin/chromedriver \
    && rm -rf /var/lib/apt/lists/*

###############################################
# REPO SETUP
###############################################
RUN git clone https://github.com/dpaia/openlibrary.git .
RUN git submodule update --init --recursive

RUN git checkout 8717e18970bcdc4e0d2cea3b1527752b21e74866

###############################################
# ENTRYPOINT / CMD
###############################################

# Write preprocess and build scripts
ENV PYTEST_ADDOPTS="--tb=short -v --continue-on-collection-errors --reruns=3"
ENV UV_HTTP_TIMEOUT=60

RUN cat <<'EOFPREP' > /preprocess.sh
#!/bin/bash

cd /app

git reset --hard 46bcf7c30178f53ef427a5840c4b24717ed79fb0
git clean -fdx
git checkout 46bcf7c30178f53ef427a5840c4b24717ed79fb0

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

python -m pip install --upgrade pip setuptools wheel
sed -i 's/PyYAML==5.4.1/PyYAML>=6.0,<7/g' requirements.txt
python -m pip install --default-timeout=100 -r requirements.txt
python -m pip install -r requirements_test.txt

npm install --no-audit

export PYTHONPATH=/app
export OL_CONFIG=/app/conf/openlibrary.yml

echo "================= 0909 BUILD START 0909 ================="
make git

make i18n

make css js components

ln -sf vendor/infogami/infogami infogami
echo "================= 0909 BUILD END 0909 ================="

EOFBUILD
RUN chmod +x /build.sh
RUN /build.sh

LABEL ee-bench.type="codegen"
LABEL ee-bench.version="1.0"
RUN rm -rf /app/.ee-bench/ 2>/dev/null || true
