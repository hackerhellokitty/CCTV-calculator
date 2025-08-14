#!/usr/bin/env zsh
# CCTV Bandwidth Calculator (Mode 3)
# Input: จำนวนกล้อง + บิตเรต (kbps) ต่อกล้อง (ไม่ถามการบีบอัด)
# Output: แบนด์วิดธ์รวม (Mbps) + เผื่อหัว (headroom)
clear

set -euo pipefail

trim() { local s="$1"; s="${s##[[:space:]]}"; s="${s%%[[:space:]]}"; print -r -- "$s"; }
print_hr() { print -r -- "------------------------------------------------------------"; }

DEFAULT_KBPS=2048     # 2 Mbps ต่อกล้อง เป็นค่าเริ่มต้นที่ใช้งานบ่อย
HEADROOM_FACTOR=1.2   # เผื่อหัว 20% สำหรับสเปก NVR

print_hr
print -r -- "📶 คำนวณแบนด์วิดธ์รวม (โหมดที่ 3)"
print_hr

# จำนวนกล้อง (เริ่มว่าง ไม่ preload 0)
integer CAM_COUNT
while true; do
  local input=""
  vared -p "จำนวนกล้องที่ใช้งานจริง: " -c input
  input="$(trim "$input")"
  if [[ "$input" =~ '^[0-9]+$' && $input -ge 1 ]]; then
    CAM_COUNT=$input
    break
  fi
  print -r -- "❌ ใส่จำนวนเต็มตั้งแต่ 1 ขึ้นไป"
done
print_hr

# เลือกโหมดกรอก: ใช้บิตเรตเดียวกันทุกกล้อง หรือกำหนดรายตัว
use_one="y"
vared -p "ใช้บิตเรตเดียวกันทุกกล้องหรือไม่? [Y/n]: " -c use_one
use_one="${use_one:l}"
[[ -z "$use_one" || "$use_one" == "y" || "$use_one" == "yes" ]] && use_one="y" || use_one="n"

typeset -A CH_KBPS

if [[ "$use_one" == "y" ]]; then
  # รับครั้งเดียว ใช้กับทุกกล้อง
  local br=""
  while true; do
    vared -p "บิตเรตต่อกล้อง (kbps) [$DEFAULT_KBPS]: " -c br
    br="$(trim "$br")"
    [[ -z "$br" ]] && br="$DEFAULT_KBPS"
    if [[ "$br" =~ '^[0-9]+([.][0-9]+)?$' && $(printf '%.0f' "$br") -gt 0 ]]; then
      break
    fi
    print -r -- "❌ ใส่เลขมากกว่า 0 เช่น 1024, 2048, 4096"
  done
  for (( ch=1; ch<=CAM_COUNT; ch++ )); do
    CH_KBPS[$ch]="$br"
  done
else
  # รับรายกล้อง: กล้องแรก default 2048, กล้องถัดไปกด Enter เพื่อคัดลอกค่าก่อนหน้า
  local last_kbps="$DEFAULT_KBPS"
  for (( ch=1; ch<=CAM_COUNT; ch++ )); do
    print -r -- "ข้อมูลกล้อง Ch $ch (กด Enter เพื่อใช้ค่าเดิม: ${last_kbps} kbps)"
    local br=""
    while true; do
      vared -p "บิตเรต (kbps) [$last_kbps]: " -c br
      br="$(trim "$br")"
      [[ -z "$br" ]] && br="$last_kbps"
      if [[ "$br" =~ '^[0-9]+([.][0-9]+)?$' && $(printf '%.0f' "$br") -gt 0 ]]; then
        CH_KBPS[$ch]="$br"
        last_kbps="$br"
        break
      fi
      print -r -- "❌ ใส่เลขมากกว่า 0 เช่น 1024, 2048, 4096"
    done
    print_hr
  done
fi

# รวมบิตเรต
total_kbps=0
for (( ch=1; ch<=CAM_COUNT; ch++ )); do
  total_kbps=$(( total_kbps + ${CH_KBPS[$ch]%.*} ))
done

# แปลงเป็น Mbps (ฐาน 10)
# 1 Mbps = 1000 kbps
total_mbps=$(echo "scale=2; $total_kbps / 1000.0" | bc)
total_mbps_headroom=$(echo "scale=2; $total_mbps * $HEADROOM_FACTOR" | bc)

# รายงาน
print_hr
print -r -- "📦 สรุปอินพุต"
print -r -- "จำนวนกล้อง: $CAM_COUNT"
for (( ch=1; ch<=CAM_COUNT; ch++ )); do
  print -r -- "Ch $ch → ${CH_KBPS[$ch]} kbps (≈ $(echo "scale=3; ${CH_KBPS[$ch]} / 1000.0" | bc) Mbps)"
done
print_hr
print -r -- "📊 แบนด์วิดธ์รวม: ${total_mbps} Mbps"
print -r -- "💡 แนะนำเผื่อหัว (×${HEADROOM_FACTOR}): ${total_mbps_headroom} Mbps"
print -r -- "🧰 เช็คสเปก NVR: Throughput รองรับ ≥ ${total_mbps_headroom} Mbps จะสบายกว่า"
print_hr
print -r -- "หมายเหตุ:"
print -r -- "- คิดแบบฐาน 10: 1 Mbps = 1000 kbps"
print -r -- "- เผื่อหัว 20% ไว้กัน peak/VBR และสำรองในระบบจริง"
print_hr
