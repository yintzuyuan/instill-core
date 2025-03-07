ARG ALPINE_VERSION=3.18
FROM golang:alpine${ALPINE_VERSION} AS base

RUN apk add --update docker docker-compose docker-cli-compose docker-cli-buildx openrc containerd git bash make wget vim curl openssl util-linux

ARG K6_VERSION XK6_VERSION XK6_SQL_VERSION XK6_SQL_POSTGRES_VERSION
# 安裝依賴
RUN apt-get update && apt-get install -y git

# 下載 xk6 原始碼
RUN git clone https://github.com/grafana/xk6.git /xk6 && \
    cd /xk6 && \
    go install ./cmd/xk6
    
RUN xk6 build v${K6_VERSION} \
  --with github.com/grafana/xk6-sql@v${XK6_SQL_VERSION} \
  --with github.com/grafana/xk6-sql-driver-postgres@v${XK6_SQL_POSTGRES_VERSION} \
  --output /usr/bin/k6

# Install Helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Kubectl
ARG TARGETARCH
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/${TARGETARCH}/kubectl
RUN chmod +x ./kubectl
RUN mv ./kubectl /usr/local/bin

FROM alpine:${ALPINE_VERSION} AS latest

COPY --from=base /etc /etc
COPY --from=base /usr /usr
COPY --from=base /lib /lib
COPY --from=docker:dind /usr/local/bin /usr/local/bin

ARG CACHE_DATE
RUN echo "Instill Core latest codebase cloned on ${CACHE_DATE}"

WORKDIR /instill-core

ARG CONTROLLER_MODEL_VERSION
RUN git clone --depth=1 https://github.com/instill-ai/artifact-backend.git
RUN git clone --depth=1 https://github.com/instill-ai/api-gateway.git
RUN git clone --depth=1 https://github.com/instill-ai/mgmt-backend.git
RUN git clone --depth=1 https://github.com/instill-ai/console.git
RUN git clone --depth=1 https://github.com/instill-ai/pipeline-backend.git
RUN git clone --depth=1 https://github.com/instill-ai/model-backend.git

FROM alpine:${ALPINE_VERSION} AS release

COPY --from=base /etc /etc
COPY --from=base /usr /usr
COPY --from=base /lib /lib
COPY --from=docker:dind /usr/local/bin /usr/local/bin

ARG CACHE_DATE
RUN echo "Instill Core release codebase cloned on ${CACHE_DATE}"

WORKDIR /instill-core

ARG API_GATEWAY_VERSION MGMT_BACKEND_VERSION CONSOLE_VERSION PIPELINE_BACKEND_VERSION MODEL_BACKEND_VERSION ARTIFACT_BACKEND_VERSION CONTROLLER_MODEL_VERSION
RUN git clone --depth=1 -b v${API_GATEWAY_VERSION} -c advice.detachedHead=false https://github.com/instill-ai/api-gateway.git
RUN git clone --depth=1 -b v${MGMT_BACKEND_VERSION} -c advice.detachedHead=false https://github.com/instill-ai/mgmt-backend.git
RUN git clone --depth=1 -b v${CONSOLE_VERSION} -c advice.detachedHead=false https://github.com/instill-ai/console.git
RUN git clone --depth=1 -b v${PIPELINE_BACKEND_VERSION} -c advice.detachedHead=false https://github.com/instill-ai/pipeline-backend.git
RUN git clone --depth=1 -b v${MODEL_BACKEND_VERSION} -c advice.detachedHead=false https://github.com/instill-ai/model-backend.git
RUN git clone --depth=1 -b v${ARTIFACT_BACKEND_VERSION} -c advice.detachedHead=false https://github.com/instill-ai/artifact-backend.git
