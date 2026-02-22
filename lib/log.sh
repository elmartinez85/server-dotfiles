#!/usr/bin/env bash
if [[ -n "${_LIB_LOG_LOADED:-}" ]]; then return 0; fi
_LIB_LOG_LOADED=1

# Color codes — only emit when stdout is a terminal
if [[ -t 1 ]]; then
  _RED="\033[0;31m"
  _GREEN="\033[0;32m"
  _YELLOW="\033[0;33m"
  _BLUE="\033[0;34m"
  _BOLD="\033[1m"
  _RESET="\033[0m"
else
  _RED="" _GREEN="" _YELLOW="" _BLUE="" _BOLD="" _RESET=""
fi

log_info()    { echo -e "${_BLUE}  [INFO]${_RESET} $*"; }
log_success() { echo -e "${_GREEN}  ✓ ${_RESET} $*"; }
log_warn()    { echo -e "${_YELLOW}  [WARN]${_RESET} $*"; }
log_error()   { echo -e "${_RED}  [ERROR]${_RESET} $*" >&2; }
log_step()    { echo -e "\n${_BOLD}==> $*${_RESET}"; }
