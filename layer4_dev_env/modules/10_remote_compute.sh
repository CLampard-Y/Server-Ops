#!/usr/bin/env bash
# ===========================================================
#  Module 10: HK -> US remote compute helper scripts
# ===========================================================

run_10_remote_compute() {
    step "10/10" "安装远程重计算辅助脚本"

    local bin_dir="${HOME}/.local/bin"
    mkdir -p "${bin_dir}"

    cat > "${bin_dir}/server-ops-sync-to-us" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: server-ops-sync-to-us <project-dir> [remote-dir]" >&2
  exit 1
fi

src="${1%/}"
[[ -d "${src}" ]] || { echo "Source must be an existing directory: ${src}" >&2; exit 1; }

src_real="$(realpath -e -- "${src}")"
code_root="$(realpath -e -- "${HOME}/code")"
case "${src_real}/" in
  "${code_root}/"*) ;;
  *) echo "Source must be under ~/code: ${src_real}" >&2; exit 1 ;;
esac

project="$(basename "${src_real}")"
[[ "${project}" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "Unsafe project name: ${project}" >&2; exit 1; }

remote="${2:-cc_US:~/code/remote/${project}}"
case "${remote}" in
  cc_US:~/code/*) ;;
  *) echo "Remote must be under cc_US:~/code/: ${remote}" >&2; exit 1 ;;
esac
[[ "${remote}" != *".."* ]] || { echo "Remote must not contain path traversal: ${remote}" >&2; exit 1; }
[[ "${remote}" =~ ^cc_US:~/code/[A-Za-z0-9_./~-]+$ ]] || { echo "Remote contains unsupported characters: ${remote}" >&2; exit 1; }

delete_args=()
if [[ "${SERVER_OPS_RSYNC_DELETE:-0}" == "1" ]]; then
  delete_args=(--delete)
fi

rsync -az "${delete_args[@]}" \
  --exclude '.git' \
  --exclude 'node_modules' \
  --exclude 'cache' \
  --exclude 'out' \
  --exclude 'broadcast' \
  --exclude '.env' \
  --exclude '.env.*' \
  --exclude '.envrc' \
  --exclude '.npmrc' \
  --exclude '.netrc' \
  --exclude '*.env' \
  --exclude '*.key' \
  --exclude '*.pem' \
  --exclude '*.token' \
  --exclude '*secret*' \
  --exclude '*mnemonic*' \
  --exclude '*keystore*' \
  --exclude 'wallet*' \
  --exclude '.ssh' \
  --exclude '.codex' \
  --exclude '.cc-switch' \
  -- "${src_real}/" "${remote}/"
EOF

    cat > "${bin_dir}/server-ops-us-forge-test" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

remote_dir="${1:-~/code/remote}"
shift || true

if [[ ! "${remote_dir}" =~ ^[A-Za-z0-9_./~:-]+$ ]]; then
  echo "Unsafe remote path: ${remote_dir}" >&2
  exit 1
fi

if [[ "${remote_dir}" == *".."* ]]; then
  echo "Remote path must not contain path traversal: ${remote_dir}" >&2
  exit 1
fi

ssh cc_US bash -s -- "${remote_dir}" "$@" <<'REMOTE_EOF'
set -euo pipefail

remote_dir="$1"
shift || true

case "${remote_dir}" in
  ~/*) remote_dir="${HOME}/${remote_dir#~/}" ;;
esac

cd "${remote_dir}"
forge test "$@"
REMOTE_EOF
EOF

    chmod +x "${bin_dir}/server-ops-sync-to-us" "${bin_dir}/server-ops-us-forge-test"

    info "已安装: ${bin_dir}/server-ops-sync-to-us"
    info "已安装: ${bin_dir}/server-ops-us-forge-test"
}
