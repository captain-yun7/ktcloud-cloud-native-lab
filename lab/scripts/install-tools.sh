#!/usr/bin/env bash
# 고정 버전 도구 설치 (Ubuntu 셸 기준: WSL2 / Lima / 서버 VM 동일)
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v mise >/dev/null; then
  curl -fsSL https://mise.run | sh
  echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
  export PATH="$HOME/.local/bin:$PATH"
fi
mise trust -q .mise.toml 2>/dev/null || true
mise install -y
# 어느 폴더에서나 쓰도록 같은 버전을 전역 기본값으로 지정 (lab 폴더 밖에서 "No version is set for shim" 방지)
mise use -g -y $(awk -F' *= *' '/^[a-z]/{gsub(/"/,"",$2); printf "%s@%s ", $1, $2}' .mise.toml) >/dev/null
echo "설치된 버전:"; mise ls --current 2>/dev/null | sed 's/^/  /'
echo "새 터미널을 열거나 'source ~/.bashrc' 후 사용하세요."
