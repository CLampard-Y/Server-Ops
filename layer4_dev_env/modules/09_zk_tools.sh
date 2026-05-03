#!/usr/bin/env bash
# ===========================================================
#  Module 09: ZK tools baseline
# ===========================================================

_layer4_npm_global_package_installed() {
    local package="$1"
    npm list -g --depth=0 "${package}" >/dev/null 2>&1
}

run_09_zk_tools() {
    step "9/10" "安装 ZK 基础工具"

    warn "ZK 工具链版本敏感。本模块安装 Circom/circomlib/snarkjs；Noir/BB/Risc0/SP1 后续按课程阶段 pin 版本。"

    export CARGO_HOME="${CARGO_HOME:-${HOME}/.cargo}"
    require_home_path "${CARGO_HOME}" "CARGO_HOME"

    local cargo_root
    cargo_root="${CARGO_INSTALL_ROOT:-${CARGO_HOME}}"
    require_home_path "${cargo_root}" "CARGO_INSTALL_ROOT"

    export PATH="${cargo_root}/bin:${CARGO_HOME}/bin:${HOME}/.local/bin:${PATH}"

    require_command cargo
    if ! command_in_home cargo; then
        warn "检测到非用户级 cargo: $(command_path cargo)。将强制 cargo install --root 写入 HOME 下。"
    fi

    ensure_npm_user_scoped

    local circom_git_url circom_git_ref circom_git_ref_type
    circom_git_url="${CIRCOM_GIT_URL:-https://github.com/iden3/circom.git}"
    circom_git_ref="${CIRCOM_GIT_REF:-${CIRCOM_GIT_REV:-v2.2.3}}"
    circom_git_ref_type="${CIRCOM_GIT_REF_TYPE:-tag}"

    local install_circom=0
    if command_in_home circom && [[ "${INSTALL_ZK_FORCE:-0}" != "1" ]]; then
        local circom_current_version
        circom_current_version="$(circom --version 2>/dev/null || echo installed)"
        info "circom 已存在: ${circom_current_version}"

        if [[ "${circom_git_ref_type}" == "tag" && "${circom_git_ref}" == v* ]]; then
            local circom_expected_version
            circom_expected_version="${circom_git_ref#v}"
            if [[ "${circom_current_version}" != *"${circom_expected_version}"* ]]; then
                error "circom 版本不匹配，期望 ${circom_expected_version}，当前: ${circom_current_version}。如需重装请设置 INSTALL_ZK_FORCE=1。"
            fi
        fi
    else
        install_circom=1
        if command_exists circom; then
            warn "检测到非用户级 circom: $(command_path circom)，将通过 cargo 安装到 HOME 下"
        fi
    fi

    if [[ "${install_circom}" == "1" ]]; then
        info "安装 circom: ${circom_git_url} (${circom_git_ref_type}: ${circom_git_ref})"
        case "${circom_git_ref_type}" in
            tag)
                cargo install --force --root "${cargo_root}" --git "${circom_git_url}" --tag "${circom_git_ref}" --locked
                ;;
            rev)
                cargo install --force --root "${cargo_root}" --git "${circom_git_url}" --rev "${circom_git_ref}" --locked
                ;;
            branch)
                warn "CIRCOM_GIT_REF_TYPE=branch 使用可移动 ref，不保证可复现；建议使用 tag 或 rev。"
                cargo install --force --root "${cargo_root}" --git "${circom_git_url}" --branch "${circom_git_ref}" --locked
                ;;
            *)
                error "CIRCOM_GIT_REF_TYPE 仅支持 tag/rev/branch: ${circom_git_ref_type}"
                ;;
        esac
        command_in_home circom || error "circom 未安装到 HOME 下: $(command_path circom)"
        info "circom 安装完成: $(circom --version 2>/dev/null || echo installed)"
    fi

    local circomlib_version snarkjs_version
    circomlib_version="${CIRCOMLIB_VERSION:-2.0.5}"
    snarkjs_version="${SNARKJS_VERSION:-0.7.6}"

    info "安装/校准 npm ZK 包: circomlib@${circomlib_version} snarkjs@${snarkjs_version}"
    npm install -g "circomlib@${circomlib_version}" "snarkjs@${snarkjs_version}"

    if command_in_home snarkjs; then
        info "snarkjs 已存在: $(snarkjs --version 2>/dev/null || echo installed)"
    elif command_exists snarkjs; then
        warn "snarkjs 存在但不在 HOME 下: $(command_path snarkjs)"
    else
        error "snarkjs 安装后不可用，请检查 npm global prefix 和 PATH"
    fi

    if _layer4_npm_global_package_installed circomlib; then
        info "circomlib 已安装为用户级 npm 全局包"
        npm list -g --depth=0 circomlib || true
    else
        error "circomlib 安装后校验失败"
    fi

    npm list -g --depth=0 snarkjs || true
}
