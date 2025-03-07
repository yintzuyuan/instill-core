ARG ALPINE_VERSION=3.18

FROM golang:alpine${ALPINE_VERSION} AS base

RUN apk add --no-cache docker docker-compose docker-cli-compose docker-cli-buildx openrc containerd git bash make wget vim curl openssl util-linux pcre2 && \
    rm -rf /var/cache/apk/*

# 安裝 xk6 和 k6
RUN git clone https://github.com/grafana/xk6.git /xk6 && \
    cd /xk6 && \
    go install ./cmd/xk6 && \
    xk6 build v0.49.0 \
    --with github.com/grafana/xk6-sql@v0.1.0 \
    --with github.com/grafana/xk6-sql-driver-postgres@v0.1.0 \
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

# 安裝必要的庫和 git
RUN apk add --no-cache git pcre2 && \
    rm -rf /var/cache/apk/*

# 複製必要檔案
COPY --from=base /usr/bin/docker* /usr/bin/
COPY --from=base /usr/bin/k6 /usr/bin/
COPY --from=base /usr/local/bin/ /usr/local/bin/

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

# 安裝必要的庫和 git
RUN apk add --no-cache git pcre2 bash && \
    rm -rf /var/cache/apk/*

# 複製必要檔案
COPY --from=base /usr/bin/docker* /usr/bin/
COPY --from=base /usr/bin/k6 /usr/bin/
COPY --from=base /usr/local/bin/ /usr/local/bin/

ARG CACHE_DATE
# 為版本變數提供預設值
ARG API_GATEWAY_VERSION=""
ARG MGMT_BACKEND_VERSION=""
ARG CONSOLE_VERSION=""
ARG PIPELINE_BACKEND_VERSION=""
ARG MODEL_BACKEND_VERSION=""
ARG ARTIFACT_BACKEND_VERSION=""

RUN echo "Instill Core release codebase cloned on ${CACHE_DATE}"

WORKDIR /instill-core

# 使用 bash 腳本來處理有或沒有版本變數的情況
RUN bash -c 'clone_repo() { \
      REPO=$1; \
      VERSION=$2; \
      if [ -z "$VERSION" ]; then \
        echo "Cloning latest for $REPO"; \
        git clone --depth=1 https://github.com/instill-ai/$REPO.git; \
      else \
        echo "Cloning version v$VERSION for $REPO"; \
        git clone --depth=1 -b v$VERSION -c advice.detachedHead=false https://github.com/instill-ai/$REPO.git || \
        { echo "Branch v$VERSION not found for $REPO, falling back to main"; \
          git clone --depth=1 https://github.com/instill-ai/$REPO.git; \
        }; \
      fi; \
    }; \
    \
    clone_repo "api-gateway" "${API_GATEWAY_VERSION}"; \
    clone_repo "mgmt-backend" "${MGMT_BACKEND_VERSION}"; \
    clone_repo "console" "${CONSOLE_VERSION}"; \
    clone_repo "pipeline-backend" "${PIPELINE_BACKEND_VERSION}"; \
    clone_repo "model-backend" "${MODEL_BACKEND_VERSION}"; \
    clone_repo "artifact-backend" "${ARTIFACT_BACKEND_VERSION}"; \
    '

# 設定一個預設的 CMD
CMD ["/bin/sh"]
