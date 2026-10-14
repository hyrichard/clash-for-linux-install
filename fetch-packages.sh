#!/usr/bin/env bash
#
# 一键下载安装所需的全部依赖包，生成「离线预置包」目录。
#
# 产物直接作为 install.sh 的预置包目录使用：命中即用、缺失才联网下载。
#
#   ./fetch-packages.sh                              # 当前架构：mihomo + yq + zashboard + 地理数据库 + subconverter
#   ./fetch-packages.sh -a arm64 -u metacubexd       # 指定架构与前端
#   ./fetch-packages.sh -p https://ghfast.top        # 走 GitHub 加速前缀
#   ./fetch-packages.sh --latest                     # 跟随各仓库最新版本（默认用内置钉版）
#
# 下载完成后拷到目标机器（--local 用本地源码安装；不加则安装器会拉取仓库分支的源码，
# 那份代码里没有预置包逻辑，预置包不会被使用）：
#   ./install.sh --local --package-dir /path/to/offline-packages
#
# 命名规则与 scripts/preflight.sh 的预置包候选名保持一致：
#   内核   mihomo-linux-<arch>[-<level>]-<tag>.gz / clash-linux-<arch>-2023.08.17.gz
#   yq     yq_linux_<arch>.tar.gz
#   转换器 subconverter_<arch>.tar.gz
#   前端   ui.zip（zashboard）/ ui.tgz（metacubexd）
#   数据库 country.mmdb、geosite.dat
set -u

PROGRAM=${0##*/}

OUT_DIR=./offline-packages
ARCH=''
ARCH_GIVEN=0
KERNEL=mihomo
UI=zashboard
LEVEL=''
PROXY=${GH_PROXY:-}
TIMEOUT=${CLASHCTL_DOWNLOAD_TIMEOUT:-120}
USE_LATEST=0
WITH_SUBCONVERTER=1
FORCE=0
DRY_RUN=0

# 与 scripts/preflight.sh 的内置钉版保持一致：离线时安装器会回退到这些版本，
# 从而与本脚本产出的文件名精确对上（有通配兜底，版本漂移也能命中）。
PIN_MIHOMO=v1.19.27
PIN_YQ=v4.53.3
PIN_SUBCONVERTER=v0.9.9
PIN_UI=v3.20.0
PIN_METACUBEXD=v1.273.1

SUBCONVERTER_REPO=${SUBCONVERTER_REPO:-asdlokj1qpi233/subconverter}
GEODATA_BASE=https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest
CLASH_BASE=https://github.com/nelvko/clash-for-linux-install/releases/download/clash
CLASH_TAG=2023.08.17

say() { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }
die() {
    printf '%s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
一键下载安装依赖包，生成离线预置包目录。

用法：fetch-packages.sh [选项]

  -o, --output <目录>     输出目录（默认 ./offline-packages）
  -a, --arch <架构>       amd64 | 386 | armv7 | arm64（默认按本机检测）
  -k, --kernel <内核>     mihomo（默认）| clash
  -u, --ui <前端>         zashboard（默认）| metacubexd | none
  -l, --level <等级>      amd64 专用：v1 | v2 | v3（默认按本机 CPU 检测，否则 v1）
  -p, --proxy <前缀>      GitHub 加速前缀，如 https://ghfast.top（默认读 GH_PROXY）
      --latest            跟随各仓库最新版本（默认使用内置钉版，便于离线复现）
      --no-subconverter   跳过订阅转换器（仅订阅转换时才需要）
  -f, --force             已存在也重新下载
  -n, --dry-run           只打印将要下载的地址，不实际下载
  -h, --help              显示本帮助
EOF
}

while [ $# -gt 0 ]; do
    case $1 in
    -o | --output)
        OUT_DIR=${2:-}
        [ -n "$OUT_DIR" ] || die "$1 需要一个目录"
        shift 2
        ;;
    -a | --arch)
        ARCH=${2:-}
        [ -n "$ARCH" ] || die "$1 需要一个架构"
        ARCH_GIVEN=1
        shift 2
        ;;
    -k | --kernel)
        KERNEL=${2:-}
        [ -n "$KERNEL" ] || die "$1 需要一个内核名"
        shift 2
        ;;
    -u | --ui)
        UI=${2:-}
        [ -n "$UI" ] || die "$1 需要一个前端名"
        shift 2
        ;;
    -l | --level)
        LEVEL=${2:-}
        [ -n "$LEVEL" ] || die "$1 需要一个等级"
        shift 2
        ;;
    -p | --proxy)
        PROXY=${2:-}
        [ -n "$PROXY" ] || die "$1 需要一个前缀"
        shift 2
        ;;
    --latest)
        USE_LATEST=1
        shift
        ;;
    --no-subconverter)
        WITH_SUBCONVERTER=0
        shift
        ;;
    -f | --force)
        FORCE=1
        shift
        ;;
    -n | --dry-run)
        DRY_RUN=1
        shift
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *) die "未知参数：${1}（用 -h 查看用法）" ;;
    esac
done

command -v curl >/dev/null 2>&1 || die '缺少命令：curl'

