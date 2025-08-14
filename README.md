# 📹 CCTV Storage & Bandwidth Calculator (Zsh)

สคริปต์ **Zsh ตัวเดียว** (`main.zsh`) สำหรับคำนวณ 3 โหมดในโปรแกรมเดียว:

1. **โหมดที่ 1:** คำนวณระยะเวลาที่สามารถบันทึกได้ (เมื่อรู้ขนาด HDD)  
2. **โหมดที่ 2:** คำนวณขนาด HDD ที่ต้องใช้ (เมื่อรู้จำนวนวันที่ต้องการ)  
3. **โหมดที่ 3:** คำนวณ Bandwidth รวมของระบบ (ใช้สำหรับเลือกเครื่องบันทึกให้รองรับได้)

> เหมาะสำหรับทำ **BOM**, ประเมิน **HDD**, และตรวจสอบ **Throughput ของ NVR/DVR**  
> แนวคิด: *“เครื่องมือคำนวณแบบวิศวกร แต่ใช้ง่ายแบบช่าง”* — กด Enter รัว ๆ ก็จบงาน

---

## ✨ จุดเด่น

- อินพุตเข้าใจง่าย (มีค่า **default** และ **คัดลอกค่ากล้องก่อนหน้า** ได้)
- รองรับทั้ง **คำนวณวัน**, **คำนวณ HDD**, และ **คำนวณแบนด์วิดธ์**
- **บันทึกรายงานอัตโนมัติ** เป็น `.txt` และ `.csv` (เลือกได้หลังคำนวณ)
- ชื่อไฟล์รายงานรวม **ชื่อโปรเจกต์ + วันที่เวลา + โหมด** เพื่อค้นหาย้อนหลังง่าย

---

## 🧩 ข้อกำหนดระบบ

- macOS / Linux ที่มี **Zsh**  
- เครื่องต้องมีคำสั่ง `bc` (ส่วนใหญ่มีอยู่แล้ว; ถ้าไม่มีให้ติดตั้งเพิ่ม)

---

## 🚀 วิธีใช้งาน

### 1) ให้สิทธิ์รันสคริปต์
```bash
chmod +x main.zsh
```

### 2) รันสคริปต์
```bash
./main.zsh
```

ระบบจะให้กรอก **ชื่อโปรเจกต์** 1 ครั้ง แล้วแสดงเมนูให้เลือกโหมด:

```
เลือกโหมดการคำนวณ
  1) คำนวณระยะเวลาบันทึก (จาก HDD)
  2) คำนวณ HDD ที่ต้องใช้ (จากจำนวนวัน)
  3) คำนวณแบนด์วิดธ์รวม (Mbps)
  0) ออก
```

---

## 📝 การสร้างรายงาน (Reports)

หลังคำนวณเสร็จแต่ละโหมด ระบบจะถามว่าอยากบันทึกรายงานไหม  
ถ้าตอบ **Yes** จะสร้างไฟล์ในโฟลเดอร์ `reports/` อัตโนมัติ:

```
<ชื่อโปรเจกต์>_<YYYYMMDD-HHMMSS>_mode<1|2|3>.txt
<ชื่อโปรเจกต์>_<YYYYMMDD-HHMMSS>_mode<1|2|3>.csv
```

ตัวอย่าง:
```
reports/ติดกล้องบ้านนายเอ็กซ์_20250814-153000_mode2.txt
reports/ติดกล้องบ้านนายเอ็กซ์_20250814-153000_mode2.csv
```

- `.txt` อ่านสรุปได้ไว (ส่งลูกค้าหรือแนบเอกสารได้เลย)  
- `.csv` นำเข้า Excel/Google Sheets ต่อได้ทันที

---

## 📌 สมมติฐาน/นิยามหน่วย

- 1 **kbps** = 1000 **bps**  
- 1 **byte** = 8 **bits**  
- 1 **TB (ฐาน 10)** = \(10^{12}\) **bytes**  
- ผลจริงขึ้นกับ **VBR**, **Motion**, **เสียง**, และ **Overhead** ของระบบ/ไฟล์ระบบ/NVR  
- โหมดที่ 3 คิดแบนด์วิดธ์รวม **ฐาน 10** (1 Mbps = 1000 kbps) และแนะนำ **เผื่อหัว 20%**

---

## 🖥 ตัวอย่างหน้าจอ

```text
./main.zsh
------------------------------------------------------------
📹 CCTV Calculator
------------------------------------------------------------
เลือกโหมด:
1) คำนวณระยะเวลาบันทึกจาก HDD
2) คำนวณขนาด HDD จากจำนวนวัน
3) คำนวณ Bandwidth รวม
พิมพ์หมายเลข (1-3): 2
...
📦 สรุปอินพุต
จำนวนกล้อง: 4
...
💾 ต้องใช้ HDD: ประมาณ 2.65 TB (ฐาน 10)
💡 แนะนำเผื่อ Overhead → 3.44 TB
------------------------------------------------------------
```

---

## 🧰 ทริคเล็ก ๆ

- หน้างานถ้า **ทุกกล้องสเปคเดียวกัน** ให้เลือก “ใช้ค่าเดิมทุกกล้อง” จะเร็วมาก  
- ถ้าต้องเลือก NVR ให้ดูทั้ง **จำนวนช่อง** และ **Throughput (Mbps)** จากผล **โหมด 3**  
- ทำ BOM ให้ปัดขึ้นเป็นขนาด HDD ที่มีขายจริง (1/2/4/6/8/10/12 TB)

---

## 🗓 เวอร์ชัน

- **เวอร์ชัน:** 1.0  
- **อัปเดตล่าสุด:** 2025-08-14

---

## ⚖️ ลิขสิทธิ์ (Public Domain)

งานชิ้นนี้เผยแพร่ภายใต้ **The Unlicense** — คุณสามารถคัดลอก ดัดแปลง เผยแพร่ นำไปใช้เชิงพาณิชย์ หรือทำสิ่งใด ๆ ได้โดยไม่ต้องขออนุญาต

**สรุปสั้น ๆ:** *อยากจะทำอะไรก็เชิญ ไม่หวง*

ดูรายละเอียดฉบับเต็มได้ในไฟล์ `LICENSE` หรืออ่านด้านล่าง:

```
This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain. We make this dedication for the benefit
of the public at large and to the detriment of our heirs and
successors. We intend this dedication to be an overt act of
relinquishment in perpetuity of all present and future rights to this
software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

For more information, please refer to <https://unlicense.org>
```
