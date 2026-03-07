# ╔══════════════════════════════════════════════════════════════╗
# ║  ChessRecast AI Trainer - Universal Dockerfile               ║
# ║  PyTorch + CUDA 12.1 for RTX 4080 GPU training               ║
# ║                                                              ║
# ║  Usage: Build args are provided via docker-compose.yml       ║
# ║    TRAIN_SCRIPT  - Python script to run (required)           ║
# ║    TRAIN_ARGS    - Extra CLI arguments (optional)            ║
# ╚══════════════════════════════════════════════════════════════╝
FROM pytorch/pytorch:2.1.0-cuda12.1-cudnn8-runtime

# Build arguments (passed from docker-compose)
ARG TRAIN_SCRIPT=mods/train_mercenary.py
ARG TRAIN_ARGS=""

# Persist as env vars so CMD/entrypoint can use them at runtime
ENV TRAIN_SCRIPT=${TRAIN_SCRIPT}
ENV TRAIN_ARGS=${TRAIN_ARGS}

# Install Python dependencies (pure PyTorch stack)
RUN pip install --no-cache-dir \
    python-chess>=1.999 \
    numpy>=1.24.0 \
    tqdm>=4.65.0 \
    websockets>=12.0

# Working directory (overridden by volume mount in compose)
WORKDIR /workspace

# Default: run the specified training script
# docker-compose 'command:' overrides this for test mode / custom args
CMD python ${TRAIN_SCRIPT} ${TRAIN_ARGS}
