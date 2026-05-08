#!/bin/bash
set -e

# uv 기반 환경 구성. Python 3.10 + torch 2.3.0 (cu121) + vllm 0.5.0.
# uv가 없으면 자동 설치하고, .venv를 프로젝트 디렉토리 안에 생성합니다.

PYTHON_VERSION="3.10"
VENV_DIR=".venv"

# ── uv 확인/설치 ─────────────────────────────────────────────
ensure_uv() {
    if ! command -v uv &> /dev/null; then
        echo "[INFO] uv가 없어서 설치합니다 ..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.local/bin:$PATH"
    fi
    echo "[OK] uv $(uv --version | awk '{print $2}')"
}

# ── HuggingFace 토큰 ──────────────────────────────────────────
setup_hf() {
    echo ""
    echo "HuggingFace 토큰을 입력하세요 (건너뛰려면 Enter):"
    read -r token
    if [ -n "$token" ]; then
        echo "HF_TOKEN=$token" >> .env
        "$VENV_DIR/bin/huggingface-cli" login --token "$token"
    else
        echo "[SKIP] HuggingFace 토큰 없음"
    fi
}

# ── .venv 생성 (Python 3.10) ─────────────────────────────────
setup_venv() {
    if [ -d "$VENV_DIR" ]; then
        echo "[SKIP] $VENV_DIR 이미 존재합니다."
    else
        echo "Creating $VENV_DIR (Python $PYTHON_VERSION) ..."
        uv venv --python "$PYTHON_VERSION" "$VENV_DIR"
        echo "[OK] $VENV_DIR 생성 완료"
    fi
}

# ── torch (CUDA 12.1) ─────────────────────────────────────────
install_torch() {
    echo "Installing torch==2.3.0 (cu121) ..."
    uv pip install --python "$VENV_DIR/bin/python" \
        torch==2.3.0 \
        --index-url https://download.pytorch.org/whl/cu121
    echo "[OK] torch 설치 완료"
}

# ── vllm (jailbreak 평가용, xformers 등 자동 의존) ────────────
install_vllm() {
    echo "Installing vllm==0.5.0 ..."
    uv pip install --python "$VENV_DIR/bin/python" vllm==0.5.0
    echo "[OK] vllm 설치 완료"
}

# ── 나머지 requirements ────────────────────────────────────────
install_requirements() {
    echo "Installing requirements.txt ..."
    uv pip install --python "$VENV_DIR/bin/python" -r requirements.txt
    # triton이 런타임에 setuptools/wheel을 import 하므로 항상 보장
    uv pip install --python "$VENV_DIR/bin/python" setuptools wheel
    echo "[OK] requirements.txt 설치 완료"
}

# ── 메인 ─────────────────────────────────────────────────────
echo "========================================="
echo " refusal_direction 환경 설정 (uv)"
echo "========================================="

> .env  # .env 초기화

ensure_uv
setup_venv
install_torch
install_vllm
install_requirements
setup_hf

echo ""
echo "========================================="
echo " 설치 완료!"
echo " 실행 방법:"
echo "   source $VENV_DIR/bin/activate"
echo "   python -m pipeline.run_pipeline --model_path <HF_MODEL_ID>"
echo "========================================="