# 与 scripts/lib/common.sh 的 gh_proxy_url 一致：前缀 + / + 原始地址。
gh_proxy_url() {
    if [ -n "$PROXY" ]; then
        printf '%s/%s\n' "${PROXY%/}" "$1"
    else
        printf '%s\n' "$1"
    fi
}

detect_arch() {
    case $(uname -m) in
    x86_64 | amd64) printf 'amd64\n' ;;
    i?86 | x86) printf '386\n' ;;
    armv7l | armv7 | armhf | arm) printf 'armv7\n' ;;
    aarch64 | arm64) printf 'arm64\n' ;;
    *) printf '\n' ;;
    esac
}

# 与 scripts/preflight.sh 的 amd64 等级检测一致（本机为 Linux 时才有意义）。
detect_level() {
    local flags level=v1
    flags=$(grep -m1 '^flags' /proc/cpuinfo 2>/dev/null) || {
        printf 'v1\n'
        return 0
    }
    grep -qw sse4_2 <<<"$flags" && grep -qw popcnt <<<"$flags" && level=v2
    grep -qw avx2 <<<"$flags" && grep -qw fma <<<"$flags" && level=v3
    printf '%s\n' "$level"
}

latest_tag() {
    local repo=$1 direct body tag url
    local -a urls
    direct="https://api.github.com/repos/$repo/releases/latest"
    urls=("$direct")
    [ -z "$PROXY" ] || urls=("$(gh_proxy_url "$direct")" "$direct")
    for url in "${urls[@]}"; do
        body=$(curl -sSL --fail --connect-timeout 4 --max-time 12 --retry 1 \
            -H 'Accept: application/vnd.github+json' "$url" 2>/dev/null) || continue
        tag=$(printf '%s' "$body" | grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 |
            sed -E 's/.*"([^"]+)"[[:space:]]*$/\1/')
        [ -n "$tag" ] && {
            printf '%s\n' "$tag"
            return 0
        }
    done
    return 1
}

resolve_version() {
    local repo=$1 pinned=$2 tag
    if [ "$USE_LATEST" = 1 ]; then
        if tag=$(latest_tag "$repo"); then
            printf '%s\n' "$tag"
            return 0
        fi
        warn "无法查询 $repo 最新版本，回退钉版 $pinned"
    fi
    printf '%s\n' "$pinned"
}

# 轻量校验：与安装期 _archive_is_valid / _geodata_file_valid 的口径对齐。
verify_file() {
    local file=$1 size
    [ -s "$file" ] || return 1
    case $file in
    *.tar.gz | *.tgz) tar -tzf "$file" >/dev/null 2>&1 ;;
    *.gz) gzip -tq "$file" 2>/dev/null ;;
    *.zip) unzip -tqq "$file" >/dev/null 2>&1 ;;
    *.mmdb)
        size=$(wc -c <"$file")
        [ "$size" -ge 65536 ] && grep -qa 'MaxMind.com' "$file"
        ;;
    *.dat)
        size=$(wc -c <"$file")
        [ "$size" -ge 65536 ] && ! head -c 64 "$file" | grep -qi '<html'
        ;;
    *) [ -s "$file" ] ;;
    esac
}

produced=()

fetch() {
    local url=$1 dest=$2 label=$3 part
    part="$dest.part"
    if [ "$FORCE" != 1 ] && [ -s "$dest" ] && verify_file "$dest"; then
        say "跳过（已存在）：$label"
        produced+=("${dest##*/}")
        return 0
    fi
    if [ "$DRY_RUN" = 1 ]; then
        say "将下载 $label"
        say "    $url"
        say "  -> $dest"
        return 0
    fi
    mkdir -p -- "$(dirname -- "$dest")" || die "无法创建目录：$(dirname -- "$dest")"
    command rm -f -- "$part"
    say "下载 $label"
    if ! curl --show-error --fail --location \
        --max-time "$TIMEOUT" --retry 1 --output "$part" --url "$url"; then
        command rm -f -- "$part"
        die "下载失败：${label}\n    $url"
    fi
    if ! verify_file "$part"; then
        command rm -f -- "$part"
        die "文件校验失败：${label}（${url}）"
    fi
    /bin/mv -f -- "$part" "$dest" || die "无法写入：$dest"
    produced+=("${dest##*/}")
    say "完成：$dest"
}

[ -n "$ARCH" ] || ARCH=$(detect_arch)
if [ "$ARCH_GIVEN" != 1 ] && [ "$(uname -s)" != Linux ]; then
    warn "当前主机不是 Linux，架构按本机推断为 ${ARCH:-未知}；若目标机不同请用 -a 显式指定"
