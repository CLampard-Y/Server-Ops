#!/usr/bin/env bash
# ===========================================================
#  Server-Ops — Layer 4: Dev Environment installer
#
#  Usage:
#    bash /home/Server-Ops/layer4_dev_env/install_dev_env.sh hk-dev
#    bash /home/Server-Ops/layer4_dev_env/install_dev_env.sh us-compute
#    bash /home/Server-Ops/layer4_dev_env/install_dev_env.sh minimal
#
#  Layer 4 is user-scoped. Run as the same user used by VS Code
#  Remote-SSH. It installs tools under $HOME and never writes API keys.
# ===========================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE="${1:-}"

# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
    cat <<EOF
Usage: bash ${0} <profile>

Profiles:
  hk-dev      Full HK development workstation: Codex, cc-switch-cli, Foundry, Rust, uv, Python venv.
  us-compute  US compute runner: Foundry, Rust, Node, uv, Python venv. AI tools disabled by default.
  minimal     Minimal jump/dev shell directories and PATH block only.

Environment overrides:
  NODE_VERSION=22
  INSTALL_CODEX_CLI=1       Enable Codex on us-compute if needed.
  INSTALL_CC_SWITCH_CLI=1   Enable cc-switch-cli on us-compute if needed.
  INSTALL_ZK_TOOLS=1        Install Circom, circomlib, and snarkjs.
  PYTHON_SCIENCE_VENV_DIR   Default: ~/code/.venvs/moonmath.
  CIRCOM_GIT_REF_TYPE=tag   tag, rev, or branch. Default: tag.
  CIRCOM_GIT_REF=v2.2.3     Default pinned Circom Git ref.
EOF
}

if [[ -z "${PROFILE}" || "${PROFILE}" == "-h" || "${PROFILE}" == "--help" ]]; then
    usage
    exit 0
fi

case "${PROFILE}" in
    hk-dev|us-compute|minimal) ;;
    *) error "未知 profile: ${PROFILE}" ;;
esac

PROFILE_FILE="${SCRIPT_DIR}/profiles/${PROFILE}.sh"
[[ -f "${PROFILE_FILE}" ]] || error "未知 profile: ${PROFILE} (${PROFILE_FILE})"

# shellcheck source=/dev/null
source "${PROFILE_FILE}"

# Defaults for values not set by the selected profile.
: "${INSTALL_USER_DIRS:=0}"
: "${INSTALL_SHELL_PROFILE:=0}"
: "${INSTALL_NODE_FNM:=0}"
: "${INSTALL_CODEX_CLI:=0}"
: "${INSTALL_CC_SWITCH_CLI:=0}"
: "${INSTALL_FOUNDRY:=0}"
: "${INSTALL_RUST:=0}"
: "${INSTALL_PYTHON_UV:=0}"
: "${INSTALL_ZK_TOOLS:=0}"
: "${INSTALL_REMOTE_COMPUTE:=0}"
: "${NODE_VERSION:=22}"

for module in "${SCRIPT_DIR}"/modules/[0-9]*.sh; do
    # shellcheck source=/dev/null
    source "${module}"
done

run_if_enabled() {
    local enabled="$1"
    local function_name="$2"
    if [[ "${enabled}" == "1" ]]; then
        "${function_name}"
    else
        warn "跳过 ${function_name}"
    fi
}

main() {
    ensure_user_mode

    banner "Layer 4: Dev Environment (${PROFILE_NAME:-${PROFILE}})"
    echo "  User:       $(whoami)"
    echo "  HOME:       ${HOME}"
    echo "  Node:       ${NODE_VERSION:-disabled}"
    echo ""

    run_if_enabled "${INSTALL_USER_DIRS}" run_01_user_dirs
    run_if_enabled "${INSTALL_SHELL_PROFILE}" run_02_shell_profile
    run_if_enabled "${INSTALL_NODE_FNM}" run_03_node_fnm
    run_if_enabled "${INSTALL_CODEX_CLI}" run_04_ai_coding_tools
    run_if_enabled "${INSTALL_CC_SWITCH_CLI}" run_05_cc_switch_cli
    run_if_enabled "${INSTALL_FOUNDRY}" run_06_foundry
    run_if_enabled "${INSTALL_RUST}" run_07_rust
    run_if_enabled "${INSTALL_PYTHON_UV}" run_08_python_uv
    run_if_enabled "${INSTALL_ZK_TOOLS}" run_09_zk_tools
    run_if_enabled "${INSTALL_REMOTE_COMPUTE}" run_10_remote_compute

    echo ""
    info "Layer 4 完成。请执行: source ~/.bashrc"
    echo ""
    echo "Next steps:"
    if [[ "${INSTALL_CC_SWITCH_CLI}" == "1" ]]; then
        echo "  cc-switch env tools"
        echo "  cc-switch --app codex provider add"
        echo "  cc-switch --app codex provider switch <id>"
    fi
    if [[ "${INSTALL_CODEX_CLI}" == "1" ]]; then
        echo "  codex --help"
    fi
    if [[ "${INSTALL_PYTHON_UV}" == "1" ]]; then
        echo "  source ${PYTHON_SCIENCE_VENV_DIR:-${HOME}/code/.venvs/moonmath}/bin/activate"
    fi
    if [[ "${INSTALL_ZK_TOOLS}" == "1" ]]; then
        echo "  circom --version"
        echo "  snarkjs --version"
    fi
}

main "$@"
