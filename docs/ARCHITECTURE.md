# ผังทะเบียน SRC garage

ผังนี้ตรงกับโค้ดจริงใน `team-app.html` ณ 2026-09-06 · เก็บบน Artifact database (แชร์ทั้งทีม อัปเดตสด)

## ทะเบียนข้อมูล
| กลุ่ม | ทะเบียน (collection) | ฟิลด์ · type · required | กติกา |
|---|---|---|---|
| Master | `customers/<id>` | `name` str ✔ · `phone` str · `note` str · `createdAt`/`updatedAt` ISO · `sample` bool | `id` สร้างโดยระบบ คงที่ตลอดชีพ ไม่ผูกกับชื่อ · แก้ชื่อ/เบอร์แล้วรถและใบงานเดิมยังผูกอยู่ |
| Master | `vehicles/<id>` | `plate` str ✔ (ตามที่พิมพ์) · `plateKey` str ✔ (unique) · `brand` · `model` · `color` str · `customerId` str ✔ → customers.id · `createdAt`/`updatedAt` · `sample` | `plateKey` = `plate` ตัดช่องว่าง/ขีดกลาง + ตัวพิมพ์ใหญ่ ใช้เป็นกุญแจค้นและกันทะเบียนซ้ำ · แก้ทะเบียนได้ ประวัติตาม `id` ไม่หลุด · ย้ายเจ้าของ = แก้ `customerId` ใบงานยังอยู่กับรถ |
| Master | `services/<id>` | `name` str ✔ (ไม่ซ้ำ) · `priceSatang` int ✔ ≥ 0 (0 = ยังไม่ตั้งราคา) · `createdAt`/`updatedAt` | ทะเบียนตัวเลือกรายการงานที่ร้านแก้เอง · ใช้ **คัดลอก** ชื่อ+ราคาไปใส่ใบงานตอนเลือก แล้วไม่ผูกกันอีก · แก้/ลบไม่กระทบใบงานเก่า · ไม่ติด `sample` จึงไม่ถูกลบด้วยปุ่มล้างข้อมูลตัวอย่าง |
| Transaction | `jobs/<id>` | `vehicleId` str ✔ → vehicles.id · `dateIn` YYYY-MM-DD ✔ · `datePromised` YYYY-MM-DD (ว่างได้) · `status` enum ✔ · `techName` str · `note` str · `receivedSatang` int ✔ ≥ 0 · `depositSatang` int (เขียนคู่ไว้เพื่อความเข้ากันได้) · `lastPaymentAt` ISO · `items` array ✔ · `createdAt`/`updatedAt` · `sample` | 1 ใบ = 1 ครั้งที่รถเข้าร้าน · `status` ∈ received \| in_progress \| ready \| delivered เดินหน้าทางเดียว · `0 ≤ receivedSatang ≤ totalSatang` |
| ฝังในใบงาน | `jobs/<id>.items[]` | `name` str ✔ · `priceSatang` int ✔ ≥ 0 | **ไม่ใช่ collection แยก** เก็บเป็น array ในเอกสาร job (ประหยัดโควตาเอกสาร) · ไม่มี `id` ไม่มี `serviceId` อ้างถึงด้วยลำดับ index ในใบนั้น |

เจ้าของข้อมูล: ธุรการหน้าร้านเป็นคนเขียนหลัก · ช่างเก็บเป็นข้อความใน `techName` ไม่ใช่ทะเบียนช่าง (ถ้าจะทำคิวช่างต้องเพิ่ม master ใหม่ ดู BACKLOG.md)

