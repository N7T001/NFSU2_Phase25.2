NFSU2 iOS Phase 2.5 - Platform Smoke Test
==========================================
ไฟล์ชุดนี้เป็นแอปทดสอบ UIKit + Metal + การจอง address space 4 GB เท่านั้น ไม่ใช่เกม NFSU2

1. สร้าง GitHub repository ใหม่ เช่น NFSU2-iOS-Smoke (Private ได้)
2. อัปโหลด main.m, Info.plist และ .github/workflows/ios-smoke.yml โดยรักษาโครงสร้างโฟลเดอร์
   ทางเลือกง่าย: ใช้ Git บน Windows ตามคำสั่งในคำตอบของ ChatGPT
3. GitHub > Actions > NFSU2 iOS Phase 2.5 Smoke > Run workflow
4. ดาวน์โหลด Artifact NFSU2_Phase25_unsigned (GitHub ให้เป็น ZIP)
5. แตก ZIP แล้วจะพบ NFSU2_Phase25_unsigned.ipa
6. IPA นี้ยังไม่ได้เซ็น ต้องเซ็นด้วยใบรับรอง/Provisioning ที่ใช้กับอุปกรณ์ก่อนติดตั้ง
7. เปิดแอปแล้วส่งภาพ PASS/FAIL ทั้งสามค่า

หมายเหตุ: หาก mmap จอง 4 GB ไม่ได้ แอปจะรายงาน FAIL โดยไม่ถือว่าเป็น crash
ไม่รวมข้อมูลเกม, executable ของเกม, หรือ lifted shards
