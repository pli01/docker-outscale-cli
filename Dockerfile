#
# Base image
#
#FROM --platform=linux/amd64 debian:bullseye
FROM --platform=linux/amd64 debian:buster

ARG http_proxy=${http_proxy:-}
ARG https_proxy=${https_proxy:-}
ARG no_proxy=${no_proxy:-}
ARG PYPI_URL=${PYPI_URL:-}
ARG PYPI_HOST=${PYPI_HOST:-}

ARG ANSIBLE_VERSION=${ANSIBLE_VERSION:-2.9.*}
ARG AWS_CLI_VERSION
ARG OSC_CLI_VERSION
ARG S3CMD_VERSION

ARG TERRAFORM_VERSION=${TERRAFORM_VERSION:-1.5.7}
#ARG TERRAFORM_VERSION=${TERRAFORM_VERSION:-1.1.0}
#ARG TERRAFORM_VERSION="0.15.3"

# define packages
ARG DEBIAN_PACKAGES="tzdata keyboard-configuration \
      curl unzip groff less wget vim jq \
      git python3 python-dnspython python3-dnspython python-redis python3-netaddr python3-jmespath \
      python-jmespath python3-cryptography \
      python-pip python3-pip python-setuptools python3-setuptools python3-urllib3 lsb-release \
      ruby"

# Installing prerequisite packages and ansible
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]
RUN . /etc/os-release \
   ; echo "deb http://deb.debian.org/debian ${VERSION_CODENAME}-backports main" > /etc/apt/sources.list.d/${VERSION_CODENAME}-backports.list \
   ; export DEBIAN_FRONTEND="noninteractive" \
   ; apt-get -qqy update \
   && apt-get install -qqy ${DEBIAN_PACKAGES} "ansible${ANSIBLE_VERSION:+=$ANSIBLE_VERSION}" \
   && ansible --version \
   && apt-get autoremove -y && apt-get autoclean -y \
   && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# install terraform version
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]
RUN curl -O https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
    && unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/local/bin/ \
    && mv /usr/local/bin/terraform /usr/local/bin/terraform-${TERRAFORM_VERSION} \
    && ln -sf /usr/local/bin/terraform-${TERRAFORM_VERSION} /usr/local/bin/terraform \
    && rm -rf terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    terraform --version

# install terraform provider
COPY provider.tf .
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]
RUN mkdir -p /usr/local/share/terraform/plugins && \
      echo 'plugin_cache_dir = "/usr/local/share/terraform/plugins"' > $HOME/.terraformrc && \
      terraform init -backend=false

# AWS CLI installation commands
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]
RUN	curl -L "https://awscli.amazonaws.com/awscli-exe-linux-x86_64${AWS_CLI_VERSION:+-$AWS_CLI_VERSION}.zip" -o "awscliv2.zip" \
  && unzip awscliv2.zip \
  && ./aws/install \
  && rm awscliv2.zip \
  && aws --version

# install:
#   s3cmd cli
#   Outscale osc-cli
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]
RUN  pip_args="" ; [ -z "$PYPI_URL" ] || pip_args=" --index-url $PYPI_URL " \
    ; [ -z "$PYPI_HOST" ] || pip_args="$pip_args --trusted-host $PYPI_HOST " \
    ; echo "$no_proxy" |tr ',' '\n' | sort -u |grep "^$PYPI_HOST$" \
    || [ -z "$http_proxy" ] || pip_args="$pip_args --proxy $http_proxy " \
    ; pip3 install "s3cmd${S3CMD_VERSION:+==$S3CMD_VERSION}" \
        "osc-sdk${OSC_CLI_VERSION:+==$OSC_CLI_VERSION}" \
        osc-sdk-python \
        boto \
        boto3 \
    && s3cmd --help \
    && osc-cli -- --help

WORKDIR /data
