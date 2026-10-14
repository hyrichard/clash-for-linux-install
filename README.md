<h1 align="center">
  clashctl
</h1>

<p align="center">Linux 上的 Mihomo / Clash 安装与管理工具</p>

<p align="center">
  <a href="https://www.star-history.com/nelvko/clash-for-linux-install">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/badge?repo=nelvko/clash-for-linux-install&type=rank&theme=dark" />
      <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/badge?repo=nelvko/clash-for-linux-install&type=rank" />
      <img alt="Star History Rank" src="https://api.star-history.com/badge?repo=nelvko/clash-for-linux-install&type=rank" />
    </picture>
  </a>
</p>

<p align="center">
  <a href="https://github.com/nelvko/clash-for-linux-install/actions/workflows/shell-tests.yml"><img alt="Shell tests" src="https://github.com/nelvko/clash-for-linux-install/actions/workflows/shell-tests.yml/badge.svg" /></a>
  <img alt="Platform: Linux" src="https://img.shields.io/badge/platform-Linux-blue?logo=linux&amp;logoColor=white" />
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/github/license/nelvko/clash-for-linux-install" /></a>
  <img alt="Language: Shell" src="https://img.shields.io/github/languages/top/nelvko/clash-for-linux-install" />
  <a href="https://github.com/nelvko/clash-for-linux-install/stargazers"><img alt="GitHub stars" src="https://img.shields.io/github/stars/nelvko/clash-for-linux-install" /></a>
  <a href="https://deepwiki.com/nelvko/clash-for-linux-install"><img src="https://deepwiki.com/badge.svg" alt="Ask DeepWiki"></a>
</p>

<table>
  <tr>
    <td width="180" align="center" valign="middle">
      <a href="https://get.sushi3.cloud/#/home?code=aHno9F9G">
        <img width="80" alt="寿司云" src="https://github.com/user-attachments/assets/ef609476-caf8-49bf-981d-651b2875a3a0" />
      </a>
    </td>
    <td valign="middle">
      <b><a href="https://get.sushi3.cloud/#/home?code=aHno9F9G">寿司云</a></b> 是 AI 用途优先的 VPN，着重优化 GPT、Claude、Gemini 等海外 AI 的使用体验，提供家宽节点和中国三网优化线路。<a href="https://get.sushi3.cloud/#/home?code=aHno9F9G">注册免费体验 1 天</a>。
    </td>
  </tr>
  <tr>
    <td width="180" align="center" valign="middle">
      <a href="https://api.muteki.site/register?aff=nelvko&promo=nelvko">
        <img width="180" alt="MaruCode" src="https://github.com/user-attachments/assets/48680ff3-ffbb-492b-82ec-5e85e9502e62" />
      </a>
    </td>
    <td valign="middle">
      <b><a href="https://api.muteki.site/register?aff=nelvko&promo=nelvko">MaruCode</a></b> 是一家偶尔做做慈善的小破站 API，自营号池，主要提供 Codex、Claude Code、GPT Image 等主流模型，支持 WebSocket 协议，明码标价（Codex 0.25x, CC 1.5x），透明汇率（1:1） <a href="https://images-2.muteki.site">生图工作台🖼️</a>
    </td>
  </tr>
</table>

<p align="center">
  <img src="https://github.com/user-attachments/assets/471f3acb-faca-4610-a02e-5294e003301e" alt="preview" width="800" />
</p>

## ✨ 特性