## snapshot vs derived
**snapshot (คัดลอกแล้วนิ่ง):** `items[].name` และ `items[].priceSatang` คัดจาก services ตอนกด ไม่เก็บ `serviceId` เพื่อไม่ให้ใบเก่าเปลี่ยนตามทะเบียน
**derived (คำนวณสด ห้ามเก็บซ้ำ):**
- `totalSatang(job)` = ผลรวม `items[].priceSatang` · ใบไม่มีรายการ = 0
- `receivedOf(job)` = `receivedSatang` ถ้ามี ไม่งั้นอ่าน `depositSatang` (เอกสารยุคแรก)
- `balanceSatang(job)` = `totalSatang` − `receivedOf` · จ่ายครบ = ≤ 0
- งานค้างในร้าน = `status` ∈ {received, in_progress} · รอลูกค้ามารับ = ready
- รับไปแล้วยังค้างชำระ = delivered และ balance > 0 · ปิดงานสมบูรณ์ = delivered และ balance ≤ 0
- ประวัติของรถ = jobs ที่ `vehicleId` ตรงกัน เรียง `dateIn` ใหม่→เก่า

เงินเป็นจำนวนเต็มสตางค์เสมอ (3,500 บาท = 350000) · วันที่เก็บ `YYYY-MM-DD` แต่แสดงผลเป็น "วันอาทิตย์ 6 กันยายน 2026"

## ขั้นตอนเขียน
ฟอร์ม → normalize (`plateKey`, บาท→สตางค์ปัดจำนวนเต็ม) → ตรวจ required/ช่วงค่า (`priceSatang ≥ 0`, `0 ≤ received ≤ total`, จำนวนเงินที่รับเพิ่ม > 0 และ ≤ ยอดค้าง) → ตรวจ FK และกันซ้ำ (`plateKey`, ชื่อ service) → `set/update/add` ลงฐานข้อมูล → รอผลสำเร็จ → snapshot ยิงกลับมาเอง แล้วหน้าจอค่อยวาดใหม่
เขียนไม่สำเร็จ = คงข้อมูลเดิม ขึ้นข้อความบอกเหตุ ไม่วาดหน้าจอครึ่งทาง · หน้าที่เป็นฟอร์ม (รับรถเข้า, สำรองข้อมูล) จะไม่ถูกวาดทับระหว่างพิมพ์

## ขั้นตอนอ่าน
- **ค้นทะเบียน:** normalize คำค้น → หา vehicle ที่ `plateKey` ตรง → customer จาก `customerId` → jobs จาก `vehicleId` เรียงใหม่→เก่า → รวม `items` เป็น total แล้วคิด balance · ไม่พบ = ข้อความบอกว่าไม่พบ ไม่ใช่หน้าเปล่า
- **งานค้าง:** jobs สถานะ received/in_progress เรียงตาม `datePromised` ใกล้สุดก่อน
- **รถที่เสร็จแล้ว:** แยก 3 กลุ่มตามกฎ derived ด้านบน กลุ่มปิดงานแสดง 20 ใบล่าสุด
- ทุกหน้าอ่านจาก `onSnapshot` ของ 4 collections พร้อมกัน หน้าจะยังไม่วาดจนกว่าจะได้ครบทั้ง 4

## กติกาแก้/ลบ
- ลบ customer ที่ยังมี vehicle ไม่ได้ · ลบ vehicle ที่ยังมี job ไม่ได้ · ลบ job สถานะ delivered ไม่ได้
- ลบ item ได้เฉพาะใบที่ยังไม่ delivered · ลบแล้วถ้า `receivedOf` จะเกิน total ใหม่ ต้องห้ามลบและบอกให้ลดยอดรับเงินก่อน
- `status` เดินหน้าอย่างเดียว กดซ้ำสถานะเดิม = ไม่เกิดผล (idempotent)
- รับเงินเพิ่ม = บวกเข้า `receivedSatang` (ห้าม 0 ห้ามเกินยอดค้าง) · แก้ยอดสะสมโดยตรงได้ในใบงานเมื่อคีย์ผิด
- ลบ service = หายจากดรอปดาวน์เท่านั้น ใบงานเก่าคงชื่อ+ราคาเดิม

