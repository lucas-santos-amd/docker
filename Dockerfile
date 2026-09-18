FROM rocm/pytorch:latest

### Build time variables:
ARG USER_REAL_NAME
ARG USER_EMAIL
ARG USER_ID
ARG USER_NAME
ARG GROUP_ID
ARG GROUP_NAME

### Image metadata:
LABEL org.opencontainers.image.authors="${USER_EMAIL}" \
      org.opencontainers.image.title="Triton development environment of ${USER_REAL_NAME}."

### Environment variables:
    # No warnings when running `pip` as `root`.
ENV PIP_ROOT_USER_ACTION=ignore
ENV TRITON_BUILD_WITH_CCACHE=true
#ENV ROCM_VERSION=7.0

### CREATE GROUP AND USER
RUN if getent group ${GROUP_ID}; then \
        GROUP_NAME=$(getent group ${GROUP_ID} | cut -d: -f1); \
    else \
        groupadd -g ${GROUP_ID} ${GROUP_NAME}; \
    fi && \
    useradd -m -u ${USER_ID} -g ${GROUP_ID} -s /bin/bash -d /triton_dev/chome ${USER_NAME} && \
    usermod --append --groups video "${USER_NAME}"

### apt step:
COPY apt_requirements.txt /tmp
    # Update package index.
RUN apt-get --yes update && \
    # Update packages.
    apt-get --yes upgrade && \
    # Install packages.
    sed 's/#.*//;/^$/d' /tmp/apt_requirements.txt \
        | xargs apt-get --yes install --no-install-recommends && \
	apt-get --yes install openssh-client && \
    # Clean up apt.
    apt-get --yes autoremove && \
    apt-get clean && \
    rm --recursive --force /tmp/apt_requirements.txt /var/lib/apt/lists/*

### Special build of `aqlprofiler` (it's required to use ATT Viewer):
#COPY "deb/rocm${ROCM_VERSION}_hsa-amd-aqlprofile_1.0.0-local_amd64.deb" /tmp
#RUN dpkg --install "/tmp/rocm${ROCM_VERSION}_hsa-amd-aqlprofile_1.0.0-local_amd64.deb" && \
#    rm --recursive --force "/tmp/rocm${ROCM_VERSION}_hsa-amd-aqlprofile_1.0.0-local_amd64.deb"

### Configure Git:
RUN git config --global user.name "${USER_REAL_NAME}" && \
    git config --global user.email "${USER_EMAIL}" && \
    git config --global --add safe.directory '*' && \
    # cp ~/.gitconfig /triton_dev/chome/ && \
    # Set GitHub SSH hosts as known hosts:
    mkdir --parents --mode 0700 ~/.ssh && \
    ssh-keyscan github.com >> ~/.ssh/known_hosts
	
### pip step:
COPY pip_requirements.txt /tmp
    # Uninstall Triton shipped with PyTorch, we'll compile Triton from source.
RUN pip uninstall --yes triton && \
    # Install pacakges.
    pip install --no-cache-dir --requirement /tmp/pip_requirements.txt && \
    # Install `hip-python` from TestPyPI package index.
    # (it's required for `tune_gemm.py --icache_flush` option)
    #pip install --no-cache-dir --index-url https://test.pypi.org/simple "hip-python~=${ROCM_VERSION}" && \
    # Clean up pip.
    rm --recursive --force /tmp/pip_requirements.txt && \
    pip cache purge

### Prepare Triton repository and compile it:
WORKDIR /triton_dev/triton_default
    # Clone repository:
RUN --mount=type=ssh git clone git@github.com:triton-lang/triton.git . && \
    # Add remotes of interest:
    # git remote add rocm git@github.com:ROCm/triton.git && \
    git remote add "${USER_NAME}" git@github.com:lucas-santos-amd/triton.git && \
    git fetch --all --prune && \
    # Checkout branches of interest:
    git checkout main && \
    # Install pre-commit hooks:
    pre-commit install && \
    # Do a "fake commit" to initialize `pre-commit` framework, it takes some
    # time and it's an annoying process...
    git add $(mktemp --tmpdir=.) && \
    git commit --allow-empty-message --message '' && \
    git reset --hard HEAD~ && \
    # Compile triton
    # cd /triton_dev/triton_default/ && \
    pip install --requirement python/requirements.txt && \
    pip install --verbose --no-build-isolation --editable .

#FIXME setup.py not working
### Prepare AITER repository and install it
WORKDIR /triton_dev/aiter_default
RUN --mount=type=ssh git clone --recursive git@github.com:lucas-santos-amd/aiter.git . && \
    # Add remotes of interest:
    git remote add upstream git@github.com:ROCm/aiter.git && \
    # git fetch --all --prune && \
    # Checkout branches of interest:
    git checkout main && \
    # Install pre-commit hooks:
    chmod +x .githooks/install && \
    ./.githooks/install
    # Install into python:
	# python setup.py develop

### Remove build time SSH stuff:
RUN rm --recursive --force /root/.ssh

### Change USER ownership
RUN chown -R ${USER_NAME}:${GROUP_ID} /triton_dev

### Change USER
# USER ${USER_NAME}

### Entrypoint
WORKDIR /triton_dev
ENTRYPOINT [ "bash" ]
