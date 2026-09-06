#!/bin/sh
# สร้าง index.html ที่ deploy จริง = ชั้นเชื่อม Supabase + ตัวแอป
cat src/_supabase-adapter.html src/team-app.html > index.html
echo "สร้าง index.html เรียบร้อย · commit แล้ว push เพื่อ deploy"
