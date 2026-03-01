#!/bin/bash
# ==========================================
# Module 00: Logger Utilities
# ==========================================

# Определение цветовых кодов
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[0;33m'
readonly C_BLUE='\033[0;34m'
readonly C_CYAN='\033[0;36m'
readonly C_NC='\033[0m' # No Color

log_info() {
    echo -e "${C_CYAN}[INFO]${C_NC} $1"
}

log_success() {
    echo -e "${C_GREEN}[SUCCESS]${C_NC} $1"
}

log_warn() {
    echo -e "${C_YELLOW}[WARN]${C_NC} $1"
}

log_error() {
    echo -e "${C_RED}[ERROR]${C_NC} $1" >&2
}

log_section() {
    echo -e "\n${C_BLUE}==========================================${C_NC}"
    echo -e "${C_BLUE}$1${C_NC}"
    echo -e "${C_BLUE}==========================================${C_NC}"
}