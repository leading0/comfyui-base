[![Watch the video](https://i3.ytimg.com/vi/JovhfHhxqdM/hqdefault.jpg)](https://www.youtube.com/watch?v=JovhfHhxqdM)

Run the latest ComfyUI with CUDA 12.8. All dependencies are pre-installed in the image. On first boot, ComfyUI is copied to your workspace — when you see `[ComfyUI-Manager] All startup tasks have been completed.` in the logs, it's ready to use.

> **This template is for CUDA 12 only.** It does not support CUDA 13 (Blackwell / RTX 5090).
> If you need CUDA 13, use our [ComfyUI CUDA 13 template](https://console.runpod.io/hub/template/comfyui-cuda-13?id=2lv7ev3wfp) instead.

## Upgrading from a previous version

If you have an existing pod created with an older version of this template (CUDA 12.4), a one-time migration is performed automatically on the next boot. ComfyUI and the bundled custom nodes are updated to the versions pinned by the image, while models, inputs, outputs, user settings, and user-installed custom nodes are preserved. The virtual environment is also migrated to CUDA 12.8 compatibility. This may take a few extra minutes on the first start after the update.

## Security: nginx Reverse Proxy with HTTP Basic Auth

This fork places **nginx in front of ComfyUI and FileBrowser** with HTTP Basic Auth. Backend services are no longer directly reachable through Runpod's public HTTP proxy.

### Architecture

```
Internet → RunPod proxy → nginx (auth) → ComfyUI (127.0.0.1:8189)
                         → nginx (auth) → FileBrowser (127.0.0.1:8081)
```

- **Port 8188** → nginx → ComfyUI (127.0.0.1:8189), protected by Basic Auth
- **Port 8080** → nginx → FileBrowser (127.0.0.1:8081), protected by Basic Auth
- **Port 22** → SSH (unchanged)
- **Port 8888** → JupyterLab (127.0.0.1:8888, internal only, not exposed)
- Backend ports 8189 and 8081 are **not** exposed through the Runpod template

### Required Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `WEB_PASSWORD` | **Yes** | — | Password for HTTP Basic Auth (nginx). Startup fails if missing. |
| `WEB_USERNAME` | No | `admin` | Username for HTTP Basic Auth. |
| `FILEBROWSER_PASSWORD` | No | `adminadmin12` | FileBrowser app-level admin password (separate from nginx auth). |
| `JUPYTER_PASSWORD` | No | (empty) | JupyterLab token. Jupyter is internal-only; set if you tunnel to it via SSH. |
| `PUBLIC_KEY` | No | (random) | SSH public key for root login. If unset, a random password is generated. |

Credentials are **not** baked into the image. The nginx htpasswd file is generated at container startup from `WEB_USERNAME` and `WEB_PASSWORD`.

### Example RunPod Template Configuration

In your Runpod template settings, set the following environment variables:

```json
{
  "WEB_USERNAME": "admin",
  "WEB_PASSWORD": "your-secure-password-here",
  "FILEBROWSER_PASSWORD": "your-filebrowser-password",
  "JUPYTER_PASSWORD": "your-jupyter-token",
  "PUBLIC_KEY": "ssh-ed25519 AAAA..."
}
```

Expose only these HTTP ports in the template: **8188** and **8080**. Do not expose 8189, 8081, or 8888.

### Building

This fork builds **on top of the pre-built upstream image** (`runpod/comfyui:latest`), adding only the nginx authentication layer. No CUDA/PyTorch/ComfyUI rebuild is needed — the build takes seconds:

```bash
docker build -t comfyui-nginx .
docker run --gpus all -e WEB_PASSWORD=secret -p 8188:8188 -p 8080:8080 comfyui-nginx
```

To use a specific upstream tag instead of `latest`, change the `FROM` line in `Dockerfile` (e.g. `runpod/comfyui:cuda13.0`).

## Access

- `8188`: ComfyUI web UI (Basic Auth: `WEB_USERNAME` / `WEB_PASSWORD`)
- `8080`: FileBrowser (Basic Auth: `WEB_USERNAME` / `WEB_PASSWORD`, then FileBrowser login: admin / `FILEBROWSER_PASSWORD`)
- `8888`: JupyterLab — **internal only** (binds to 127.0.0.1); access via SSH tunnel: `ssh -L 8888:127.0.0.1:8888 root@<pod-ip>`
- `22`: SSH (set `PUBLIC_KEY` or check logs for generated root password)

## Pre-installed custom nodes

- ComfyUI-Manager
- ComfyUI-KJNodes
- Civicomfy
- ComfyUI-RunpodDirect

## Source Code

This is a fork of [runpod-workers/comfyui-base](https://github.com/runpod-workers/comfyui-base) with nginx Basic Auth added.

## Custom Arguments

Edit `/workspace/runpod-slim/comfyui_args.txt` (one arg per line):

```
--max-batch-size 8
--preview-method auto
```

## Directory Structure

- `/workspace/runpod-slim/ComfyUI`: ComfyUI install
- `/workspace/runpod-slim/comfyui_args.txt`: ComfyUI args
- `/workspace/runpod-slim/filebrowser.db`: FileBrowser DB
- `/etc/nginx/nginx.conf`: nginx reverse proxy config
- `/etc/nginx/.htpasswd`: Generated at startup (not baked into image)