## ตัวอย่างหนึ่งเส้นทางครบวง
1. `c1` "สมชาย ก." → `v1` plate `1กก1234` plateKey `1กก1234` customerId `c1`
2. `s1` "ติดฟิล์มกรองแสงรอบคัน" ราคาตั้งต้น 350000 → เปิด `j1` vehicleId `v1` dateIn 2026-07-12 items `[{ติดฟิล์มกรองแสงรอบคัน, 350000}]` received 0 → total 350000 · balance 350000
3. เดินสถานะ received → in_progress → ready → delivered · รับเงินเพิ่ม 350000 → received 350000 · balance 0 → เข้ากลุ่ม "รับรถแล้ว จ่ายเงินแล้ว"
4. รถคันเดิมกลับมา: ค้น ` 1กก 1234 ` เจอ `v1` (ไม่สร้างรถใหม่) → `j2` dateIn 2026-09-04 items `[{ชุดแต่งรอบคัน,1200000},{ล้อแม็ก,1800000}]` received 1000000 → total 3000000 · balance 2000000 · status in_progress
5. แก้ชื่อ `s1` เป็น "ติดฟิล์มรอบคัน" → `j1.items[0].name` ต้องยังเป็นชื่อเดิม
6. `v2` plate `2ขข5678` customerId `c2` → `j3` status received → งานค้าง = 2 (j2, j3) · รอลูกค้ามารับ = 0 · ปิดงานสมบูรณ์ = 1 (j1)

ตรวจการอ้างอิง: `v1.customerId=c1`, `v2.customerId=c2` ✔ · `j1.vehicleId=v1`, `j2.vehicleId=v1`, `j3.vehicleId=v2` ✔ · items อยู่ในเอกสาร job ของตัวเอง ไม่มี FK ค้าง · `s1` ถูกอ้างเฉพาะตอนคัดลอก ลบทิ้งได้โดยไม่มีอะไรค้าง

## ที่เก็บ สิทธิ์ และการชนกัน
- 4 collections ตามตารางด้านบน ไม่มี rules พิเศษ = ทุกคนที่เปิดหน้าได้ อ่านและเขียนได้ทั้งหมด (ยังไม่มีสิทธิ์แยกบทบาท)
- หน้าที่ประกาศ db เป็นแบบองค์กรภายใน ผู้ใช้ต้องล็อกอินและอยู่องค์กรเดียวกับเจ้าของหน้า แชร์สาธารณะไม่ได้
- เขียนพร้อมกัน = last-writer-wins ไม่มี transaction · การนับ/ยอดเงินคำนวณจาก state ของเอกสาร ไม่ใช่จำนวนครั้งที่กด จึงกดซ้ำหรือเขียนชนกันแล้วยอดไม่บวกเกิน
- โควตา 5,000 เอกสารต่อแอป นับ customers + vehicles + jobs + services รวมกัน (items ไม่กิน เพราะฝังในใบงาน) · ที่ 6–15 คัน/วัน จะเต็มราวปีที่ 1–2 ต้องย้ายงานเก่าออกหรือย้ายฐานข้อมูลจริง

## migration และการสำรอง
- ยุคแรกเก็บยอดรับเงินไว้ที่ `depositSatang` · ยุคปัจจุบันใช้ `receivedSatang` และยังเขียน `depositSatang` คู่ไว้ · การอ่านมี fallback จึงไม่ต้องแปลงข้อมูลเก่า ถ้าจะเลิกเขียนคู่ต้องอัปเดตเอกสารเก่าก่อน
- เอกสารตัวอย่างติด `sample:true` (customers/vehicles/jobs) ลบทั้งชุดได้จากปุ่มในหน้าค้นทะเบียน
- ไฟล์สำรองเป็น JSON `{app:'carstyle', version:1, exportedAt, customers[], vehicles[], jobs[], services[]}` แต่ละแถวมี `id` ติดมาด้วย · นำเข้า = `set` ทับตาม `id` เดิม ของที่ไม่มีในไฟล์ไม่ถูกลบ
- ถ้าเปลี่ยนโครงในอนาคต ให้เพิ่มเลข `version` ในไฟล์สำรองและแปลงตอนนำเข้า ห้ามเขียนทับข้อมูลเก่าโดยไม่สำรองก่อน
