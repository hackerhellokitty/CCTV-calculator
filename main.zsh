#!/usr/bin/env zsh
# main.zsh — CCTV quick calculators with project-aware report export (txt + csv)
# Modes:
# 1) Recording days (from HDD)
# 2) Required HDD (from days)
# 3) Total bandwidth (Mbps)
clear
set -euo pipefail

# ---------- Helpers ----------
print_hr()   { print -r -- "------------------------------------------------------------"; }
say()        { print -r -- "$@"; }
say_err()    { print -r -- "$@" >&2; }
trim()       { local s="$1"; s="${s##[[:space:]]}"; s="${s%%[[:space:]]}"; print -r -- "$s"; }
nowstamp()   { date "+%Y%m%d-%H%M%S"; }
ensure_reports_dir() { [[ -d reports ]] || mkdir -p reports; }

# sanitize project name for filenames
sanitize_for_filename() {
  local s="$1"
  # แทนช่องว่างด้วย _, ตัดอักขระต้องห้ามของชื่อไฟล์ทั่วไป
  s="${s// /_}"
  s="${s//\//-}"; s="${s//\\/ -}"
  s="${s//:/-}"; s="${s//\*/-}"; s="${s//\?/-}"
  s="${s//\"/-}"; s="${s//</-}"; s="${s//>/-}"; s="${s//|/-}"
  # บีบ _ ซ้ำ ๆ และตัด _ หัว/ท้าย
  s="$(print -r -- "$s" | sed 's/[_]\{2,\}/_/g; s/^_//; s/_$//')"
  print -r -- "$s"
}

# TB (base10) to bytes
hdd_bytes_from_input() { local cap="$1"; echo $(( cap * 1000000000000.0 )); }  # 1 TB = 10^12 bytes
# kbps to B/s
kbps_to_Bps() { local kbps="$1"; echo $(( kbps * 1000.0 / 8.0 )); }

# input with default (Enter accepts default)
read_with_default() {
  local prompt="$1" default="$2" var
  vared -p "$prompt [$default]: " -c var
  var="$(trim "$var")"
  [[ -z "$var" ]] && var="$default"
  echo "$var"
}

