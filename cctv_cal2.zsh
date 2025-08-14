#!/bin/zsh

trim() { print -r -- "${1#"${1%%[![:space:]]*}"}" | sed 's/[[:space:]]*$//'; }

# ค่าดีฟอลต์
DEFAULT_ENCODING="H.265+"
DEFAULT_RES="2MP"
DEFAULT_BITRATE=2048

ENCODING_OPTIONS=("H.264" "H.264+" "H.265" "H.265+" )
RES_OPTIONS=("1MP" "2MP" "3MP" "4MP" "8MP")

print "------------------------------------------------------------"
print "📹 คำนวณขนาด HDD ที่ต้องใช้ (โหมดที่ 2)"
print "------------------------------------------------------------"

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

# เก็บข้อมูลกล้อง
typeset -A CH_ENCODING CH_RES CH_BITRATE

for (( ch=1; ch<=CAM_COUNT; ch++ )); do
  if (( ch == 1 )); then
    prev_enc="$DEFAULT_ENCODING"
    prev_res="$DEFAULT_RES"
    prev_bitrate="$DEFAULT_BITRATE"
  else
    prev_enc="$CH_ENCODING[$((ch-1))]"
    prev_res="$CH_RES[$((ch-1))]"
    prev_bitrate="$CH_BITRATE[$((ch-1))]"
  fi

  print "------------------------------------------------------------"
  print "ข้อมูลกล้อง Ch $ch (กด Enter เพื่อใช้ค่ากล้องก่อนหน้า: $prev_enc / $prev_res / ${prev_bitrate} kbps)"

  # Encoding
  local enc_input=""
  vared -p "เลือก Encoding mode (1:H.264, 2:H.264+, 3:H.265, 4:H.265+) [$prev_enc]: " -c enc_input
  enc_input="$(trim "$enc_input")"
  if [[ -z "$enc_input" ]]; then
    CH_ENCODING[$ch]="$prev_enc"
  elif [[ "$enc_input" =~ '^[1-4]$' ]]; then
    CH_ENCODING[$ch]="${ENCODING_OPTIONS[$enc_input]}"
  else
    CH_ENCODING[$ch]="$enc_input"
  fi

  # Resolution
  local res_input=""
  vared -p "เลือก Resolution (1:1MP, 2:2MP, 3:3MP, 4:4MP, 5:8MP) [$prev_res]: " -c res_input
  res_input="$(trim "$res_input")"
  if [[ -z "$res_input" ]]; then
    CH_RES[$ch]="$prev_res"
  elif [[ "$res_input" =~ '^[1-5]$' ]]; then
    CH_RES[$ch]="${RES_OPTIONS[$res_input]}"
  else
    CH_RES[$ch]="$res_input"
  fi

  # Bitrate
  local br_input=""
  vared -p "กรอก Bitrate (kbps) [$prev_bitrate]: " -c br_input
  br_input="$(trim "$br_input")"
  if [[ -z "$br_input" ]]; then
    CH_BITRATE[$ch]=$prev_bitrate
  else
    CH_BITRATE[$ch]=$br_input
  fi
done

# จำนวนวัน (เริ่มว่าง ไม่ preload 0)
integer DAYS
while true; do
  local input=""
  vared -p "จำนวนวันที่ต้องการเก็บ: " -c input
  input="$(trim "$input")"
  if [[ "$input" =~ '^[0-9]+$' && $input -ge 1 ]]; then
    DAYS=$input
    break
  fi
  print -r -- "❌ ใส่จำนวนเต็มตั้งแต่ 1 ขึ้นไป"
done

# คำนวณ HDD
total_bitrate=0
for (( ch=1; ch<=CAM_COUNT; ch++ )); do
  (( total_bitrate += CH_BITRATE[$ch] ))
done

# kbps → bytes/sec
total_bps=$(( total_bitrate * 1000 ))
total_Bps=$(( total_bps / 8 ))

# ความจุรวม = bytes/sec * sec/day * days
total_bytes=$(( total_Bps * 86400 * DAYS ))
TB_required=$(echo "scale=2; $total_bytes / (10^12)" | bc -l)
TB_overhead=$(echo "scale=2; $TB_required * 1.3" | bc -l)

# แสดงผล
print "------------------------------------------------------------"
print "📦 สรุปอินพุต"
print "จำนวนกล้อง: $CAM_COUNT"
for (( ch=1; ch<=CAM_COUNT; ch++ )); do
  print "Ch $ch → ${CH_ENCODING[$ch]} / ${CH_RES[$ch]} / ${CH_BITRATE[$ch]} kbps"
done
print "จำนวนวันที่ต้องการ: $DAYS"
print "------------------------------------------------------------"
print "💾 ต้องใช้ HDD: ประมาณ ${TB_required} TB (ฐาน 10)"
print "💡 แนะนำเผื่อ Overhead → ${TB_overhead} TB"
print "------------------------------------------------------------"
print "หมายเหตุ:"
print " 1 kbps = 1000 bps, 1 byte = 8 bits, 1 TB = 10^12 bytes"
print " Overhead เผื่อ VBR, motion, audio, filesystem metadata"