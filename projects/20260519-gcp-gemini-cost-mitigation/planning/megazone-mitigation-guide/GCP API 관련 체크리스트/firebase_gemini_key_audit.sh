#!/usr/bin/env bash
# firebase_gemini_key_audit.sh
#
# 24년 5월 이전 생성된 unrestricted Firebase/Google API Key가
# Gemini(Generative Language) API 호출에 악용되는 취약점을 점검하는 Read-only 스크립트.
#
# 사용법:
#   ./firebase_gemini_key_audit.sh -p PROJECT_ID            # 단일 프로젝트
#   ./firebase_gemini_key_audit.sh --all                    # 접근 가능한 모든 프로젝트
#   ./firebase_gemini_key_audit.sh --all --csv report.csv   # CSV 리포트 생성
#   ./firebase_gemini_key_audit.sh -p PROJECT_ID --skip-metrics  # Monitoring 조회 생략
#
# 요구 사항: gcloud, jq, (선택) bq
# 권한: apikeys.keys.list, serviceusage.services.list, monitoring.timeSeries.list

set -euo pipefail

# ---------- constants ----------
LEGACY_CUTOFF="2024-05-01T00:00:00Z"
GEMINI_API="generativelanguage.googleapis.com"
VERTEX_API="aiplatform.googleapis.com"
METRIC_LOOKBACK_DAYS=7

# ---------- color ----------
if [[ -t 1 ]]; then
  C_RED=$'\033[31m'; C_YEL=$'\033[33m'; C_GRN=$'\033[32m'
  C_CYN=$'\033[36m'; C_BLD=$'\033[1m';  C_RST=$'\033[0m'
else
  C_RED=""; C_YEL=""; C_GRN=""; C_CYN=""; C_BLD=""; C_RST=""
fi

# ---------- args ----------
PROJECT_ID=""
SCAN_ALL=0
CSV_OUT=""
SKIP_METRICS=0

usage() {
  sed -n '2,15p' "$0"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--project) PROJECT_ID="${2:-}"; shift 2 ;;
    --all)        SCAN_ALL=1; shift ;;
    --csv)        CSV_OUT="${2:-}"; shift 2 ;;
    --skip-metrics) SKIP_METRICS=1; shift ;;
    -h|--help)    usage ;;
    *) echo "Unknown arg: $1" >&2; usage ;;
  esac
done

if [[ -z "$PROJECT_ID" && $SCAN_ALL -eq 0 ]]; then
  echo "${C_RED}ERROR${C_RST}: -p PROJECT_ID 또는 --all 중 하나를 지정해야 합니다." >&2
  usage
fi

# ---------- preflight ----------
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "${C_RED}ERROR${C_RST}: '$1' 명령이 필요합니다." >&2
    exit 2
  }
}
require_cmd gcloud
require_cmd jq

ACTIVE_ACCOUNT="$(gcloud config get-value account 2>/dev/null || true)"
if [[ -z "$ACTIVE_ACCOUNT" || "$ACTIVE_ACCOUNT" == "(unset)" ]]; then
  echo "${C_RED}ERROR${C_RST}: gcloud 로그인 상태가 아닙니다. 'gcloud auth login' 후 다시 실행하세요." >&2
  exit 2
fi
echo "${C_CYN}Active account:${C_RST} $ACTIVE_ACCOUNT"

