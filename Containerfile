FROM alpine:latest
RUN apk add --no-cache nodejs npm git curl bash ca-certificates \
    && npm install -g @anthropic-ai/claude-code \
    && npm cache clean --force
RUN adduser -D -u 501 -h /home/claudeuser -s /bin/sh claudeuser
USER claudeuser
WORKDIR /home/claudeuser
ENV HOME=/home/claudeuser
ENTRYPOINT ["claude", "--dangerously-skip-permissions"]
