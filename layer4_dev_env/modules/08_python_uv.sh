#!/usr/bin/env bash
# ===========================================================
#  Module 08: Python uv toolchain + scientific venv
# ===========================================================

run_08_python_uv() {
    step "8/10" "安装 uv Python 工具链与科学计算 venv"

    export PATH="${HOME}/.local/bin:${PATH}"

    if command_in_home uv; then
        info "uv 已存在: $(uv --version)"
    else
        if command_exists uv; then
            warn "检测到非用户级 uv: $(command_path uv)，将安装用户级 uv"
        fi
        info "安装 uv..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="${HOME}/.local/bin:${PATH}"
    fi

    command_in_home uv || error "uv 未安装到 HOME 下: $(command_path uv)"

    info "uv: $(uv --version 2>/dev/null || echo installed)"

    require_command python3
    python3 - <<'PY'
import sys

if sys.version_info < (3, 10):
    raise SystemExit("Python scientific venv requires Python >= 3.10")
PY

    local venv_dir
    venv_dir="${PYTHON_SCIENCE_VENV_DIR:-${HOME}/code/.venvs/moonmath}"
    require_home_path "${venv_dir}" "PYTHON_SCIENCE_VENV_DIR"

    local packages=(
        numpy==2.2.6
        sympy==1.13.3
        matplotlib==3.10.0
        pandas==2.2.3
        ipython==8.31.0
    )
    if [[ -n "${PYTHON_SCIENCE_PACKAGES:-}" ]]; then
        read -r -a packages <<< "${PYTHON_SCIENCE_PACKAGES}"
    fi

    local package
    for package in "${packages[@]}"; do
        [[ "${package}" != -* ]] || error "PYTHON_SCIENCE_PACKAGES 不允许 pip/uv option: ${package}"
        [[ "${package}" == *"=="* ]] || error "PYTHON_SCIENCE_PACKAGES 必须固定版本 name==version: ${package}"
        [[ "${package}" != *"://"* ]] || error "PYTHON_SCIENCE_PACKAGES 不允许 URL requirement: ${package}"
    done

    mkdir -p "$(dirname "${venv_dir}")"
    require_home_path "${venv_dir}" "PYTHON_SCIENCE_VENV_DIR"

    if [[ -f "${venv_dir}/pyvenv.cfg" ]]; then
        info "Python 科学计算 venv 已存在: ${venv_dir}"
    else
        info "创建 Python 科学计算 venv: ${venv_dir}"
        uv venv --python python3 "${venv_dir}"
    fi

    local python_bin="${venv_dir}/bin/python"
    [[ -x "${python_bin}" ]] || error "venv Python 不存在或不可执行: ${python_bin}"

    info "安装/更新科学计算包: ${packages[*]}"
    uv pip install --python "${python_bin}" "${packages[@]}"

    info "Python scientific venv 已就绪: source ${venv_dir}/bin/activate"
}
