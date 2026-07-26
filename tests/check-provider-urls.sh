#!/usr/bin/env bash
# Live canary: download provider bootstrap scripts without executing them.
set -u

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

check_installer(){
  local name="$1" url="$2" allowed_prefix="$3" marker="$4"
  local file="$WORK/${name}.installer" final_url

  final_url="$(
    curl -fsSL --proto '=https' --tlsv1.2 \
      --connect-timeout 10 --max-time 60 \
      -o "$file" -w '%{url_effective}' "$url"
  )"

  case "$final_url" in
    "$allowed_prefix"*) ;;
    *)
      echo "FAIL: $name redirected to unexpected URL: $final_url" >&2
      return 1;;
  esac
  if ! grep -Eiq "$marker" "$file"; then
    echo "FAIL: $name installer does not contain expected product marker: $marker" >&2
    return 1
  fi
  echo "PASS: $name -> $final_url"
}

check_installer \
  qwen \
  "https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen-standalone.sh" \
  "https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/" \
  "qwen"

check_installer \
  kimi \
  "https://code.kimi.com/kimi-code/install.sh" \
  "https://cdn.kimi.com/kimi-code/" \
  "kimi-code"

check_installer \
  codebuddy \
  "https://www.codebuddy.cn/cli/install.sh" \
  "https://www.codebuddy.cn/cli/" \
  "codebuddy"