# ---------- target projects ----------
if [[ $SCAN_ALL -eq 1 ]]; then
  echo "${C_CYN}Listing accessible projects...${C_RST}"
  TARGET_PROJECTS=()
  while IFS= read -r _p; do
    [[ -n "$_p" ]] && TARGET_PROJECTS+=("$_p")
  done < <(gcloud projects list --format="value(projectId)" 2>/dev/null | sort -u)
  if [[ ${#TARGET_PROJECTS[@]} -eq 0 ]]; then
    echo "${C_RED}ERROR${C_RST}: 접근 가능한 프로젝트가 없습니다." >&2
    exit 2
  fi
  echo "  -> ${#TARGET_PROJECTS[@]} project(s) found."
else
  TARGET_PROJECTS=("$PROJECT_ID")
fi

# ---------- csv header ----------
if [[ -n "$CSV_OUT" ]]; then
  echo "project_id,key_id,display_name,create_time,is_legacy,is_firebase_auto,app_restriction,api_restriction,gemini_allowed,gemini_enabled,vertex_enabled,recent_genlang_calls_7d,risk,recommended_action" > "$CSV_OUT"
fi

# ---------- helpers ----------
# date 플레이버 한 번만 감지
if date --version >/dev/null 2>&1; then
  DATE_FLAVOR="gnu"
else
  DATE_FLAVOR="bsd"
fi

date_to_epoch() {
  local s="$1"
  if [[ -z "$s" ]]; then
    echo 0
    return
  fi
  local out=""
  if [[ "$DATE_FLAVOR" == "gnu" ]]; then
    out="$(date -u -d "$s" +%s 2>/dev/null || true)"
  else
    # macOS BSD: 소수점 이하 및 trailing Z 제거 후 파싱
    local cleaned="${s%.*}"      # 소수점 이하 제거
    cleaned="${cleaned%Z}"        # trailing Z 제거
    cleaned="${cleaned%%+*}"      # +오프셋 제거
    out="$(date -u -j -f "%Y-%m-%dT%H:%M:%S" "$cleaned" +%s 2>/dev/null || true)"
  fi
  # 숫자만 추출 (개행/공백/에러 문구 방어)
  out="$(printf '%s' "$out" | tr -cd '0-9')"
  [[ -z "$out" ]] && out=0
  echo "$out"
}

CUTOFF_EPOCH="$(date_to_epoch "$LEGACY_CUTOFF")"
# 디버깅 편의용 sanity check
if [[ ! "$CUTOFF_EPOCH" =~ ^[0-9]+$ ]] || [[ "$CUTOFF_EPOCH" -eq 0 ]]; then
  echo "${C_RED}ERROR${C_RST}: CUTOFF_EPOCH 계산 실패 (date 파싱 문제). 값='$CUTOFF_EPOCH'" >&2
  exit 2
fi

is_api_enabled() {
  local proj="$1" api="$2"
  gcloud services list --enabled --project="$proj" \
    --filter="config.name:$api" --format="value(config.name)" 2>/dev/null \
    | grep -qx "$api"
}

# Cloud Monitoring으로 최근 N일간 generativelanguage 호출 합계
recent_genlang_calls() {
  local proj="$1"
  [[ $SKIP_METRICS -eq 1 ]] && { echo "skipped"; return; }

  local end_ts start_ts
  end_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if [[ "$DATE_FLAVOR" == "gnu" ]]; then
    start_ts="$(date -u -d "-${METRIC_LOOKBACK_DAYS} days" +%Y-%m-%dT%H:%M:%SZ)"
  else
    start_ts="$(date -u -v-${METRIC_LOOKBACK_DAYS}d +%Y-%m-%dT%H:%M:%SZ)"
  fi

  local resp
  resp="$(gcloud monitoring time-series list \
      --project="$proj" \
      --filter='metric.type="serviceruntime.googleapis.com/api/request_count" AND resource.labels.service="'"$GEMINI_API"'"' \
      --interval-start-time="$start_ts" \
      --interval-end-time="$end_ts" \
      --format=json 2>/dev/null || true)"

  if [[ -z "$resp" || "$resp" == "[]" ]]; then
    echo "0"
    return
  fi

  echo "$resp" | jq '[.[].points[].value.int64Value // .[].points[].value.doubleValue // 0 | tonumber] | add // 0'
}

# ---------- per-project audit ----------
audit_project() {
  local proj="$1"
  echo
  echo "${C_BLD}════════════════════════════════════════════════════════${C_RST}"
  echo "${C_BLD}Project: ${C_CYN}${proj}${C_RST}"
  echo "${C_BLD}════════════════════════════════════════════════════════${C_RST}"

  # 1. 위험 API 활성화 여부
  local gemini_on=0 vertex_on=0
  is_api_enabled "$proj" "$GEMINI_API" && gemini_on=1 || true
  is_api_enabled "$proj" "$VERTEX_API" && vertex_on=1 || true

  printf "  Generative Language API : %s\n" \
    "$( [[ $gemini_on -eq 1 ]] && echo "${C_RED}ENABLED${C_RST}" || echo "${C_GRN}disabled${C_RST}" )"
  printf "  Vertex AI API           : %s\n" \
    "$( [[ $vertex_on -eq 1 ]] && echo "${C_YEL}ENABLED${C_RST}" || echo "${C_GRN}disabled${C_RST}" )"

  # 2. API Key 인벤토리
  local keys_json raw_json
  raw_json="$(gcloud services api-keys list --project="$proj" --format=json 2>/dev/null || echo '[]')"
  # gcloud가 location별로 여러 JSON 배열을 이어 출력하는 경우가 있어 slurp으로 병합
  keys_json="$(printf '%s' "$raw_json" | jq -s 'add // []' 2>/dev/null || echo '[]')"
  local key_count
  key_count="$(printf '%s' "$keys_json" | jq 'length' | tr -cd '0-9')"
  [[ -z "$key_count" ]] && key_count=0
  echo "  API Keys                : $key_count"

  if [[ "$key_count" -eq 0 ]]; then
    return
  fi

  # 3. 최근 호출량 (프로젝트당 1회 조회)
  local recent_calls=""
  if [[ $gemini_on -eq 1 ]]; then
    recent_calls="$(recent_genlang_calls "$proj")"
    echo "  Recent ${METRIC_LOOKBACK_DAYS}d Gemini calls  : ${recent_calls}"
  fi

  echo
  printf "  %-32s %-22s %-7s %-9s %-12s %-12s %-10s\n" \
    "KEY_ID/DisplayName" "CREATE_TIME" "LEGACY" "FB_AUTO" "APP_RESTR" "API_RESTR" "RISK"
  printf "  %s\n" "  ----------------------------------------------------------------------------------------------------------"

  # 각 키 평가
  echo "$keys_json" | jq -c '.[]' | while read -r key; do
    local key_name display create_time create_epoch is_legacy is_fb
    local app_restr api_restr api_targets gemini_allowed risk action key_id

    key_name="$(echo "$key" | jq -r '.name // empty')"
    key_id="${key_name##*/}"
    display="$(echo "$key" | jq -r '.displayName // "(no name)"')"
    create_time="$(echo "$key" | jq -r '.createTime // empty')"

    if [[ -n "$create_time" ]]; then
      create_epoch="$(date_to_epoch "$create_time")"
    else
      create_epoch=0
    fi
    if [[ "$create_epoch" -gt 0 && "$create_epoch" -lt "$CUTOFF_EPOCH" ]]; then
      is_legacy="YES"
    else
      is_legacy="no"
    fi

    if echo "$display" | grep -qiE 'auto.created by firebase|firebase.*api.key|android key.*auto'; then
      is_fb="YES"
    else
      is_fb="no"
    fi

    # Application restrictions
    if echo "$key" | jq -e '.restrictions | (.browserKeyRestrictions // .serverKeyRestrictions // .androidKeyRestrictions // .iosKeyRestrictions)' >/dev/null 2>&1; then
      app_restr="SET"
    else
      app_restr="${C_YEL}NONE${C_RST}"
    fi

    # API restrictions
    api_targets="$(echo "$key" | jq -r '.restrictions.apiTargets // [] | map(.service) | join(",")')"
    if [[ -z "$api_targets" ]]; then
      api_restr="${C_RED}UNRESTRICTED${C_RST}"
      gemini_allowed="YES (no restriction)"
    else
      api_restr="restricted"
      if echo ",$api_targets," | grep -q ",$GEMINI_API,"; then
        gemini_allowed="YES (in allowlist)"
      else
        gemini_allowed="no"
      fi
    fi

    # 위험 등급
    risk="OK"
    action="-"
    local unrestricted=0
    [[ "$api_restr" == "${C_RED}UNRESTRICTED${C_RST}" ]] && unrestricted=1

    if [[ $gemini_on -eq 1 ]]; then
      if [[ "$is_legacy" == "YES" && $unrestricted -eq 1 ]]; then
        risk="${C_RED}CRITICAL${C_RST}"
        action="즉시 API restrictions 적용 (Firebase 관련 API만 허용) + 키 rotate"
      elif [[ $unrestricted -eq 1 ]]; then
        risk="${C_RED}HIGH${C_RST}"
        action="API restrictions 적용으로 Generative Language API 제외"
      elif [[ "$gemini_allowed" == "YES (in allowlist)" ]]; then
        risk="${C_RED}HIGH${C_RST}"
        action="API restrictions에서 Generative Language API 제거"
      elif [[ "$is_legacy" == "YES" ]]; then
        risk="${C_YEL}WARN${C_RST}"
        action="레거시 키 - restrictions 재검토 권장"
      fi
    else
      if [[ $unrestricted -eq 1 && "$is_legacy" == "YES" ]]; then
        risk="${C_YEL}WARN${C_RST}"
        action="Gemini API 비활성이지만 향후 활성화 시 위험 - restrictions 적용 권장"
      fi
    fi

    # 라벨 짧게
    local label="$key_id"
    [[ -n "$display" && "$display" != "(no name)" ]] && label="$key_id ($display)"
    label="${label:0:32}"

    printf "  %-32s %-22s %-7s %-9s %-12b %-12b %-10b\n" \
      "$label" "${create_time:0:19}" "$is_legacy" "$is_fb" "$app_restr" "$api_restr" "$risk"

    if [[ "$action" != "-" ]]; then
      printf "    └─ ${C_BLD}권장:${C_RST} %s\n" "$action"
    fi

    # CSV
    if [[ -n "$CSV_OUT" ]]; then
      # 컬러 제거된 평문값
      local app_plain api_plain risk_plain
      app_plain="$(echo "$key" | jq -e '.restrictions | (.browserKeyRestrictions // .serverKeyRestrictions // .androidKeyRestrictions // .iosKeyRestrictions)' >/dev/null 2>&1 && echo "SET" || echo "NONE")"
      api_plain="$([[ -z "$api_targets" ]] && echo "UNRESTRICTED" || echo "restricted:${api_targets}")"
      case "$risk" in
        *CRITICAL*) risk_plain="CRITICAL" ;;
        *HIGH*)     risk_plain="HIGH" ;;
        *WARN*)     risk_plain="WARN" ;;
        *)          risk_plain="OK" ;;
      esac
      printf '%s,%s,"%s",%s,%s,%s,%s,"%s",%s,%s,%s,%s,%s,"%s"\n' \
        "$proj" "$key_id" "${display//\"/\"\"}" "$create_time" \
        "$is_legacy" "$is_fb" "$app_plain" "$api_plain" \
        "$gemini_allowed" "$gemini_on" "$vertex_on" \
        "${recent_calls:-N/A}" "$risk_plain" "${action//\"/\"\"}" \
        >> "$CSV_OUT"
    fi
  done
}

