# UOM Personal Student App 🎓

A companion app for University of Mauritius students — timetable, deadlines, bus times, files, focus
timer and study groups — on Android and Windows, synced through one account.

## ✨ Features

### 📅 Schedule
- AI timetable import (photo/PDF), week-aware classes, one-off classes.
- Day view with correct hour alignment, early/late classes, side-by-side overlapping classes and a live "now" line.
- Tap a class for homework, a reminder and **Join Meet/Teams/Zoom** (paste a link on any class or event).

### 🗓 Academic Hub
- Calendar with **per-event colours** and **multi-day (spanning) events** drawn as continuous bars.
- Day agenda (classes + events), 14-day "coming up" strip.

### ✅ Board (Kanban)
- To Do → In Progress → Done. Drag between columns (PC) or long-press onto a column tab (phone).
- No accidental swipe-to-delete; every delete asks first and offers **Undo**.
- Priority, filters, time spent per task (from Focus), finished items auto-clear after 7/14/30 days.

### 🖨 Print & export
- Task report PDF: pick types, board columns, dates; optional month calendar pages.
- Printable planners: lined / dotted / grid note paper, month calendar, week planner with your classes.
- Built-in PDF viewer for your files.

### 🚌 Bus
- Opens on the **next departure** with a live countdown; earlier buses are collapsed.
- Add a time and it drops into the right slot (arrival pre-filled from the usual journey time); paste many times at once.
- New users start empty: create a route, use a ready-made one, or **import** a route a friend shared (Route menu → Share route sends a code over WhatsApp/group chat).

### 📁 Files
- Module folders + your own folders, with **custom sections** (add / rename / delete). Move, rename, search.

### 📝 Notes
- Colourful notes with headings, **bold**, bullet lists and tickable checklists; pinning.

### ⏱ Focus
- Pomodoro timer with daily goal, streak and the weekly productivity chart.
- Link a session to a board task, long break every few sessions, and a break reminder after too much continuous focus.

### 👥 Groups
- Join your cohort (public list by programme, year Y1–Y5 and semester S1/S2, or private join code).
- Shared timetable & events managed by **leaders**, group chat with announcements, live "next class" countdown,
  per-member "remind me X min before", and a weekly **focus leaderboard**.

### 🔐 Accounts & sync
- Email/password sign-in (or guest, upgradable later without losing data).
- Everything personal syncs live between phone and PC; the app works offline and catches up later.

## 🔧 One-time Firebase setup

1. Firebase console → **Authentication** → enable **Email/Password** and **Anonymous**.
2. **Firestore Database** → create the database (production mode).
3. Deploy the security rules in this repo:
   ```bash
   npm i -g firebase-tools
   firebase login
   firebase deploy --only firestore:rules
   ```
   Without the rules deployed, Groups will get "permission denied".

## 🚀 Getting started

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # after changing Isar models
flutter run                 # phone
flutter run -d windows      # PC
flutter test                # logic + layout/overflow tests
```

## 🛠 Tech stack
Flutter · Provider · Isar (local DB) · Firebase Auth + Cloud Firestore (sync & groups) · Gemini (timetable import)