- **开箱即用**：一键部署 `mihomo` 内核、Web 面板及运行依赖。
- **广泛兼容**：支持 `root` 与普通用户，适配主流 Linux 发行版及容器环境。兼容 systemd、OpenRC 等服务方式，提供 Bash、Zsh 和 Fish 命令集成。
- **功能丰富**：涵盖代理开关、内核启停、状态查看、日志追踪等常用操作，支持 Web 面板、TUN 模式、内核升级及 `Mixin` 配置。
- **订阅管理**：支持多订阅添加、切换与更新，集成 [subconverter](https://github.com/asdlokj1qpi233/subconverter) 实现订阅格式转换。

## 📦 安装

首次安装或从旧版升级，执行以下命令（已加速）：

```bash
GH_PROXY=https://gh-proxy.org/
curl -fsSL "${GH_PROXY}https://raw.githubusercontent.com/nelvko/clash-for-linux-install/HEAD/install.sh" | \
  bash -s -- --gh-proxy "$GH_PROXY"
```

- `GH_PROXY`：[GitHub 下载加速代理](https://gh-proxy.org/)，失效时可更换[其他可用地址](https://ghproxy.link/)。
- 没有订阅？[click me](https://get.sushi3.cloud/#/home?code=aHno9F9G)

### 离线安装（预置包）

先在任意联网机器上把依赖包一次性下载好，再拷到目标机器离线安装：

```bash
# 联网机器：生成预置包目录（默认 ./offline-packages）
./fetch-packages.sh                       # 默认 amd64 + 两个前端；-a arm64 指定架构，-h 查看全部选项

# 拷贝到目标机器后：命中预置包直接使用，缺失的才联网下载
./install.sh --local --package-dir /path/to/offline-packages
```

预置包覆盖内核（mihomo/clash）、`yq`、订阅转换器、Web 前端（zashboard/metacubexd）与地理数据库
（`country.mmdb`/`geosite.dat`）。目录也可长期写在 `.env` 的 `CLASHCTL_PACKAGE_DIR` 中。

`--local` 表示用当前目录的源码安装。不加时安装器会从仓库分支拉取源码，那份代码若还不含预置包
逻辑，`--package-dir` 就会形同虚设（包照样联网下载）。

## 🚀 快速上手

添加并启用订阅（安装时已配置可跳过）：

```bash
clashctl sub add --use "<订阅链接>"
```

开启当前终端代理：

```bash
# 自动启动内核，并开启当前终端代理
clashctl on

# 测试连通性
curl -I https://www.google.com
```

## ⌨️ 命令一览

```text
Usage:
  clashctl COMMAND [OPTIONS]

Commands:
  on                    启用当前终端代理，自动启动内核
  off                   关闭当前终端代理，保留内核运行
  start                 仅启动内核
  stop                  仅停止内核
  status                内核状态
  ui                    面板地址（ui switch 切换前端）
  sub                   订阅管理
  node                  节点切换
  tun                   Tun 模式
  mixin                 Mixin 配置
  secret                Web 密钥
  log                   查看日志
  upgrade               升级内核
  update                更新 clashctl
  version               脚本和内核版本

Global Options:
  -h, --help            显示帮助信息
  -v, --version         显示版本信息
```

使用示例与进阶配置，详见 [Wiki](https://github.com/nelvko/clash-for-linux-install/wiki)。

## 🔄 更新

```bash
# 更新 clashctl 上游版本
clashctl update

# 升级代理内核
clashctl upgrade
```

## 🗑️ 卸载

```bash
# 清理当前 Shell 的代理环境变量（卸载脚本无法清理）
clashctl off

# 执行卸载脚本
bash "$CLASHCTL_HOME/uninstall.sh"
```

卸载会删除安装目录及其数据，需要保留的内容请提前备份。`.clashctl-backups/` 中的恢复资料会保留，确认无需回退后可手动清理。

## 📖 文档

- [Wiki](https://github.com/nelvko/clash-for-linux-install/wiki)
- [常见问题](https://github.com/nelvko/clash-for-linux-install/wiki/FAQ)

## ⭐ Star History

<a href="https://www.star-history.com/?repos=nelvko%2Fclash-for-linux-install&type=date&legend=top-left">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=nelvko/clash-for-linux-install&type=date&theme=dark&legend=top-left" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=nelvko/clash-for-linux-install&type=date&legend=top-left" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=nelvko/clash-for-linux-install&type=date&legend=top-left" />
 </picture>
</a>

## ⚠️ 特别声明

- 编写本项目主要是为了学习和研究 `Shell` 编程，不得将项目内容用于违反适用法律法规及相关规定的活动。
- 本项目保留对本声明进行补充或修改的权利。使用本项目前，请阅读并遵守本声明。
