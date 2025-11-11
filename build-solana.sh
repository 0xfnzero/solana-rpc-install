#!/bin/bash

# ====================================
# Solana 编译安装脚本 (Ubuntu)
# ====================================
# 用途：在 Ubuntu 系统上从源码编译安装 Solana
# 支持自定义版本选择
# ====================================

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置变量
DEFAULT_VERSION="v3.0.10"
BASE_DIR="/opt/solana"              # 安装基础目录
SOLANA_VERSION=""
DOWNLOAD_URL=""
INSTALL_DIR="${BASE_DIR}"           # Solana 安装目录
SOURCE_DIR=""                       # 源码目录（根据版本动态设置）

# 打印信息函数
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

highlight() {
    echo -e "${BLUE}$1${NC}"
}

# 显示欢迎信息
show_welcome() {
    clear
    echo ""
    highlight "============================================"
    highlight "   Solana (Agave) 编译安装脚本 - Ubuntu"
    highlight "============================================"
    echo ""
    info "安装目录: ${BASE_DIR}"
    info "源码将在临时目录编译，完成后安装到上述目录"
    echo ""
}

# 选择版本
select_version() {
    info "请选择要安装的 Solana 版本:"
    echo ""
    echo "  1) v3.0.10 (推荐 - 最新稳定版)"
    echo "  2) v3.0.9 (LTS)"
    echo "  3) v3.0.8"
    echo "  4) v3.0.7"
    echo "  5) 自定义版本 (输入完整版本号，如 v3.1.0)"
    echo ""

    while true; do
        read -p "请输入选项 [1-5] (默认: 1): " choice
        choice=${choice:-1}

        case $choice in
            1)
                SOLANA_VERSION="v3.0.10"
                break
                ;;
            2)
                SOLANA_VERSION="v3.0.9"
                break
                ;;
            3)
                SOLANA_VERSION="v3.0.8"
                break
                ;;
            4)
                SOLANA_VERSION="v3.0.7"
                break
                ;;
            5)
                read -p "请输入版本号 (格式: vX.Y.Z): " custom_version
                if [[ $custom_version =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    SOLANA_VERSION="$custom_version"
                    warn "使用自定义版本: $SOLANA_VERSION"
                    warn "请确认该版本存在于 https://github.com/anza-xyz/agave/releases"
                    read -p "继续安装? (y/N): " confirm
                    if [[ ! $confirm =~ ^[Yy]$ ]]; then
                        error "已取消安装"
                    fi
                    break
                else
                    error "版本号格式错误，请使用 vX.Y.Z 格式 (如 v3.0.10)"
                fi
                ;;
            *)
                warn "无效选项，请输入 1-6"
                ;;
        esac
    done

    # 设置下载 URL 和源码目录（使用临时目录）
    DOWNLOAD_URL="https://github.com/anza-xyz/agave/archive/refs/tags/${SOLANA_VERSION}.tar.gz"
    SOURCE_DIR="/tmp/solana-build/agave-${SOLANA_VERSION#v}"

    echo ""
    info "已选择版本: ${SOLANA_VERSION}"
    info "下载地址: ${DOWNLOAD_URL}"
    echo ""
}

# 确认安装
confirm_installation() {
    echo ""
    highlight "============================================"
    highlight "  安装配置确认"
    highlight "============================================"
    echo ""
    echo "  Solana 版本:    ${SOLANA_VERSION}"
    echo "  安装目录:       ${INSTALL_DIR}"
    echo "  临时编译目录:   ${SOURCE_DIR}"
    echo "  编译时间:       预计 20-40 分钟"
    echo "  所需磁盘:       约 20GB (临时)"
    echo ""

    read -p "确认开始安装? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        info "已取消安装"
        exit 0
    fi
    echo ""
}

# 检查是否为 root 用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        warn "建议使用 root 用户执行此脚本 (当前用户: $(whoami))"
        warn "某些操作可能需要 sudo 权限"
        read -p "是否继续? (y/N): " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        info "以 root 用户运行"
    fi
}

