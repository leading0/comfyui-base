# ============================================================================
# nginx-auth layer for runpod/comfyui
#
# Builds ON TOP of the pre-built upstream image (runpod/comfyui:latest),
# adding only nginx + HTTP Basic Auth. No CUDA/PyTorch/ComfyUI rebuild.
#
# Usage:
#   docker build -t comfyui-nginx .
#   docker run --gpus all -e WEB_PASSWORD=secret -p 8188:8188 -p 8080:8080 comfyui-nginx
# ============================================================================

FROM runpod/comfyui:latest

ENV DEBIAN_FRONTEND=noninteractive

# Install nginx and htpasswd utility
RUN apt-get update && \
    apt-get install -y --no-install-recommends nginx apache2-utils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy nginx reverse proxy config
COPY nginx/nginx.conf /etc/nginx/nginx.conf

# Override start script with auth-aware version
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Expose only nginx-facing ports + SSH.
# Backend services (ComfyUI 8189, FileBrowser 8081, Jupyter 8888)
# are bound to 127.0.0.1 and never exposed.
EXPOSE 8188 22 8080