#!/usr/bin/env bash
set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# pi-mono run.sh — Self-documenting CLI for humans & agents
# Usage:
#   ./run.sh              → Interactive menu
#   ./run.sh <command>    → Direct execution (agent-friendly)
#   ./run.sh help         → Show all commands
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Project root (where this script lives)
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Helper functions
info()    { echo -e "${BLUE}ℹ ${NC}$1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn()    { echo -e "${YELLOW}⚠${NC} $1"; }
error()   { echo -e "${RED}✗${NC} $1"; }
header()  { echo -e "\n${BOLD}${CYAN}$1${NC}"; }

# Run a command with logging
run_cmd() {
    local cmd="$1"
    echo ""
    info "실행: ${DIM}${cmd}${NC}"
    echo ""
    eval "$cmd"
    local status=$?
    echo ""
    if [[ $status -eq 0 ]]; then
        success "완료!"
    else
        error "실패 (exit code: $status)"
    fi
    return $status
}

# Ensure we're in project root
ensure_project_dir() {
    cd "$PROJECT_DIR"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# COMMANDS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

cmd_install() {
    # DESC: npm 의존성 설치
    ensure_project_dir
    run_cmd "npm install --no-audit --no-fund"
}

cmd_build() {
    # DESC: 전체 패키지 빌드
    ensure_project_dir
    run_cmd "npm run build"
}

cmd_build_agent() {
    # DESC: coding-agent 패키지만 빌드
    ensure_project_dir
    run_cmd "cd packages/coding-agent && npm run build"
}

cmd_check() {
    # DESC: Biome lint + TypeScript 타입 체크
    ensure_project_dir
    run_cmd "npm run check"
}

cmd_test_lock() {
    # DESC: lockSync retry 테스트 (settings-manager)
    ensure_project_dir
    run_cmd "cd packages/coding-agent && npx vitest run test/settings-manager.test.ts"
}

cmd_test_agent() {
    # DESC: coding-agent 테스트만 실행
    ensure_project_dir
    run_cmd "cd packages/coding-agent && npm test"
}

cmd_pi_link() {
    # DESC: 로컬 빌드된 pi를 ~/.local/bin/pi로 링크
    ensure_project_dir
    local target="$HOME/.local/bin/pi"
    local cli_js="${PROJECT_DIR}/packages/coding-agent/dist/cli.js"

    if [[ ! -f "$cli_js" ]]; then
        error "빌드가 필요합니다: ./run.sh build"
        return 1
    fi

    mkdir -p "$(dirname "$target")"

    if [[ -f "$target" && ! -L "$target" ]]; then
        warn "기존 $target 를 ${target}.bak 으로 백업"
        cp "$target" "${target}.bak"
    fi

    cat > "$target" << EOF
#!/bin/sh
exec node "${cli_js}" "\$@"
EOF
    chmod +x "$target"
    success "링크 완료: $target → 로컬 빌드"
    info "확인: pi --version"
    pi --version 2>/dev/null || true
}

cmd_pi_unlink() {
    # DESC: 로컬 pi 링크 해제, pnpm 글로벌 pi 복원
    local target="$HOME/.local/bin/pi"

    if [[ -f "${target}.bak" ]]; then
        mv "${target}.bak" "$target"
        success "pnpm 글로벌 pi 복원됨"
    elif [[ -f "$target" ]]; then
        rm "$target"
        success "$target 제거됨"
    else
        warn "$target 가 없습니다"
    fi
}

cmd_pi_version() {
    # DESC: 현재 pi 버전 및 경로 확인
    ensure_project_dir
    echo ""
    info "패키지 버전:"
    node -e "console.log(require('./packages/coding-agent/package.json').version)"
    echo ""
    info "설치된 pi:"
    which pi 2>/dev/null && pi --version 2>/dev/null || warn "pi가 PATH에 없습니다"
}

cmd_env_check() {
    # DESC: 개발 환경 상태 점검
    ensure_project_dir
    header "환경 점검"

    echo -e "\n${BOLD}[Node.js]${NC}"
    command -v node &>/dev/null && success "node: $(node --version)" || error "node: 없음"

    echo -e "\n${BOLD}[Nix]${NC}"
    [[ -f "${PROJECT_DIR}/flake.nix" ]] && success "flake.nix: 존재" || warn "flake.nix: 없음"

    echo -e "\n${BOLD}[Dependencies]${NC}"
    [[ -d "${PROJECT_DIR}/node_modules" ]] && success "node_modules: 설치됨" || warn "node_modules: 없음"

    echo -e "\n${BOLD}[Build]${NC}"
    [[ -d "${PROJECT_DIR}/packages/coding-agent/dist" ]] && success "coding-agent dist: 빌드됨" || warn "dist: 없음"
    echo ""
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DISPATCH
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

COMMANDS=(
    "install:cmd_install"
    "build:cmd_build"
    "build-agent:cmd_build_agent"
    "check:cmd_check"
    "test-lock:cmd_test_lock"
    "test-agent:cmd_test_agent"
    "pi-link:cmd_pi_link"
    "pi-unlink:cmd_pi_unlink"
    "pi-version:cmd_pi_version"
    "env-check:cmd_env_check"
)

show_help() {
    echo ""
    echo -e "${BOLD}pi-mono run.sh${NC}"
    echo ""
    for entry in "${COMMANDS[@]}"; do
        local cmd_name="${entry%%:*}"
        local func_name="${entry#*:}"
        local desc
        desc=$(sed -n "/^${func_name}()/,/^}/p" "$0" | grep -m1 "# DESC:" | sed 's/.*# DESC: *//')
        printf "  %-18s %s\n" "$cmd_name" "${desc:-}"
    done
    echo ""
}

main() {
    if [[ $# -eq 0 || "$1" == "help" || "$1" == "--help" ]]; then
        show_help
        exit 0
    fi

    local cmd="$1"; shift
    for entry in "${COMMANDS[@]}"; do
        local cmd_name="${entry%%:*}"
        local func_name="${entry#*:}"
        if [[ "$cmd_name" == "$cmd" ]]; then
            "$func_name" "$@"
            exit $?
        fi
    done

    error "알 수 없는 명령어: $cmd"
    show_help
    exit 1
}

main "$@"