# ---------- main loop ----------
SUMMARY_TOTAL=0
SUMMARY_CRIT=0
SUMMARY_HIGH=0
SUMMARY_WARN=0
SUMMARY_FILE="$(mktemp)"
trap 'rm -f "$SUMMARY_FILE"' EXIT

for proj in "${TARGET_PROJECTS[@]}"; do
  # 권한 부족/접근 불가 프로젝트는 스킵
  if ! gcloud projects describe "$proj" >/dev/null 2>&1; then
    echo "${C_YEL}WARN${C_RST}: '$proj' 접근 불가 - skip"
    continue
  fi

  # 서브쉘에서 카운트가 손실되지 않도록 audit 출력을 캡처
  audit_project "$proj" | tee -a "$SUMMARY_FILE"
done

# ---------- summary ----------
SUMMARY_CRIT=$(grep -c "CRITICAL" "$SUMMARY_FILE" || true)
SUMMARY_HIGH=$(grep -c "HIGH"     "$SUMMARY_FILE" || true)
SUMMARY_WARN=$(grep -c "WARN"     "$SUMMARY_FILE" || true)

echo
echo "${C_BLD}════════════════════════════════════════════════════════${C_RST}"
echo "${C_BLD}Audit Summary${C_RST}"
echo "${C_BLD}════════════════════════════════════════════════════════${C_RST}"
echo "  Projects scanned : ${#TARGET_PROJECTS[@]}"
echo "  ${C_RED}CRITICAL findings${C_RST} : $SUMMARY_CRIT"
echo "  ${C_RED}HIGH     findings${C_RST} : $SUMMARY_HIGH"
echo "  ${C_YEL}WARN     findings${C_RST} : $SUMMARY_WARN"
[[ -n "$CSV_OUT" ]] && echo "  CSV report       : $CSV_OUT"
echo
echo "${C_BLD}다음 단계 (수동 조치 권장):${C_RST}"
echo "  1) CRITICAL/HIGH 키 → Console > APIs & Services > Credentials"
echo "     - API restrictions 적용 (Firebase 관련 API만 허용)"
echo "     - Application restrictions(referrer/IP/app) 적용"
echo "  2) Gemini API를 사용하지 않는 프로젝트:"
echo "     gcloud services disable ${GEMINI_API} --project=PROJECT_ID"
echo "  3) 노출 이력 있는 키는 신규 발급 후 교체(rotate) 및 기존 키 삭제"
echo "  4) Billing Console에서 SKU 'Generate content*' 비정상 과금 확인"

# Exit code: CRITICAL/HIGH 있으면 1
if [[ $SUMMARY_CRIT -gt 0 || $SUMMARY_HIGH -gt 0 ]]; then
  exit 1
fi
exit 0
