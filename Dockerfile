# 在頂層定義所有 ARG 變數
ARG ALPINE_VERSION=3.18
ARG K6_VERSION=0.49.0
ARG XK6_SQL_VERSION=0.1.0
ARG XK6_SQL_POSTGRES_VERSION=0.1.0
ARG API_GATEWAY_VERSION
ARG MGMT_BACKEND_VERSION
ARG CONSOLE_VERSION
ARG PIPELINE_BACKEND_VERSION
ARG MODEL_BACKEND_VERSION
ARG ARTIFACT_BACKEND_VERSION
ARG CONTROLLER_MODEL_VERSION

FROM golang:alpine${ALPINE_VERSION} AS base

RUN apk add --no-cache docker docker-compose docker-cli-compose docker-cli-buildx openrc containerd git bash make wget vim curl openssl util-linux && \
    rm -rf /var/cache/apk/*

# 安裝 xk6 和 k6
RUN git clone https://github.com/grafana/xk6.git /xk6 && \
    cd /xk6 && \
    go install ./cmd/xk6 && \
    xk6 build v${K6_VERSION} \
    --with github.com/grafana/xk6-sql@v${XK6_SQL_VERSION} \
    --with github.com/grafana/xk6-sql-driver-postgres@v${XK6_SQL_POSTGRES_VERSION} \
    --output /usr/bin/k6 && \
    rm -rf /xk6

# 安裝 Helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 安裝 Kubectl
ARG TARGETARCH
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/${TARGETARCH}/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin

FROM alpine:${ALPINE_VERSION} AS latest

# 只複製必要的檔案
COPY --from=base /usr/bin/ /usr/bin/
COPY --from=base /usr/local/bin/ /usr/local/bin/
COPY --from=base /lib/ /lib/
COPY --from=docker:dind /usr/local/bin/ /usr/local/bin/

ARG CACHE_DATE
RUN echo "Instill Core latest codebase cloned on ${CACHE_DATE}"

WORKDIR /instill-core

RUN git clone --depth=1 https://github.com/instill-ai/artifact-backend.git && \
    git clone --depth=1 https://github.com/instill-ai/api-gateway.git && \
    git clone --depth=1 https://github.com/instill-ai/mgmt-backend.git && \
    git clone --depth=1 https://github.com/instill-ai/console.git && \
    git clone --depth=1 https://github.com/instill-ai/pipeline-backend.git && \
    git clone --depth=1 https://github.com/instill-ai/model-backend.git

FROM alpine:${ALPINE_VERSION} AS release

# 只複製必要的檔案
COPY --from=base /usr/bin/ /usr/bin/
COPY --from=base /usr/local/bin/ /usr/local/bin/
COPY --from=base /lib/ /lib/
COPY --from=docker:dind /usr/local/bin/ /usr/local/bin/

ARG CACHE_DATE
ARG API_GATEWAY_VERSION
ARG MGMT_BACKEND_VERSION
ARG CONSOLE_VERSION
ARG PIPELINE_BACKEND_VERSION
ARG MODEL_BACKEND_VERSION
ARG ARTIFACT_BACKEND_VERSION
ARG CONTROLLER_MODEL_VERSION

RUN echo "Instill Core release codebase cloned on ${CACHE_DATE}"

WORKDIR /instill-core

RUN git clone --depth=1 -b v${API_GATEWAY_VERSION} -c advice.detachedHead=false https://github.com/instill-ai/api-gateway.git && \
    git clone --depth=1 -b v${MGMT_BACKEND_VERSION} -c advice.detachedHead=false https://github.com/instill-ai/mgmt-backend.git && \
    git clone --depth=1 -b v${CONSOLE_VERSION} -c advice.detachedHead=false https://github.com/instill-ai/console.git && \
    git clone --depth=1 -b v${PIPELINE_BACKEND_VERSION} -c advice.detachedHead=false https://github.com/instill-ai/pipeline-backend.git && \
    git clone --depth=1 -b v${MODEL_BACKEND_VERSION} -c advice.detachedHead=false https://github.com/instill-ai/model-backend.git && \
    git clone --depth=1 -b v${ARTIFACT_BACKEND_VERSION} -c advice.detachedHead=false https://github.com/instill-ai/artifact-backend.git

# 設定一個預設的 CMD 或 ENTRYPOINT
CMD ["/bin/sh"]
