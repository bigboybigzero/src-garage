-- SRC garage · สร้างตารางและสิทธิ์สำหรับเว็บของร้าน
-- วางทั้งไฟล์นี้ในหน้า SQL Editor ของ Supabase แล้วกด Run ครั้งเดียวจบ

do $$
declare t text;
begin
  foreach t in array array['customers','vehicles','jobs','services'] loop

    execute format(
      'create table if not exists public.%I (
         id text primary key,
         data jsonb not null default ''{}''::jsonb,
         updated_at timestamptz not null default now()
       )', t);

    execute format('alter table public.%I enable row level security', t);

    -- เฉพาะคนที่ล็อกอินแล้วเท่านั้นที่อ่านและเขียนได้ คนทั่วไปที่เปิดลิงก์เฉย ๆ ไม่เห็นข้อมูล
    execute format('drop policy if exists staff_all on public.%I', t);
    execute format(
      'create policy staff_all on public.%I
         for all to authenticated
         using (true) with check (true)', t);

    -- เปิด realtime ให้ทุกเครื่องเห็นการแก้ไขของกันและกันทันที
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null;
    end;

  end loop;
end $$;

-- ตรวจผล: ต้องได้ 4 แถว customers / jobs / services / vehicles
select tablename from pg_tables where schemaname='public' order by tablename;
