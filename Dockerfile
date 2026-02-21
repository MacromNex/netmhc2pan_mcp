FROM python:3.10-slim

# Install system dependencies (tcsh required by NetMHCIIpan wrapper script)
RUN apt-get update && apt-get install -y \
    tcsh \
    gawk \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies
RUN pip install --no-cache-dir \
    fastmcp loguru click pandas numpy tqdm openpyxl
RUN pip install --no-cache-dir --ignore-installed fastmcp

# Extract NetMHCIIpan binary distribution if tarball is present
# Note: The tarball is gitignored, so it's only available in local builds
# GitHub Actions and CI/CD builds without the tarball will proceed without NetMHCIIpan
RUN mkdir -p repo && \
    if [ -f repo/netMHCIIpan-4.3istatic.Linux.tar.gz ]; then \
      echo "Installing NetMHCIIpan from local tarball"; \
      tar -xzf repo/netMHCIIpan-4.3istatic.Linux.tar.gz -C repo/ && \
      sed -i 's|setenv\tNMHOME\t.*|setenv\tNMHOME\t/app/repo/netMHCIIpan-4.3|' \
          repo/netMHCIIpan-4.3/netMHCIIpan && \
      chmod +x repo/netMHCIIpan-4.3/netMHCIIpan && \
      chmod +x repo/netMHCIIpan-4.3/Linux_x86_64/bin/*; \
    else \
      echo "WARNING: NetMHCIIpan tarball not found in repo/"; \
      echo "For local builds: place netMHCIIpan-4.3istatic.Linux.tar.gz in repo/"; \
      echo "For GitHub Actions: configure build artifact or external storage"; \
    fi

# Copy application source
COPY src/ ./src/
RUN chmod -R a+r /app/src/
COPY scripts/ ./scripts/
RUN chmod -R a+r /app/scripts/
COPY configs/ ./configs/
RUN chmod -R a+r /app/configs/

# Create directories for jobs and tmp
RUN mkdir -p jobs tmp

# Create env/bin symlink so the job manager's "mamba run -p ./env python"
# path resolves without mamba. Also create a mamba shim that just runs the
# command directly (skipping "mamba run -p ./env").
RUN mkdir -p /app/env/bin && \
    ln -s /usr/local/bin/python /app/env/bin/python && \
    ln -s /usr/local/bin/pip /app/env/bin/pip && \
    printf '#!/bin/sh\n# mamba shim for Docker: skip "run -p <env>" and exec the rest\nshift; shift; shift; exec "$@"\n' > /usr/local/bin/mamba && \
    chmod +x /usr/local/bin/mamba

ENV PYTHONPATH=/app

CMD ["python", "src/server.py"]
