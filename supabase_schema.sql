-- Project newPrime — Supabase-Schema (fuer die spaetere Sync-Schicht)
-- Wird im MVP noch nicht genutzt (App laeuft lokal), aber hier schon vorbereitet.
-- Ausfuehren im Supabase SQL-Editor.

-- 1. Profil + Gamification-Zustand (1:1 mit auth.users)
create table if not exists profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  xp integer not null default 0,
  streak integer not null default 0,
  last_workout_date date,
  shields integer not null default 1,
  created_at timestamptz not null default now()
);

-- 2. Programm (Split)
create table if not exists programs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now()
);

-- 3. Trainingstag (Session-Vorlage)
create table if not exists session_templates (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references programs (id) on delete cascade,
  name text not null,
  position integer not null default 0
);

-- 4. Uebungs-Vorlage
create table if not exists exercise_templates (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references session_templates (id) on delete cascade,
  name text not null,
  muscle text not null,
  rep_min integer not null,
  rep_max integer not null,
  target_sets integer not null default 3,
  position integer not null default 0
);

-- 5. Abgeschlossenes Workout
create table if not exists workout_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  session_name text not null,
  performed_at timestamptz not null default now(),
  xp_earned integer not null default 0
);

-- 6. Abgeschlossener Satz (Kern-Einheit, Basis fuer Progression & PR)
create table if not exists completed_sets (
  id uuid primary key default gen_random_uuid(),
  log_id uuid not null references workout_logs (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  exercise_name text not null,
  muscle text,
  weight numeric not null,
  reps integer not null,
  rpe numeric,
  rest_seconds integer,
  tempo text,
  note text,
  is_warmup boolean not null default false,
  performed_at timestamptz not null default now()
);

create index if not exists idx_completed_sets_user_exercise
  on completed_sets (user_id, exercise_name, performed_at desc);

-- Row Level Security: jeder Nutzer sieht nur seine eigenen Daten.
alter table profiles enable row level security;
alter table programs enable row level security;
alter table session_templates enable row level security;
alter table exercise_templates enable row level security;
alter table workout_logs enable row level security;
alter table completed_sets enable row level security;

create policy "own profile" on profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);
create policy "own programs" on programs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own logs" on workout_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own sets" on completed_sets
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Vorlagen-Tabellen ueber das Programm abgesichert.
create policy "own session templates" on session_templates
  for all using (
    exists (select 1 from programs p
            where p.id = session_templates.program_id
              and p.user_id = auth.uid())
  );
create policy "own exercise templates" on exercise_templates
  for all using (
    exists (select 1 from session_templates s
            join programs p on p.id = s.program_id
            where s.id = exercise_templates.session_id
              and p.user_id = auth.uid())
  );
