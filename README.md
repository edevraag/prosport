# 🏆 ProSport  — Train Like a Pro. Perform Like a Champion.

> AI-powered athletic performance analysis that gives every aspiring athlete access to professional-grade coaching — right from their smartphone.

---

## 🚀 What is ProSport ?

ProSport democratizes elite sports coaching by analyzing your gameplay video using computer vision and AI. Upload a video, and our platform tells you exactly how you move, where you're going wrong, how tired you're getting, and which pro player you play like.

No expensive coaches. No biomechanics lab. Just your phone.

---

## ✨ Features

- 📹 **Video Upload & Analysis** — Upload any sports video for instant AI analysis
- 🦴 **Pose Detection** — MediaPipe-powered skeletal tracking with joint angle measurement
- 😴 **Fatigue Tracker** — Real-time fatigue scoring so you know when to rest
- 🏅 **Alike Player** — Find out which pro athlete (Kohli, Nadal, Sindhu...) you play like
- 📊 **Coaching Report** — Gemini AI generated strengths, weaknesses & drill recommendations
- 🎙️ **Audio Coaching** — ElevenLabs voice coaching output
- 🔐 **Secure by Design** — Row Level Security ensures your data stays yours

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Frontend | React + Tailwind CSS |
| Backend | Python + FastAPI |
| AI / CV | MediaPipe, OpenCV, Gemini AI |
| Voice | ElevenLabs |
| Database | Supabase + PostgreSQL |
| Vector Search | pgvector |
| Storage | Supabase Storage |
| Auth | Supabase Auth |

---

## 📁 Project Structure

```
prosport/
├── frontend/          # React app (UI, dashboard, video upload)
├── backend/           # FastAPI server (CV pipeline, AI calls)
├── database/          # SQL migrations, schema, seed data
│   └── prosport_migration.sql
├── .gitignore
└── README.md
```

---

## 🗄️ Database Schema

| Table | Description |
|---|---|
| `users` | User profiles linked to Supabase Auth |
| `sessions` | Each video upload session |
| `pose_analysis` | MediaPipe keypoints & joint angles per frame |
| `fatigue_logs` | Fatigue scores throughout the session |
| `pro_players` | Benchmark data for 6 pro athletes |
| `coaching_reports` | AI-generated feedback per session |

---

## ⚙️ Setup & Installation

### Prerequisites
- Node.js 18+
- Python 3.10+
- Supabase account

### 1. Clone the repo
```bash
git clone https://github.com/edevraag/prosport.git
cd prosport
```

### 2. Database Setup
- Go to your Supabase project → SQL Editor
- Run the full migration file: `database/prosport_migration.sql`
- This creates all tables, RLS policies, storage buckets, and seeds pro player data

### 3. Environment Variables
Create a `.env` file in both `frontend/` and `backend/` — **never commit this file!**

**frontend/.env**
```
VITE_SUPABASE_URL=your_supabase_url
VITE_SUPABASE_ANON_KEY=your_supabase_anon_key
```

**backend/.env**
```
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
GEMINI_API_KEY=your_gemini_key
ELEVENLABS_API_KEY=your_elevenlabs_key
```

### 4. Frontend
```bash
cd frontend
npm install
npm run dev
```

### 5. Backend
```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload
```

---

## 🔐 Security

- Row Level Security (RLS) enabled on all user tables
- Videos and audio stored in private Supabase Storage buckets
- Users can only access their own data
- `.env` files excluded from version control

---

## 👥 Team

| Role | Responsibility |
|---|---|
| 🎨 Person 1 — UI Engineer | React frontend, dashboard, video upload, auth |
| ⚙️ Person 2 — API & AI Engineer | FastAPI, MediaPipe, Gemini, ElevenLabs |
| 🗄️ Person 3 — Data Engineer | Supabase schema, RLS, storage, seed data |

---

## 📊 Data Flow

```
User uploads video
      ↓
Session created in DB
      ↓
Backend runs MediaPipe → pose_analysis table
      ↓
Fatigue calculated → fatigue_logs table
      ↓
Gemini generates feedback → coaching_reports table
      ↓
Frontend displays full report to user
```

---

*Built with ❤️ at a hackathon*
