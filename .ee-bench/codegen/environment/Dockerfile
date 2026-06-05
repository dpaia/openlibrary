###############################################
# BASE IMAGE
###############################################
FROM 084828598639.dkr.ecr.us-west-2.amazonaws.com/docker-hub/library/python:3.11-slim-bookworm

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
    nodejs \
    npm \
    python3-dev \
    python3-setuptools \
    gyp \
    chromium \
    chromium-driver \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

# Setup basic python environment which is needed for final post-processing and scoring
RUN python3 -m pip install --upgrade pip wheel
RUN ln -sf /usr/bin/python3 /usr/bin/python

###############################################
# REPO SETUP
###############################################
RUN git clone https://github.com/dpaia/openlibrary.git .
RUN git submodule update --init --recursive

# Freeze the repository to a reproducible state.
RUN git checkout 2d9a6c849c60ed19fd0858ce9e40b7cc8e097e59

###############################################
# ENTRYPOINT / CMD
###############################################

# Write preprocess and build scripts
ENV PYTEST_ADDOPTS="--tb=short -v --continue-on-collection-errors --reruns=3"
ENV UV_HTTP_TIMEOUT=60

RUN cat <<'EOFPREP' > /preprocess.sh
#!/bin/bash

cd /app

git reset --hard bf5511b4348e89a143ffc99553cd7e4e2a6b0485
git clean -fdx
git checkout bf5511b4348e89a143ffc99553cd7e4e2a6b0485

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

python -m pip install --default-timeout=100 -r requirements.txt
python -m pip install -r requirements_test.txt
python -m pip install selenium webdriver-manager splinter

ln -sf vendor/infogami/infogami infogami

export PYTHONPATH=/app
export OL_CONFIG=/app/conf/openlibrary.yml

echo "================= 0909 BUILD START 0909 ================="

echo "Skipping Node.js dependencies to focus on Python testing..."

make git 2>/dev/null || echo "make git failed, continuing..."

echo "Applying YAML loader fix for integration tests..."
sed -i 's/yaml\.load(f)/yaml.load(f, Loader=yaml.FullLoader)/g' tests/integration/__init__.py 2>/dev/null || echo "YAML fix not needed"

echo "Configuring WebDriver for headless Docker environment..."
cat > /tmp/webdriver_fix.py << 'EOF'
import re
import os

integration_init = 'tests/integration/__init__.py'
if os.path.exists(integration_init):
    with open(integration_init, 'r') as f:
        content = f.read()

    if 'from selenium.webdriver.chrome.options import Options' not in content:
        content = content.replace('from selenium import webdriver', 
            'from selenium import webdriver\nfrom selenium.webdriver.chrome.options import Options\nfrom selenium.webdriver.firefox.options import Options as FirefoxOptions')

    old_webdriver_block = '''        try:
            self.driver = webdriver.Chrome()
        except:
            self.driver = webdriver.Firefox()'''

    new_webdriver_block = '''        try:
            chrome_options = Options()
            chrome_options.add_argument('--headless')
            chrome_options.add_argument('--no-sandbox')
            chrome_options.add_argument('--disable-dev-shm-usage')
            chrome_options.add_argument('--disable-gpu')
            chrome_options.add_argument('--remote-debugging-port=9222')
            chrome_options.add_argument('--user-data-dir=/tmp/chrome-user-data')
            self.driver = webdriver.Chrome(options=chrome_options)
        except:
            firefox_options = FirefoxOptions()
            firefox_options.add_argument('--headless')
            self.driver = webdriver.Firefox(options=firefox_options)'''

    content = content.replace(old_webdriver_block, new_webdriver_block)

    with open(integration_init, 'w') as f:
        f.write(content)
EOF

python /tmp/webdriver_fix.py

echo "Skipping CSS/JS builds that require Node.js dependencies..."

echo "================= 0909 BUILD END 0909 ================="

EOFBUILD
RUN chmod +x /build.sh
RUN /build.sh

LABEL ee-bench.type="codegen"
LABEL ee-bench.version="1.0"
RUN rm -rf /app/.ee-bench/ 2>/dev/null || true