# 检查系统环境
check_system() {
    info "检查系统环境..."

    # 检查是否为 Ubuntu/Debian
    if [[ ! -f /etc/os-release ]]; then
        error "无法检测系统版本"
    fi

    . /etc/os-release
    if [[ "$ID" != "ubuntu" ]] && [[ "$ID" != "debian" ]]; then
        warn "此脚本针对 Ubuntu/Debian 优化，当前系统: $ID"
    fi

    info "系统: $PRETTY_NAME"

    # 检查磁盘空间
    available_space=$(df -BG ${BASE_DIR%/*} 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ -z "$available_space" ]]; then
        available_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    fi

    if [[ $available_space -lt 20 ]]; then
        error "磁盘空间不足！至少需要 20GB，当前可用: ${available_space}GB"
    fi

    info "可用磁盘空间: ${available_space}GB"
}

# 创建安装目录
create_install_directory() {
    info "准备安装目录: ${INSTALL_DIR}"

    if [[ ! -d "$INSTALL_DIR" ]]; then
        mkdir -p "$INSTALL_DIR"
        info "已创建安装目录: ${INSTALL_DIR}"
    else
        info "安装目录已存在: ${INSTALL_DIR}"
    fi
}

# 检查并安装 Rust
install_rust() {
    info "检查 Rust 环境..."

    if ! command -v rustc &> /dev/null; then
        info "未检测到 Rust，开始安装..."
        info "下载并运行 rustup 安装脚本..."
        curl https://sh.rustup.rs -sSf | sh -s -- -y

        # 加载 Rust 环境
        source "$HOME/.cargo/env"
        info "✅ Rust 安装完成"
    else
        info "Rust 已安装: $(rustc --version)"
    fi

    # 确保 Rust 环境可用
    if [[ -f "$HOME/.cargo/env" ]]; then
        source "$HOME/.cargo/env"
    fi

    # 更新 Rust 到最新稳定版
    info "更新 Rust 到最新稳定版..."
    rustup update stable
    rustup default stable

    # 安装必需的 Rust 组件
    info "安装 rustfmt 组件..."
    rustup component add rustfmt

    # 验证安装
    info "验证 Rust 工具链..."
    info "  rustc:   $(rustc --version)"
    info "  cargo:   $(cargo --version)"
    info "  rustfmt: $(rustfmt --version)"
}

# 安装系统依赖
install_dependencies() {
    info "安装系统依赖包..."

    # 更新包列表
    info "更新 apt 包列表..."
    apt-get update -qq

    # 安装必要的依赖（按照 Solana 官方要求）
    info "安装编译所需的系统依赖..."
    apt-get install -y \
        build-essential \
        pkg-config \
        libssl-dev \
        libudev-dev \
        zlib1g-dev \
        llvm \
        clang \
        cmake \
        make \
        libprotobuf-dev \
        protobuf-compiler \
        libclang-dev \
        curl \
        wget \
        git

    # 验证关键依赖
    info "验证关键依赖..."
    info "  gcc:      $(gcc --version | head -n1)"
    info "  clang:    $(clang --version | head -n1)"
    info "  cmake:    $(cmake --version | head -n1)"
    info "  protoc:   $(protoc --version)"

    info "✅ 系统依赖安装完成"
}

# 下载源码
download_source() {
    info "下载 Solana (Agave) ${SOLANA_VERSION} 源码..."

    # 创建临时编译目录
    local build_dir="/tmp/solana-build"
    mkdir -p "$build_dir"

    # 清理旧的源码目录
    if [[ -d "$SOURCE_DIR" ]]; then
        warn "检测到已存在的源码目录，正在清理..."
        rm -rf "$SOURCE_DIR"
    fi

    # 下载源码到临时目录
    cd "$build_dir"

    local tar_file="agave-${SOLANA_VERSION}.tar.gz"

    info "正在下载到临时目录 (${DOWNLOAD_URL})..."
    if ! wget -q --show-progress -O "$tar_file" "$DOWNLOAD_URL"; then
        error "下载失败！请检查版本号是否正确或网络连接"
    fi

    # 解压
    info "解压源码..."
    tar -xzf "$tar_file"

    if [[ ! -d "$SOURCE_DIR" ]]; then
        error "源码解压失败，目录不存在: $SOURCE_DIR"
    fi

    # 清理压缩包
    rm -f "$tar_file"

    info "源码准备完成: $SOURCE_DIR"
}

# 编译 Solana
build_solana() {
    info "开始编译 Solana ${SOLANA_VERSION}"
    info "这可能需要 20-40 分钟，请耐心等待..."
    echo ""

    cd "$SOURCE_DIR"

    # 设置编译选项
    local cpu_cores=$(nproc)
    export CARGO_BUILD_JOBS=$cpu_cores

    info "使用 ${cpu_cores} 个 CPU 核心进行并行编译"

    # 显示编译开始时间
    local start_time=$(date +%s)
    info "编译开始时间: $(date '+%Y-%m-%d %H:%M:%S')"

    # 执行编译脚本
    info "执行编译脚本..."
    if ! ./scripts/cargo-install-all.sh "$INSTALL_DIR"; then
        error "编译失败！请检查错误信息"
    fi

    # 计算编译耗时
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    info "编译完成！耗时: ${minutes}分${seconds}秒"
}

# 配置环境变量
setup_environment() {
    info "配置环境变量..."

    # 检测 shell 配置文件
    local shell_config=""
    if [[ -f "$HOME/.bashrc" ]]; then
        shell_config="$HOME/.bashrc"
    elif [[ -f "$HOME/.zshrc" ]]; then
        shell_config="$HOME/.zshrc"
    else
        shell_config="$HOME/.profile"
    fi

    # 添加 PATH 环境变量
    local solana_path_export="export PATH=\"${INSTALL_DIR}/bin:\$PATH\""

    if ! grep -q "${INSTALL_DIR}/bin" "$shell_config" 2>/dev/null; then
        info "添加 Solana PATH 到 $shell_config"
        echo "" >> "$shell_config"
        echo "# Solana PATH" >> "$shell_config"
        echo "$solana_path_export" >> "$shell_config"
    else
        info "PATH 已存在于 $shell_config"
    fi

    # 立即加载环境变量
    export PATH="${INSTALL_DIR}/bin:$PATH"
}

# 验证安装
verify_installation() {
    info "验证安装..."

    # 临时设置 PATH
    export PATH="${INSTALL_DIR}/bin:$PATH"

    if command -v solana &> /dev/null; then
        echo ""
        highlight "============================================"
        highlight "  ✅ Solana 安装成功！"
        highlight "============================================"
        echo ""
        solana --version
        echo ""

        # 统计已安装的工具
        local tool_count=$(ls -1 "${INSTALL_DIR}/bin/" | wc -l)
        info "已安装 ${tool_count} 个工具到: ${INSTALL_DIR}/bin/"

        # 列出主要工具
        info "主要工具:"
        ls "${INSTALL_DIR}/bin/" | grep -E "^solana" | head -10 | while read -r tool; do
            echo "  - $tool"
        done
    else
        error "验证失败：无法找到 solana 命令"
    fi
}

# 清理临时文件
cleanup() {
    info "清理临时编译文件..."

    local build_dir="/tmp/solana-build"

    if [[ -d "$build_dir" ]]; then
        info "删除临时编译目录: $build_dir"
        rm -rf "$build_dir"
        info "✅ 临时文件已清理"
    fi
}

# 显示后续步骤
show_next_steps() {
    echo ""
    highlight "============================================"
    highlight "  后续步骤"
    highlight "============================================"
    echo ""
    echo "1️⃣  重新加载 shell 配置:"
    echo "   ${GREEN}source ~/.bashrc${NC}  # 或 source ~/.zshrc"
    echo ""
    echo "2️⃣  验证安装:"
    echo "   ${GREEN}solana --version${NC}"
    echo ""
    echo "3️⃣  设置 Solana 网络配置:"
    echo "   ${GREEN}# Mainnet${NC}"
    echo "   ${GREEN}solana config set --url https://api.mainnet-beta.solana.com${NC}"
    echo ""
    echo "   ${GREEN}# Devnet${NC}"
    echo "   ${GREEN}solana config set --url https://api.devnet.solana.com${NC}"
    echo ""
    echo "4️⃣  创建钱包 (可选):"
    echo "   ${GREEN}solana-keygen new${NC}"
    echo ""
    echo "5️⃣  查看配置:"
    echo "   ${GREEN}solana config get${NC}"
    echo ""
    highlight "安装信息:"
    echo "  版本:         ${SOLANA_VERSION}"
    echo "  安装目录:     ${INSTALL_DIR}"
    echo "  二进制文件:   ${INSTALL_DIR}/bin/"
    echo ""
    info "🎉 安装完成！祝您使用愉快！"
    echo ""
}

# 主函数
main() {
    show_welcome
    select_version
    confirm_installation
    check_root
    check_system

    # 1. 先安装系统依赖
    install_dependencies

    # 2. 再安装 Rust 工具链（依赖系统库）
    install_rust

    # 3. 创建安装目录
    create_install_directory

    # 4. 下载和编译
    download_source
    build_solana

    # 5. 配置和验证
    setup_environment
    verify_installation

    # 6. 清理临时文件和完成
    cleanup
    show_next_steps
}

# 执行主函数
main "$@"
