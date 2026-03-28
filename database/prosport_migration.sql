-- ============================================================
-- PROSPORT AI — FULL DATABASE MIGRATION
-- Run this entire file in Supabase SQL Editor
-- ============================================================

-- ✅ STEP 1: Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================================
-- TABLE 1: users (extends Supabase auth.users)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  username TEXT UNIQUE,
  avatar_url TEXT,
  sport TEXT DEFAULT 'general',        -- e.g. 'cricket', 'badminton', 'tennis'
  skill_level TEXT DEFAULT 'beginner', -- 'beginner', 'intermediate', 'advanced'
  height_cm NUMERIC,
  weight_kg NUMERIC,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE 2: sessions (each video upload = one session)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  title TEXT,
  sport TEXT,
  video_url TEXT,          -- Supabase Storage URL
  thumbnail_url TEXT,
  duration_seconds NUMERIC,
  status TEXT DEFAULT 'pending',  -- 'pending', 'processing', 'done', 'failed'
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE 3: pose_analysis (MediaPipe keypoints + scores)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.pose_analysis (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID REFERENCES public.sessions(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  frame_timestamp NUMERIC,           -- seconds into the video
  keypoints JSONB,                   -- raw MediaPipe landmark data
  joint_angles JSONB,                -- e.g. {"elbow": 145, "knee": 162}
  posture_score NUMERIC,             -- 0-100
  speed_ms NUMERIC,                  -- movement speed in m/s
  movement_error TEXT,               -- e.g. "elbow too low on serve"
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE 4: fatigue_logs (per-session fatigue tracking)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.fatigue_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID REFERENCES public.sessions(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  timestamp_seconds NUMERIC,
  fatigue_score NUMERIC,             -- 0-100 (100 = exhausted)
  fatigue_level TEXT,                -- 'low', 'medium', 'high', 'critical'
  indicators JSONB,                  -- e.g. {"speed_drop": 12, "symmetry_loss": 8}
  recovery_time_mins NUMERIC,        -- estimated recovery time
  alert_triggered BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE 5: pro_players (benchmark data for Alike Player)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.pro_players (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  sport TEXT NOT NULL,
  nationality TEXT,
  playing_style TEXT,                -- e.g. 'aggressive baseline', 'serve-volley'
  stats JSONB,                       -- e.g. {"avg_smash_speed": 280, "serve_accuracy": 0.72}
  joint_angle_benchmarks JSONB,      -- ideal angles per movement
  style_vector vector(128),          -- pgvector embedding for similarity search
  image_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE 6: coaching_reports (AI-generated reports per session)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.coaching_reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID REFERENCES public.sessions(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  alike_player_id UUID REFERENCES public.pro_players(id),
  summary TEXT,                      -- Gemini-generated coaching summary
  strengths JSONB,                   -- e.g. ["Good footwork", "Strong serve"]
  weaknesses JSONB,                  -- e.g. ["Elbow drops on backhand"]
  drills JSONB,                      -- recommended drills
  overall_score NUMERIC,             -- 0-100
  audio_url TEXT,                    -- ElevenLabs audio coaching URL
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pose_analysis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fatigue_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coaching_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pro_players ENABLE ROW LEVEL SECURITY;

-- Users: only read/write own profile
CREATE POLICY "Users can view own profile" ON public.users
  FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.users
  FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.users
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Sessions: only own sessions
CREATE POLICY "Users can view own sessions" ON public.sessions
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own sessions" ON public.sessions
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own sessions" ON public.sessions
  FOR UPDATE USING (auth.uid() = user_id);

-- Pose analysis: only own data
CREATE POLICY "Users can view own pose data" ON public.pose_analysis
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own pose data" ON public.pose_analysis
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Fatigue logs: only own data
CREATE POLICY "Users can view own fatigue logs" ON public.fatigue_logs
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own fatigue logs" ON public.fatigue_logs
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Coaching reports: only own reports
CREATE POLICY "Users can view own reports" ON public.coaching_reports
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own reports" ON public.coaching_reports
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Pro players: everyone can read (public benchmark data)
CREATE POLICY "Anyone can view pro players" ON public.pro_players
  FOR SELECT USING (true);

-- ============================================================
-- STORAGE BUCKETS
-- ============================================================

INSERT INTO storage.buckets (id, name, public)
VALUES
  ('videos', 'videos', false),
  ('thumbnails', 'thumbnails', true),
  ('audio', 'audio', false)
ON CONFLICT (id) DO NOTHING;

-- Storage policies: users can upload to their own folder
CREATE POLICY "Users can upload own videos" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'videos' AND auth.uid()::text = (storage.foldername(name))[1]
  );
CREATE POLICY "Users can view own videos" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'videos' AND auth.uid()::text = (storage.foldername(name))[1]
  );
CREATE POLICY "Anyone can view thumbnails" ON storage.objects
  FOR SELECT USING (bucket_id = 'thumbnails');
CREATE POLICY "Users can upload thumbnails" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'thumbnails' AND auth.uid()::text = (storage.foldername(name))[1]
  );
CREATE POLICY "Users can view own audio" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'audio' AND auth.uid()::text = (storage.foldername(name))[1]
  );
CREATE POLICY "Users can upload own audio" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'audio' AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- ============================================================
-- SEED DATA: pro_players
-- ============================================================

INSERT INTO public.pro_players (name, sport, nationality, playing_style, stats, joint_angle_benchmarks, image_url)
VALUES
(
  'Virat Kohli', 'cricket', 'India', 'aggressive-batting',
  '{"batting_avg": 53.5, "strike_rate": 93.2, "cover_drive_speed_kmh": 118, "reaction_time_ms": 210}',
  '{"elbow_at_contact": 145, "knee_bend_stance": 28, "shoulder_rotation": 92, "wrist_snap_angle": 67}',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9b/Virat_Kohli_in_ICC_T20_World_Cup_2022_%28cropped%29.jpg/220px-Virat_Kohli_in_ICC_T20_World_Cup_2022_%28cropped%29.jpg'
),
(
  'PV Sindhu', 'badminton', 'India', 'attacking-net',
  '{"smash_speed_kmh": 280, "rally_win_rate": 0.68, "court_coverage_ms": 320, "jump_height_cm": 62}',
  '{"elbow_at_smash": 160, "knee_bend_jump": 55, "shoulder_extension": 178, "wrist_snap": 72}',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6b/PV_Sindhu_at_the_2016_Olympics_%28cropped%29.jpg/220px-PV_Sindhu_at_the_2016_Olympics_%28cropped%29.jpg'
),
(
  'Rafael Nadal', 'tennis', 'Spain', 'heavy-topspin-baseline',
  '{"serve_speed_kmh": 217, "first_serve_accuracy": 0.69, "forehand_rpm": 3200, "court_coverage_m": 4.1}',
  '{"elbow_at_serve": 172, "knee_bend_stance": 35, "shoulder_rotation": 185, "follow_through": 220}',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1e/Nadal_Australian_Open_2015.jpg/220px-Nadal_Australian_Open_2015.jpg'
),
(
  'Neeraj Chopra', 'athletics', 'India', 'javelin-power',
  '{"throw_distance_m": 89.94, "run_up_speed_ms": 9.2, "release_angle_deg": 33, "shoulder_power_nm": 410}',
  '{"elbow_at_release": 175, "knee_drive": 88, "shoulder_rotation": 210, "hip_extension": 165}',
  'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2c/Neeraj_Chopra_at_the_2020_Summer_Olympics_%28cropped%29.jpg/220px-Neeraj_Chopra_at_the_2020_Summer_Olympics_%28cropped%29.jpg'
),
(
  'Novak Djokovic', 'tennis', 'Serbia', 'all-court-defensive',
  '{"serve_speed_kmh": 230, "first_serve_accuracy": 0.71, "return_win_rate": 0.42, "flexibility_score": 98}',
  '{"elbow_at_serve": 168, "knee_bend_return": 42, "shoulder_rotation": 190, "follow_through": 215}',
  NULL
),
(
  'MS Dhoni', 'cricket', 'India', 'finisher-wicketkeeper',
  '{"batting_avg": 50.6, "stumping_speed_ms": 0.08, "helicopter_shot_speed_kmh": 125, "reaction_time_ms": 180}',
  '{"elbow_at_contact": 138, "knee_bend_stance": 32, "wrist_rotation": 88, "follow_through": 145}',
  NULL
);

-- ============================================================
-- HELPER FUNCTIONS (for backend to call)
-- ============================================================

-- Get full session report for a user
CREATE OR REPLACE FUNCTION get_session_report(p_session_id UUID)
RETURNS TABLE (
  session_title TEXT,
  sport TEXT,
  video_url TEXT,
  overall_score NUMERIC,
  summary TEXT,
  strengths JSONB,
  weaknesses JSONB,
  drills JSONB,
  alike_player_name TEXT,
  fatigue_peak NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.title,
    s.sport,
    s.video_url,
    cr.overall_score,
    cr.summary,
    cr.strengths,
    cr.weaknesses,
    cr.drills,
    pp.name,
    MAX(fl.fatigue_score)
  FROM public.sessions s
  LEFT JOIN public.coaching_reports cr ON cr.session_id = s.id
  LEFT JOIN public.pro_players pp ON pp.id = cr.alike_player_id
  LEFT JOIN public.fatigue_logs fl ON fl.session_id = s.id
  WHERE s.id = p_session_id
  GROUP BY s.title, s.sport, s.video_url, cr.overall_score, cr.summary,
           cr.strengths, cr.weaknesses, cr.drills, pp.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get user's session history with scores
CREATE OR REPLACE FUNCTION get_user_sessions(p_user_id UUID)
RETURNS TABLE (
  session_id UUID,
  title TEXT,
  sport TEXT,
  created_at TIMESTAMPTZ,
  overall_score NUMERIC,
  status TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.id,
    s.title,
    s.sport,
    s.created_at,
    cr.overall_score,
    s.status
  FROM public.sessions s
  LEFT JOIN public.coaching_reports cr ON cr.session_id = s.id
  WHERE s.user_id = p_user_id
  ORDER BY s.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- AUTO-CREATE USER PROFILE ON SIGNUP
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, full_name, avatar_url)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'avatar_url'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- ✅ DONE! All tables, RLS, storage, seed data, and functions created.
-- ============================================================
