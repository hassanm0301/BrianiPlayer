# Download page for the Briani Player clients. Standard library Python only.
# python:3.13-alpine (3.13.16), multi-architecture index digest.
FROM python@sha256:2d9aefe2fef018a7eb2c13064c89c71929800fd2e5dccdbf52ea5da5bb8d929a
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 DOWNLOADS_CACHE=/cache DOWNLOADS_PORT=8089
# A fresh named volume takes this directory's owner, so the unprivileged
# service can write its cache.
RUN mkdir /cache && chown 10001:10001 /cache
COPY server.py page.html /app/
USER 10001:10001
EXPOSE 8089
CMD ["python", "/app/server.py"]
