#!/usr/bin/env bash
# 预置包命中：download_zip 必须把通用前端名（ui.zip/ui.tgz）交给 _download_archive，
# 命中后不得再发起下载。回归点：extras 曾在版本查询那轮赋值，挑选 url 那轮被清空。
set -euo pipefail

TEST_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_DIR=$(cd -- "$TEST_DIR/.." && pwd -P)
WORK_DIR=$(mktemp -d)
trap 'command rm -rf -- "$WORK_DIR"' EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

command -v python3 >/dev/null 2>&1 || fail 'python3 is required'

make_zip() {
    python3 - "$1" <<'PY'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1], 'w') as archive:
    archive.writestr('dist/index.html', '<html>preset</html>')
PY
}

make_tgz() {
    python3 - "$1" <<'PY'
import io, sys, tarfile
with tarfile.open(sys.argv[1], 'w:gz') as archive:
    payload = b'<html>preset</html>'
    info = tarfile.TarInfo('dist/index.html')
    info.size = len(payload)
    archive.addfile(info, io.BytesIO(payload))
PY
}

probe="$WORK_DIR/probe.sh"
cat >"$probe" <<'PROBE'
#!/usr/bin/env bash
set -uo pipefail
repo=$1
case_dir=$2
frontend=$3
preset_dir=$4

export CLASHCTL_SRC=$repo
export CLASHCTL_HOME="$case_dir/home"
export CLASHCTL_KERNEL=mihomo
export CLASHCTL_COLOR=never
export CLASHCTL_UI_FRONTEND=$frontend
export CLASHCTL_PACKAGE_DIR=$preset_dir
export CLASHCTL_DOWNLOAD_TIMEOUT=5
mkdir -p -- "$CLASHCTL_HOME/resources" "$CLASHCTL_HOME/bin" "$CLASHCTL_HOME/data"

. "$repo/scripts/preflight.sh" || exit 1

# 断网：下载尝试一律记账并失败；命中预置包时不应出现归档地址。
curl() {
    printf '%s\n' "$*" >>"$case_dir/curl"
    return 22
}

download_zip ui || exit 1
printf 'ARCHIVE=%s\n' "$ZIP_UI"

# 布局归一化（根目录 index.html 与 dist/index.html 都要落到 dist/）
stage="$case_dir/stage"
mkdir -p -- "$stage"
_component_prepare_ui "$ZIP_UI" "$stage" || exit 1
[ -f "$stage/ui.extract/dist/index.html" ] || exit 1
PROBE
chmod 0700 "$probe"

# run_case <用例名> <前端> <应当命中的归档名> <预置目录内容 …>
run_case() {
    local label=$1 frontend=$2 expected=$3 fixture
    shift 3
    local case_dir="$WORK_DIR/$label" preset_dir="$WORK_DIR/preset-$label"
    mkdir -p -- "$case_dir" "$preset_dir"
    for fixture in "$@"; do
        case $fixture in
        ui.zip) make_zip "$preset_dir/ui.zip" ;;
        ui.tgz) make_tgz "$preset_dir/ui.tgz" ;;
        esac
    done
    if ! output=$(bash "$probe" "$REPO_DIR" "$case_dir" "$frontend" "$preset_dir" 2>"$case_dir/stderr"); then
        cat "$case_dir/stderr" >&2
        fail "$label probe failed"
    fi
    resolved=$(printf '%s\n' "$output" | sed -n 's/^ARCHIVE=//p')
    [ -n "$resolved" ] || fail "$label 未产出 ZIP_UI"
    if grep -qs 'releases/download' "$case_dir/curl"; then
        cat "$case_dir/curl" >&2
        fail "$label 命中预置包后仍在下载"
    fi
    cmp -s -- "$resolved" "$preset_dir/$expected" || fail "$label 未使用预置包内容：$resolved"
}

run_case zip-only zashboard ui.zip ui.zip
run_case tgz-only metacubexd ui.tgz ui.tgz
# fetch-packages.sh 默认两个前端都下：都放着时也必须各取所需，不能因先命中格式不符的那份而退回下载。
run_case both-zashboard zashboard ui.zip ui.zip ui.tgz
run_case both-metacubexd metacubexd ui.tgz ui.zip ui.tgz

printf 'preset-packages: ok\n'
