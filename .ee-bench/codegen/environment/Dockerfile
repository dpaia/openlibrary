###############################################
# BASE IMAGE
###############################################
FROM python:3.9-slim-bookworm

###############################################
# WORKING DIRECTORY
###############################################
# Set working directory, the repo should always be cloned into /app
# DO NOT MODIFY THIS SECTION
RUN mkdir /app
WORKDIR /app

###############################################
# SYSTEM DEPENDENCIES
###############################################
ENV LANG=en_US.UTF-8
ENV LC_ALL=POSIX

# Install required system dependencies
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
    python3-dev \
    python3-setuptools \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 16 (compatible with 2022 dependencies)
RUN curl -fsSL https://deb.nodesource.com/setup_16.x | bash - \
    && apt-get install -y nodejs

# Setup basic python environment which is needed for final post-processing and scoring
RUN python3 -m pip install --upgrade pip wheel
RUN ln -sf /usr/bin/python3 /usr/bin/python

###############################################
# REPO SETUP
###############################################
RUN git clone https://github.com/dpaia/openlibrary.git .
RUN git submodule update --init --recursive

# Freeze the repository to a reproducible state.
RUN git checkout fa6ff903cb27f336e17654595dd900fa943dcd91

###############################################
# ENTRYPOINT / CMD
###############################################

# Write preprocess and build scripts
ENV PYTEST_ADDOPTS="--tb=short -v --continue-on-collection-errors --reruns=3"
ENV UV_HTTP_TIMEOUT=60

RUN cat <<'EOFPREP' > /preprocess.sh
#!/bin/bash

cd /app

git reset --hard afb819f8166c6dff4295c6802cc0b55b67f05731
git clean -fdx
git checkout afb819f8166c6dff4295c6802cc0b55b67f05731

cd /

EOFPREP
RUN chmod +x /preprocess.sh
RUN /preprocess.sh

RUN cat <<'EOFBUILD' > /build.sh
#!/bin/sh
pip install setuptools || true
pip install pypi-timemachine
pypi-timemachine 2021-02-01 --port 9876 &
pip config set global.index-url http://127.0.0.1:9876/
sleep 3
pip install pytest-rerunfailures
export PYTEST_ADDOPTS="--tb=short -v --continue-on-collection-errors --reruns=3"

cd /app
set -e

python -m pip install --default-timeout=100 -r requirements.txt
python -m pip install -r requirements_test.txt
python -m pip install selenium

npm ci --no-audit --legacy-peer-deps --ignore-optional || npm install --no-audit --legacy-peer-deps --ignore-optional

ln -sf vendor/infogami/infogami infogami

export PYTHONPATH=/app
export OL_CONFIG=/app/conf/openlibrary.yml

echo "================= 0909 BUILD START 0909 ================="
make git
make css || true
make js || true
make components || true
make i18n || true
echo "================= 0909 BUILD END 0909 ================="

EOFBUILD
RUN chmod +x /build.sh
RUN /build.sh

LABEL ee-bench.type="codegen"
LABEL ee-bench.version="1.0"
RUN rm -rf /app/.ee-bench/ 2>/dev/null || true
