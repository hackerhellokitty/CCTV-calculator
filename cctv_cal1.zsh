#!/usr/bin/env zsh
# CCTV Recording Days Calculator (Mode 1) — HDD = TB (ฐาน 10)
# Default ต่อกล้อง: Codec=H.265+, Resolution=2MP, Bitrate=2048 kbps
# กด Enter รับค่า default ได้ทันที และมีโหมดใช้ default กับทุกกล้อง
clear
set -euo pipefail

print_hr()   { print -r -- "------------------------------------------------------------"; }
say()        { print -r -- "$@"; }
say_err()    { print -r -- "$@" >&2; }

# HDD TB (ฐาน 10) → bytes
hdd_bytes_from_input() {
  local capacity="$1"
  echo $(( capacity * 1000000000000.0 ))   # 1 TB = 10^12 bytes
}

# kbps → bytes/sec
kbps_to_Bps() {
  local kbps="$1"
  echo $(( kbps * 1000.0 / 8.0 ))
}

# ตัดช่องว่างหัวท้าย
trim() {
  local s="$1"
  s="${s##[[:space:]]}"
  s="${s%%[[:space:]]}"
  print -r -- "$s"
}

# อ่านค่าพร้อม default (Enter = รับ default)
read_with_default() {
  local prompt="$1" default="$2" var
  vared -p "$prompt [$default]: " -c var
  var="$(trim "$var")"
  [[ -z "$var" ]] && var="$default"
  echo "$var"
}

# เมนูเลือก: รับได้ทั้งหมายเลขหรือชื่อ (ไม่สนตัวพิมพ์)
# รองรับ default: กด Enter เพื่อเลือกค่า default_value
choose_from_list_or_name_default() {
  local prompt="$1" default_value="$2"; shift 2
  local options=("$@")
  local lower_opts=()
  local i

  say_err "[เลือกจากรายการด้านล่าง: จะพิมพ์หมายเลข/ชื่อ หรือกด Enter รับค่าเริ่มต้น]"
  say_err "$prompt (ค่าเริ่มต้น: $default_value)"
  i=1
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

    # กด Enter = default
    if [[ -z "$choice" ]]; then
      echo "$default_value"
      return
    fi
    # เป็นหมายเลขในช่วง
    if [[ "$choice" =~ '^[0-9]+$' ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
      echo "${options[$choice]}"
      return
    fi
    # เป็นชื่อที่ตรง
    for idx in {1..${#options[@]}}; do
      if [[ "${lower_opts[$idx]}" == "$choice_l" ]]; then
        echo "${options[$idx]}"
        return
      fi
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

main() {
  print_hr
  say "📹 คำนวณระยะเวลาบันทึก (โหมดที่ 1) — HDD หน่วย TB (ฐาน 10)"
  print_hr

  # ความจุ HDD
  local hdd_capacity
  while true; do
    vared -p "ใส่ความจุ HDD (TB): " -c hdd_capacity
    hdd_capacity="$(trim "$hdd_capacity")"
    if [[ "$hdd_capacity" =~ '^[0-9]*([.][0-9]+)?$' ]] && [[ -n "$hdd_capacity" ]]; then
      break
    fi
    say_err "❌ ใส่ตัวเลขเท่านั้น เช่น 1, 2, 4, 6.5"
  done

  # จำนวนกล้องใช้งานจริง
  local cam_count
  while true; do
    vared -p "จำนวนกล้องที่ใช้งานจริง: " -c cam_count
    cam_count="$(trim "$cam_count")"
    if [[ "$cam_count" =~ '^[0-9]+$' ]] && (( cam_count >= 1 )); then
      break
    fi
    say_err "❌ ใส่จำนวนเต็มตั้งแต่ 1 ขึ้นไป"
  done

  # ตัวเลือก/ค่าเริ่มต้นตามที่ผู้ใช้กำหนด
  local codecs=("H.264" "H.264+" "H.265" "H.265+")
  local resolutions=("1MP" "2MP" "3MP" "4MP" "8MP")
  local default_codec="H.265+"
  local default_res="2MP"
  local default_kbps="2048"

  # โหมดลัด: ใช้ค่า default เดียวกันกับทุกกล้อง
  local use_defaults_for_all="no"
  if yes_no_default_yes "ใช้ค่าเริ่มต้นเดียวกันสำหรับทุกกล้องหรือไม่? (Codec=$default_codec, Res=$default_res, Bitrate=${default_kbps}kbps)"; then
    use_defaults_for_all="yes"
  fi

  typeset -a ch_codec ch_res ch_kbps

  if [[ "$use_defaults_for_all" == "yes" ]]; then
    # รับครั้งเดียว (เผื่ออยากเปลี่ยน default รอบนี้)
    print_hr
    say "ตั้งค่าเริ่มต้นรอบนี้ (กด Enter เพื่อใช้ค่าที่กำหนดไว้)"
    default_codec=$(choose_from_list_or_name_default "เลือก Encoding mode" "$default_codec" "${codecs[@]}")
    default_res=$(choose_from_list_or_name_default "เลือก Resolution" "$default_res" "${resolutions[@]}")
    default_kbps=$(read_with_default "กรอก Bitrate (kbps)" "$default_kbps")

    for (( ch=1; ch<=cam_count; ch++ )); do
      ch_codec[$ch]="$default_codec"
      ch_res[$ch]="$default_res"
      ch_kbps[$ch]="$default_kbps"
    done
  else
    # ตั้งค่าทีละกล้อง (Enter = รับค่า default ของแต่ละช่อง)
    for (( ch=1; ch<=cam_count; ch++ )); do
      print_hr
      say "ข้อมูลกล้อง Ch $ch"
      ch_codec[$ch]=$(choose_from_list_or_name_default "เลือก Encoding mode" "$default_codec" "${codecs[@]}")
      ch_res[$ch]=$(choose_from_list_or_name_default "เลือก Resolution" "$default_res" "${resolutions[@]}")
      local kbps
      while true; do
        kbps=$(read_with_default "กรอก Bitrate (kbps)" "$default_kbps")
        if [[ "$kbps" =~ '^[0-9]*([.][0-9]+)?$' ]] && (( $(printf '%.0f' "$kbps") > 0 )); then
          ch_kbps[$ch]="$kbps"
          break
        fi
        say_err "❌ ใส่ตัวเลขมากกว่า 0 เช่น 512, 1024, 2048, 4096, 8192"
      done
    done
  fi

  print_hr
  say "📦 สรุปอินพุต"
  say "HDD: $hdd_capacity TB (ฐาน 10)"
  say "จำนวนกล้อง: $cam_count"

  # คำนวณ
  local hdd_bytes total_kbps=0.0
  hdd_bytes=$(hdd_bytes_from_input "$hdd_capacity")
  for (( ch=1; ch<=cam_count; ch++ )); do
    total_kbps=$(( total_kbps + ch_kbps[$ch] ))
  done

  local total_Bps seconds_per_day=86400.0
  total_Bps=$(kbps_to_Bps "$total_kbps")
  if (( $(printf '%.0f' "$total_Bps") == 0 )); then
    say "❌ Bitrate รวมเป็นศูนย์ คำนวณไม่ได้"
    exit 1
  fi

  local days_all=$(( hdd_bytes / (total_Bps * seconds_per_day) ))
  local hours_all=$(( days_all * 24.0 ))

  # รายงานผลต่อช่อง และสรุปรวม
  print_hr
  say "🧾 รายงานต่อช่อง"
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
}

main "$@"