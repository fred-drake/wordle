from python:3.9.10 as base
ENV POETRY_VERSION=1.1.12
ENV POETRY_HOME=/usr/local
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -sSL https://install.python-poetry.org | python3 -

# installs all python dependencies to the image for development and testing.
from base as builder
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        cmake=3.18.4-2+deb11u1 \
        ruby=1:2.7+2 && \
    rm -rf /var/cache/apt/archives
RUN gem install mdl:0.11.0
WORKDIR /tmp
RUN curl -LO https://github.com/zricethezav/gitleaks/releases/download/v8.2.7/gitleaks_8.2.7_linux_x64.tar.gz && \
    tar zxvf gitleaks_8.2.7_linux_x64.tar.gz && \
    mv gitleaks /usr/local/bin
RUN curl -LO https://github.com/hadolint/hadolint/releases/download/v2.8.0/hadolint-Linux-x86_64 && \
    chmod +x hadolint-Linux-x86_64 && \
    mv hadolint-Linux-x86_64 /usr/local/bin/hadolint
WORKDIR /tmp/project
COPY src/ src/
COPY tests/ tests/
COPY pyproject.toml .
COPY poetry.toml .
COPY poetry.lock .
COPY setup.cfg .
RUN poetry install

# the development environment used for IDE integration
from builder as development
RUN rm -rf /tmp/project
ENV PYTHONPATH=/workspaces/wordle/src:/workspaces/wordle/tests

# takes what the builder image built and runs tests.
from builder as tester
COPY config.yaml .
COPY Dockerfile .
RUN poe test

# With tests complete, install all packages again, this time with no
# python development packages, but we will need to install native
# development packages via apt in order to build all of the python packages.
from base as packager
WORKDIR /app
COPY --from=tester /tmp/project/pyproject.toml .
COPY poetry.toml .
COPY poetry.lock .
COPY setup.cfg .
RUN apt-get update && apt-get install -y --no-install-recommends cmake=3.18.4-2+deb11u1
RUN poetry install --no-dev

# the production build, which pulls the source code from the packager and 
# installs only production dependencies in the final image.
from base
WORKDIR /app
ENV PYTHONPATH=/app/src
COPY src/ src/
COPY --from=packager /usr/local/lib/python3.9/site-packages /usr/local/lib/python3.9/site-packages
COPY config.yaml .
CMD [ "python", "src/wordle_rl/main.py" ]
