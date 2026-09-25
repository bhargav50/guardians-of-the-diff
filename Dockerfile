FROM ghcr.io/anomalyco/opencode:2.0.15

USER root

# The upstream image is Alpine and intentionally minimal. Git makes the fixture
# a real disposable repository; bash gives the TUI's shell tool a familiar shell.
# Node/npm are used only to install the plugin SDK version matching OpenCode.
RUN apk add --no-cache bash git nodejs npm

COPY fixture-seed/ /opt/fixture-seed/
COPY src/ /opt/fixture-seed/.opencode/guardians-src/
COPY scripts/container-entrypoint.sh /usr/local/bin/sandbox-entrypoint

RUN npm install --prefix /opt/fixture-seed/.opencode --omit=dev --ignore-scripts \
    && npm cache clean --force \
    && chmod 0755 /usr/local/bin/sandbox-entrypoint \
    && mkdir -p /workspace/fixture /workspace/audit /credential-snapshot \
    && chmod 0777 /workspace/fixture /workspace/audit

ENV HOME=/root \
    TERM=xterm-256color \
    OPENCODE_PERMISSION_AUDIT=/workspace/audit/permission-evaluator.jsonl \
    OPENCODE_EVALUATOR_MODEL=openai/gpt-5.5-fast \
    OPENCODE_EVALUATOR_TIMEOUT_MS=20000

WORKDIR /workspace/fixture

ENTRYPOINT ["/usr/local/bin/sandbox-entrypoint"]
CMD ["/workspace/fixture"]