# List chooser with default (accept number or exact name, case-insensitive)
choose_from_list_or_name_default() {
  local prompt="$1" default_value="$2"; shift 2
  local options=("$@")
  local lower_opts=()
  local i=1
  say_err "[เลือกจากรายการด้านล่าง: จะพิมพ์หมายเลข/ชื่อ หรือกด Enter รับค่าเริ่มต้น]"
  say_err "$prompt (ค่าเริ่มต้น: $default_value)"
  for o in "${options[@]}"; do
    say_err "  $i) $o"
    lower_opts+=("${o:l}")
    (( i++ ))
  done
  local choice
  while true; do
    vared -p "พิมพ์หมายเลข (1-${#options[@]}) / พิมพ์ชื่อ / Enter ใช้ค่าเริ่มต้น: " -c choice
    choice="$(trim "$choice")"
    local choice_l="${choice:l}"
    if [[ -z "$choice" ]]; then echo "$default_value"; return; fi
    if [[ "$choice" =~ '^[0-9]+$' ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
      echo "${options[$choice]}"; return
    fi
    for idx in {1..${#options[@]}}; do
      if [[ "${lower_opts[$idx]}" == "$choice_l" ]]; then echo "${options[$idx]}"; return; fi
    done
    say_err "❌ เลือกไม่ถูกต้อง: พิมพ์หมายเลข 1-${#options[@]}, พิมพ์ชื่อให้ตรง, หรือกด Enter ใช้ค่าเริ่มต้น"
  done
}

yes_no_default_yes() {
  local prompt="$1" ans
  vared -p "$prompt [Y/n]: " -c ans
  ans="$(trim "${ans:l}")"
  [[ -z "$ans" || "$ans" == "y" || "$ans" == "yes" ]] && return 0 || return 1
}

# ---------- Global: Project ----------
PROJECT_NAME=""
PROJECT_SLUG=""
print_hr
say "🗂️  ตั้งค่าชื่อโปรเจกต์สำหรับรายงาน"
vared -p "ชื่อโปรเจกต์ (เช่น ติดกล้องบ้านนายเอ็กซ์): " -c PROJECT_NAME
PROJECT_NAME="$(trim "$PROJECT_NAME")"
[[ -z "$PROJECT_NAME" ]] && PROJECT_NAME="โปรเจกต์ไม่มีชื่อ"
PROJECT_SLUG="$(sanitize_for_filename "$PROJECT_NAME")"
say "📌 โปรเจกต์: $PROJECT_NAME"
print_hr

# ---------- Mode 1: HDD -> Days ----------
mode1() {
  local codecs=("H.264" "H.264+" "H.265" "H.265+")
  local resolutions=("1MP" "2MP" "3MP" "4MP" "8MP")
  local default_codec="H.265+"
  local default_res="2MP"
  local default_kbps="2048"

  print_hr; say "📹 คำนวณระยะเวลาบันทึก (โหมดที่ 1) — HDD หน่วย TB (ฐาน 10)"; print_hr

  local hdd_capacity
  while true; do
    vared -p "ใส่ความจุ HDD (TB): " -c hdd_capacity
    hdd_capacity="$(trim "$hdd_capacity")"
    if [[ "$hdd_capacity" =~ '^[0-9]*([.][0-9]+)?$' ]] && [[ -n "$hdd_capacity" ]]; then break; fi
    say_err "❌ ใส่ตัวเลขเท่านั้น เช่น 1, 2, 4, 6.5"
  done

  local cam_count
  while true; do
    vared -p "จำนวนกล้องที่ใช้งานจริง: " -c cam_count
    cam_count="$(trim "$cam_count")"
    if [[ "$cam_count" =~ '^[0-9]+$' ]] && (( cam_count >= 1 )); then break; fi
    say_err "❌ ใส่จำนวนเต็มตั้งแต่ 1 ขึ้นไป"
  done

  local use_defaults_for_all="no"
  if yes_no_default_yes "ใช้ค่าเริ่มต้นเดียวกันสำหรับทุกกล้องหรือไม่? (Codec=$default_codec, Res=$default_res, Bitrate=${default_kbps}kbps)"; then
    use_defaults_for_all="yes"
  fi

  typeset -a ch_codec ch_res ch_kbps

  if [[ "$use_defaults_for_all" == "yes" ]]; then
    print_hr; say "ตั้งค่าเริ่มต้นรอบนี้ (กด Enter เพื่อใช้ค่าที่กำหนดไว้)"
    default_codec=$(choose_from_list_or_name_default "เลือก Encoding mode" "$default_codec" "${codecs[@]}")
    default_res=$(choose_from_list_or_name_default "เลือก Resolution" "$default_res" "${resolutions[@]}")
    default_kbps=$(read_with_default "กรอก Bitrate (kbps)" "$default_kbps")
    for (( ch=1; ch<=cam_count; ch++ )); do
      ch_codec[$ch]="$default_codec"; ch_res[$ch]="$default_res"; ch_kbps[$ch]="$default_kbps"
    done
  else
    for (( ch=1; ch<=cam_count; ch++ )); do
      print_hr; say "ข้อมูลกล้อง Ch $ch"
      ch_codec[$ch]=$(choose_from_list_or_name_default "เลือก Encoding mode" "$default_codec" "${codecs[@]}")
      ch_res[$ch]=$(choose_from_list_or_name_default "เลือก Resolution" "$default_res" "${resolutions[@]}")
      local kbps
      while true; do
        kbps=$(read_with_default "กรอก Bitrate (kbps)" "$default_kbps")
        if [[ "$kbps" =~ '^[0-9]*([.][0-9]+)?$' ]] && (( $(printf '%.0f' "$kbps") > 0 )); then ch_kbps[$ch]="$kbps"; break; fi
        say_err "❌ ใส่ตัวเลขมากกว่า 0 เช่น 512, 1024, 2048, 4096, 8192"
      done
    done
  fi

  print_hr; say "📦 สรุปอินพุต"
  say "โปรเจกต์: $PROJECT_NAME"
  say "HDD: $hdd_capacity TB (ฐาน 10)"
  say "จำนวนกล้อง: $cam_count"

  local hdd_bytes total_kbps=0.0
  hdd_bytes=$(hdd_bytes_from_input "$hdd_capacity")
  for (( ch=1; ch<=cam_count; ch++ )); do total_kbps=$(( total_kbps + ch_kbps[$ch] )); done

  local total_Bps seconds_per_day=86400.0
  total_Bps=$(kbps_to_Bps "$total_kbps")
  if (( $(printf '%.0f' "$total_Bps") == 0 )); then say "❌ Bitrate รวมเป็นศูนย์ คำนวณไม่ได้"; return; fi

  local days_all=$(( hdd_bytes / (total_Bps * seconds_per_day) ))
  local hours_all=$(( days_all * 24.0 ))

  print_hr; say "🧾 รายงานต่อช่อง"
  for (( ch=1; ch<=cam_count; ch++ )); do
    local Bps_i=$(kbps_to_Bps "${ch_kbps[$ch]}")
    local days_if_only_this=$(( hdd_bytes / (Bps_i * seconds_per_day) ))
    say "Ch $ch"
    say "  Encoding mode : ${ch_codec[$ch]}"
    say "  Resolution    : ${ch_res[$ch]}"
    say "  Bitrate       : ${ch_kbps[$ch]} kbps"
    say "  ➤ เมื่อบันทึกทั้งระบบพร้อมกันทุกช่อง: ~$(printf '%.2f' "$days_all") วัน (≈ $(printf '%.1f' "$hours_all") ชม.)"
    say "  ➤ หากเก็บเฉพาะช่องนี้ช่องเดียว: ~$(printf '%.2f' "$days_if_only_this") วัน"
    print_hr
  done
  say "📊 สรุปทั้งระบบ"
  say "Bitrate รวม : $(printf '%.0f' "$total_kbps") kbps"
  say "บันทึกได้ประมาณ : $(printf '%.2f' "$days_all") วัน (≈ $(printf '%.1f' "$hours_all") ชั่วโมง)"
  print_hr
  say "หมายเหตุ:"
  say "- 1 kbps = 1000 bps, 1 byte = 8 bits, 1 TB = 10^12 bytes"
  say "- ผลจริงแปรผันตาม VBR/ความเคลื่อนไหวภาพ/เสียง/Overhead ของไฟล์ระบบและ NVR"
  print_hr

  # ----- Export report -----
  if yes_no_default_yes "ต้องการบันทึกรายงานเป็นไฟล์ไหม?"; then
    ensure_reports_dir
    local ts=$(nowstamp)
    local base="reports/${PROJECT_SLUG}_${ts}_mode1"
    local txt="${base}.txt"
    local csv="${base}.csv"

    {
      print "CCTV Report — Mode 1 (HDD → Days)"
      print "Project: $PROJECT_NAME"
      print_hr
      print "HDD: ${hdd_capacity} TB (base10)"
      print "Cameras: ${cam_count}"
      print "Total bitrate: ${total_kbps} kbps"
      print "Days (all channels): $(printf '%.2f' "$days_all") (≈ $(printf '%.1f' "$hours_all") hours)"
      print_hr
      for (( ch=1; ch<=cam_count; ch++ )); do
        local Bps_i=$(kbps_to_Bps "${ch_kbps[$ch]}")
        local days_if_only_this=$(( hdd_bytes / (Bps_i * seconds_per_day) ))
        print "Ch $ch: ${ch_codec[$ch]} / ${ch_res[$ch]} / ${ch_kbps[$ch]} kbps | If only this: $(printf '%.2f' "$days_if_only_this") days"
      done
      print_hr
      print "Note: 1 kbps=1000 bps; 1 TB=10^12 bytes; VBR/motion/audio/FS overhead varies."
    } > "$txt"

    {
      print "project,mode,camera,ch_codec,ch_res,bitrate_kbps,days_all,days_if_only_this"
      for (( ch=1; ch<=cam_count; ch++ )); do
        local Bps_i=$(kbps_to_Bps "${ch_kbps[$ch]}")
        local days_if_only_this=$(( hdd_bytes / (Bps_i * seconds_per_day) ))
        print "\"$PROJECT_NAME\",mode1,$ch,${ch_codec[$ch]},${ch_res[$ch]},${ch_kbps[$ch]},$(printf '%.2f' "$days_all"),$(printf '%.2f' "$days_if_only_this")"
      done
    } > "$csv"

    say "✅ บันทึกแล้ว: $txt และ $csv"
  fi
}

# ---------- Mode 2: Days -> HDD ----------
mode2() {
  local DEFAULT_ENCODING="H.265+"
  local DEFAULT_RES="2MP"
  local DEFAULT_BITRATE=2048
  local ENCODING_OPTIONS=("H.264" "H.264+" "H.265" "H.265+" )
  local RES_OPTIONS=("1MP" "2MP" "3MP" "4MP" "8MP")

  print_hr; say "📹 คำนวณขนาด HDD ที่ต้องใช้ (โหมดที่ 2)"; print_hr

  integer CAM_COUNT
  while true; do
    local input=""
    vared -p "จำนวนกล้องที่ใช้งานจริง: " -c input
    input="$(trim "$input")"
    if [[ "$input" =~ '^[0-9]+$' && $input -ge 1 ]]; then CAM_COUNT=$input; break; fi
    say "❌ ใส่จำนวนเต็มตั้งแต่ 1 ขึ้นไป"
  done

  typeset -A CH_ENCODING CH_RES CH_BITRATE
  for (( ch=1; ch<=CAM_COUNT; ch++ )); do
    if (( ch == 1 )); then
      prev_enc="$DEFAULT_ENCODING"; prev_res="$DEFAULT_RES"; prev_bitrate="$DEFAULT_BITRATE"
    else
      prev_enc="$CH_ENCODING[$((ch-1))]"; prev_res="$CH_RES[$((ch-1))]"; prev_bitrate="$CH_BITRATE[$((ch-1))]"
    fi

    print_hr; say "ข้อมูลกล้อง Ch $ch (กด Enter เพื่อใช้ค่ากล้องก่อนหน้า: $prev_enc / $prev_res / ${prev_bitrate} kbps)"

    local enc_input=""; vared -p "เลือก Encoding mode (1:H.264, 2:H.264+, 3:H.265, 4:H.265+) [$prev_enc]: " -c enc_input
    enc_input="$(trim "$enc_input")"
    if [[ -z "$enc_input" ]]; then CH_ENCODING[$ch]="$prev_enc"
    elif [[ "$enc_input" =~ '^[1-4]$' ]]; then CH_ENCODING[$ch]="${ENCODING_OPTIONS[$enc_input]}"
    else CH_ENCODING[$ch]="$enc_input"; fi

    local res_input=""; vared -p "เลือก Resolution (1:1MP, 2:2MP, 3:3MP, 4:4MP, 5:8MP) [$prev_res]: " -c res_input
    res_input="$(trim "$res_input")"
    if [[ -z "$res_input" ]]; then CH_RES[$ch]="$prev_res"
    elif [[ "$res_input" =~ '^[1-5]$' ]]; then CH_RES[$ch]="${RES_OPTIONS[$res_input]}"
    else CH_RES[$ch]="$res_input"; fi

    local br_input=""; vared -p "กรอก Bitrate (kbps) [$prev_bitrate]: " -c br_input
    br_input="$(trim "$br_input")"
    if [[ -z "$br_input" ]]; then CH_BITRATE[$ch]=$prev_bitrate; else CH_BITRATE[$ch]=$br_input; fi
  done

  integer DAYS
  print_hr
  while true; do
    local input=""
    vared -p "จำนวนวันที่ต้องการเก็บ: " -c input
    input="$(trim "$input")"
    if [[ "$input" =~ '^[0-9]+$' && $input -ge 1 ]]; then DAYS=$input; break; fi
    say "❌ ใส่จำนวนเต็มตั้งแต่ 1 ขึ้นไป"
  done

  local total_bitrate=0
  for (( ch=1; ch<=CAM_COUNT; ch++ )); do (( total_bitrate += CH_BITRATE[$ch] )); done

  local total_bps=$(( total_bitrate * 1000 ))
  local total_Bps=$(( total_bps / 8 ))
  local total_bytes=$(( total_Bps * 86400 * DAYS ))

  local TB_required=$(echo "scale=2; $total_bytes / (10^12)" | bc -l)
  local TB_overhead=$(echo "scale=2; $TB_required * 1.3" | bc -l)

  print_hr; say "📦 สรุปอินพุต"
  say "โปรเจกต์: $PROJECT_NAME"
  say "จำนวนกล้อง: $CAM_COUNT"
  for (( ch=1; ch<=CAM_COUNT; ch++ )); do
    say "Ch $ch → ${CH_ENCODING[$ch]} / ${CH_RES[$ch]} / ${CH_BITRATE[$ch]} kbps"
  done
  say "จำนวนวันที่ต้องการ: $DAYS"
  print_hr
  say "💾 ต้องใช้ HDD: ประมาณ ${TB_required} TB (ฐาน 10)"
  say "💡 แนะนำเผื่อ Overhead → ${TB_overhead} TB"
  print_hr
  say "หมายเหตุ:"
  say " 1 kbps = 1000 bps, 1 byte = 8 bits, 1 TB = 10^12 bytes"
  say " Overhead เผื่อ VBR, motion, audio, filesystem metadata"
  print_hr

  # ----- Export report -----
  if yes_no_default_yes "ต้องการบันทึกรายงานเป็นไฟล์ไหม?"; then
    ensure_reports_dir
    local ts=$(nowstamp)
    local base="reports/${PROJECT_SLUG}_${ts}_mode2"
    local txt="${base}.txt"
    local csv="${base}.csv"

    {
      print "CCTV Report — Mode 2 (Days → HDD)"
      print "Project: $PROJECT_NAME"
      print_hr
      print "Cameras: ${CAM_COUNT}"
      print "Days required: ${DAYS}"
      print "Total bitrate: ${total_bitrate} kbps"
      print "HDD required: ${TB_required} TB (base10)"
      print "Overhead (30%): ${TB_overhead} TB"
      print_hr
      for (( ch=1; ch<=CAM_COUNT; ch++ )); do
        print "Ch $ch: ${CH_ENCODING[$ch]} / ${CH_RES[$ch]} / ${CH_BITRATE[$ch]} kbps"
      done
      print_hr
      print "Note: 1 kbps=1000 bps; 1 TB=10^12 bytes; overhead accounts for VBR/motion/audio/FS."
    } > "$txt"

    {
      print "project,mode,camera,ch_codec,ch_res,bitrate_kbps,days,HDD_TB,HDD_TB_overhead"
      for (( ch=1; ch<=CAM_COUNT; ch++ )); do
        print "\"$PROJECT_NAME\",mode2,$ch,${CH_ENCODING[$ch]},${CH_RES[$ch]},${CH_BITRATE[$ch]},${DAYS},${TB_required},${TB_overhead}"
      done
    } > "$csv"

    say "✅ บันทึกแล้ว: $txt และ $csv"
  fi
}

# ---------- Mode 3: Total Bandwidth ----------
mode3() {
  local DEFAULT_KBPS=2048
  local HEADROOM_FACTOR=1.2

  print_hr; say "📶 คำนวณแบนด์วิดธ์รวม (โหมดที่ 3)"; print_hr

  integer CAM_COUNT
  while true; do
    local input=""
    vared -p "จำนวนกล้องที่ใช้งานจริง: " -c input
    input="$(trim "$input")"
    if [[ "$input" =~ '^[0-9]+$' && $input -ge 1 ]]; then CAM_COUNT=$input; break; fi
    say "❌ ใส่จำนวนเต็มตั้งแต่ 1 ขึ้นไป"
  done
  print_hr

  local use_one="y"
  vared -p "ใช้บิตเรตเดียวกันทุกกล้องหรือไม่? [Y/n]: " -c use_one
  use_one="${use_one:l}"
  [[ -z "$use_one" || "$use_one" == "y" || "$use_one" == "yes" ]] && use_one="y" || use_one="n"

  typeset -A CH_KBPS
  if [[ "$use_one" == "y" ]]; then
    local br=""
    while true; do
      vared -p "บิตเรตต่อกล้อง (kbps) [$DEFAULT_KBPS]: " -c br
      br="$(trim "$br")"; [[ -z "$br" ]] && br="$DEFAULT_KBPS"
      if [[ "$br" =~ '^[0-9]+([.][0-9]+)?$' && $(printf '%.0f' "$br") -gt 0 ]]; then break; fi
      say "❌ ใส่เลขมากกว่า 0 เช่น 1024, 2048, 4096"
    done
    for (( ch=1; ch<=CAM_COUNT; ch++ )); do CH_KBPS[$ch]="$br"; done
  else
    local last_kbps="$DEFAULT_KBPS"
    for (( ch=1; ch<=CAM_COUNT; ch++ )); do
      say "ข้อมูลกล้อง Ch $ch (กด Enter เพื่อใช้ค่าเดิม: ${last_kbps} kbps)"
      local br=""
      while true; do
        vared -p "บิตเรต (kbps) [$last_kbps]: " -c br
        br="$(trim "$br")"; [[ -z "$br" ]] && br="$last_kbps"
        if [[ "$br" =~ '^[0-9]+([.][0-9]+)?$' && $(printf '%.0f' "$br") -gt 0 ]]; then CH_KBPS[$ch]="$br"; last_kbps="$br"; break; fi
        say "❌ ใส่เลขมากกว่า 0 เช่น 1024, 2048, 4096"
      done
      print_hr
    done
  fi

  local total_kbps=0
  for (( ch=1; ch<=CAM_COUNT; ch++ )); do total_kbps=$(( total_kbps + ${CH_KBPS[$ch]%.*} )); done
  local total_mbps=$(echo "scale=2; $total_kbps / 1000.0" | bc)
  local total_mbps_headroom=$(echo "scale=2; $total_mbps * $HEADROOM_FACTOR" | bc)

  print_hr; say "📦 สรุปอินพุต"
  say "โปรเจกต์: $PROJECT_NAME"
  say "จำนวนกล้อง: $CAM_COUNT"
  for (( ch=1; ch<=CAM_COUNT; ch++ )); do
    say "Ch $ch → ${CH_KBPS[$ch]} kbps (≈ $(echo "scale=3; ${CH_KBPS[$ch]} / 1000.0" | bc) Mbps)"
  done
  print_hr
  say "📊 แบนด์วิดธ์รวม: ${total_mbps} Mbps"
  say "💡 แนะนำเผื่อหัว (×1.2): ${total_mbps_headroom} Mbps"
  say "🧰 เช็คสเปก NVR: Throughput รองรับ ≥ ${total_mbps_headroom} Mbps"
  print_hr
  say "หมายเหตุ:"
  say "- คิดแบบฐาน 10: 1 Mbps = 1000 kbps"
  say "- เผื่อหัว 20% ไว้กัน peak/VBR และสำรองในระบบจริง"
  print_hr

  # ----- Export report -----
  if yes_no_default_yes "ต้องการบันทึกรายงานเป็นไฟล์ไหม?"; then
    ensure_reports_dir
    local ts=$(nowstamp)
    local base="reports/${PROJECT_SLUG}_${ts}_mode3"
    local txt="${base}.txt"
    local csv="${base}.csv"

    {
      print "CCTV Report — Mode 3 (Total Bandwidth)"
      print "Project: $PROJECT_NAME"
      print_hr
      print "Cameras: ${CAM_COUNT}"
      print "Total bandwidth: ${total_mbps} Mbps"
      print "Recommended headroom (×1.2): ${total_mbps_headroom} Mbps"
      print_hr
      for (( ch=1; ch<=CAM_COUNT; ch++ )); do
        local km="${CH_KBPS[$ch]}"
        print "Ch $ch: ${km} kbps (≈ $(echo "scale=3; ${km}/1000.0" | bc) Mbps)"
      done
      print_hr
      print "Note: base10 units; headroom helps with VBR/peaks."
    } > "$txt"

    {
      print "project,mode,camera,bitrate_kbps,total_mbps,total_mbps_headroom"
      for (( ch=1; ch<=CAM_COUNT; ch++ )); do
        print "\"$PROJECT_NAME\",mode3,$ch,${CH_KBPS[$ch]},${total_mbps},${total_mbps_headroom}"
      done
    } > "$csv"

    say "✅ บันทึกแล้ว: $txt และ $csv"
  fi
}

# ---------- Main Menu ----------
while true; do
  print_hr
  say "เลือกโหมดการคำนวณ (โปรเจกต์: $PROJECT_NAME)"
  say "  1) คำนวณระยะเวลาบันทึก (จาก HDD)"
  say "  2) คำนวณ HDD ที่ต้องใช้ (จากจำนวนวัน)"
  say "  3) คำนวณแบนด์วิดธ์รวม (Mbps)"
  say "  0) ออก"
  local choice=""
  vared -p "พิมพ์หมายเลข: " -c choice
  choice="$(trim "$choice")"
  case "$choice" in
    1) mode1 ;;
    2) mode2 ;;
    3) mode3 ;;
    0) say "บ๊ายบาย 👋"; exit 0 ;;
    *) say_err "❌ เลือก 0, 1, 2 หรือ 3 เท่านั้น" ;;
  esac
done