fi
case $ARCH in
x86_64 | amd64) ARCH=amd64 ;;
i386 | i486 | i586 | i686 | 386 | x86) ARCH=386 ;;
armv7l | armv7 | armhf | arm) ARCH=armv7 ;;
aarch64 | arm64) ARCH=arm64 ;;
esac
case $ARCH in
amd64 | 386 | armv7 | arm64) ;;
*) die "不支持的架构：${ARCH:-未知}（用 -a 指定 amd64/386/armv7/arm64）" ;;
esac
case $KERNEL in
mihomo | clash) ;;
*) die "内核只能是 mihomo 或 clash（当前：${KERNEL}）" ;;
esac
case $UI in
zashboard | metacubexd | none) ;;
*) die "前端只能是 zashboard、metacubexd 或 none（当前：${UI}）" ;;
esac
if [ "$ARCH" = amd64 ]; then
    [ -n "$LEVEL" ] || LEVEL=$(detect_level)
    case $LEVEL in
    v1 | v2 | v3) ;;
    *) die "--level 只能是 v1/v2/v3（当前：${LEVEL}）" ;;
    esac
else
    [ -z "$LEVEL" ] || warn "--level 仅对 amd64 生效，已忽略"
    LEVEL=''
fi

case $ARCH in
amd64)
    YQ_ARCH=amd64
    SUB_ARCH=linux64
    CLASH_ARCH=amd64
    ;;
386)
    YQ_ARCH=386
    SUB_ARCH=linux32
    CLASH_ARCH=386
    ;;
armv7)
    YQ_ARCH=arm
    SUB_ARCH=armv7
    CLASH_ARCH=armv5
    ;;
arm64)
    YQ_ARCH=arm64
    SUB_ARCH=aarch64
    CLASH_ARCH=arm64
    ;;
esac

MIHOMO_TAG=$(resolve_version MetaCubeX/mihomo "$PIN_MIHOMO")
YQ_TAG=$(resolve_version mikefarah/yq "$PIN_YQ")
SUB_TAG=$(resolve_version "$SUBCONVERTER_REPO" "$PIN_SUBCONVERTER")
UI_TAG=$(resolve_version Zephyruso/zashboard "$PIN_UI")
META_TAG=$(resolve_version MetaCubeX/metacubexd "$PIN_METACUBEXD")

# 注意：不要把非 ASCII 字符紧跟在 ${VAR:+...} 内，macOS 自带 bash 3.2 会误判变量名。
arch_display=$ARCH
[ -z "$LEVEL" ] || arch_display="${ARCH}（${LEVEL}）"
say "架构：$arch_display   内核：$KERNEL   前端：$UI   输出：$OUT_DIR"

if [ "$KERNEL" = mihomo ]; then
    if [ "$ARCH" = amd64 ]; then
        name="mihomo-linux-amd64-$LEVEL-$MIHOMO_TAG.gz"
    else
        name="mihomo-linux-$ARCH-$MIHOMO_TAG.gz"
    fi
    fetch "https://github.com/MetaCubeX/mihomo/releases/download/$MIHOMO_TAG/$name" \
        "$OUT_DIR/$name" "内核 mihomo $MIHOMO_TAG"
else
    name="clash-linux-$CLASH_ARCH-$CLASH_TAG.gz"
    fetch "$CLASH_BASE/$name" "$OUT_DIR/$name" "内核 clash $CLASH_TAG"
fi

name="yq_linux_$YQ_ARCH.tar.gz"
fetch "https://github.com/mikefarah/yq/releases/download/$YQ_TAG/$name" \
    "$OUT_DIR/$name" "yq $YQ_TAG"

if [ "$WITH_SUBCONVERTER" = 1 ]; then
    name="subconverter_$SUB_ARCH.tar.gz"
    fetch "https://github.com/$SUBCONVERTER_REPO/releases/download/$SUB_TAG/$name" \
        "$OUT_DIR/$name" "subconverter $SUB_TAG"
fi

case $UI in
zashboard)
    fetch "https://github.com/Zephyruso/zashboard/releases/download/$UI_TAG/dist.zip" \
        "$OUT_DIR/ui.zip" "前端 zashboard $UI_TAG"
    ;;
metacubexd)
    fetch "https://github.com/MetaCubeX/metacubexd/releases/download/$META_TAG/compressed-dist.tgz" \
        "$OUT_DIR/ui.tgz" "前端 metacubexd $META_TAG"
    ;;
none) say '前端：跳过（none）' ;;
esac

fetch "$GEODATA_BASE/country.mmdb" "$OUT_DIR/country.mmdb" '地理数据库 country.mmdb'
fetch "$GEODATA_BASE/geosite.dat" "$OUT_DIR/geosite.dat" '地理数据库 geosite.dat'

[ "$DRY_RUN" = 1 ] && exit 0

# 校验清单，便于传输后核对完整性。
if ((${#produced[@]})); then
    if command -v sha256sum >/dev/null 2>&1; then
        (cd -- "$OUT_DIR" && sha256sum -- "${produced[@]}" >SHA256SUMS)
    elif command -v shasum >/dev/null 2>&1; then
        (cd -- "$OUT_DIR" && shasum -a 256 -- "${produced[@]}" >SHA256SUMS)
    fi
fi

say ''
say "预置包已就绪：$OUT_DIR"
say '安装时指定该目录即可离线复用（--local 用本地源码，否则安装器会拉取远端分支源码）：'
say "    ./install.sh --local --package-dir $(cd -- "$OUT_DIR" && pwd)"
