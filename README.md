# UOM Personal Student App 🎓

A comprehensive mobile companion designed for University of Mauritius students to manage their academic life, track attendance, and coordinate schedules with friends.

## ✨ Key Features

### 📅 Advanced Schedule Management
- **Smart Timetable**: Automatically detects the current week and adjusts for Online vs. Campus weeks.
- **Compare Schedules**: The flagship **"Free to Meet"** feature allows you to compare your timetable (e.g., Data Science) with a friend's (e.g., Computer Science).
- **Intelligent Gap Detection**: When comparing, the app automatically highlights common free slots (min 30 mins) directly on the grid—but **only if both of you are on campus** that day!

### ❤️ Attendance Survival Mode
- **Gamified Tracking**: Treat your attendance like a game! You start with 10 "Lives" per module.
- **Visual Feedback**: Hearts dissipate as you miss classes.
- **Log History**: Correct mistakes or view your attendance history for any module.

### 📝 Academic Hub & Planner
- **Task Management**: Track assignments, tests, and projects.
- **Deadline Awareness**: Visual urgency indicators (Red for <= 3 days, Orange for <= 7 days).
- **Class Quick Actions**: Add homework directly from your schedule view.

### 💻 PC / Desktop Experience
- **Responsive Layout**: Automatically adapts to large screens with a dedicated side navigation rail.
- **Optimized for Productivity**: Use your mouse and keyboard to manage tasks faster.
- **Windows Support**: Native performance on Windows machines.

### 🚌 Campus Utilities
- **Bus Schedule**: Integrated bus timings for easy commute planning.
- **Dark Mode**: Fully supported beautiful dark theme for late-night studying.

## 🚀 Getting Started

1.  **Prerequisites**: Ensure you have [Flutter](https://flutter.dev/docs/get-started/install) installed.
2.  **Clone the Repo**:
    ```bash
    git clone https://github.com/TusharDwarka/uom-per-app.git
    cd uom-per-app
    ```
3.  **Install Dependencies**:
    ```bash
    flutter pub get
    ```
4.  **Run the App**:
    ```bash
    flutter run
    ```
    *To run on Windows:*
    ```bash
    flutter run -d windows
    ```

5.  **Build for PC**:
    ```bash
    flutter build windows
    ```
    *Output located in `build/windows/runner/Release`*

## 🛠 Tech Stack
-   **Framework**: Flutter
-   **State Management**: Provider
-   **Database**: Isar (High performance NoSQL)
-   **UI**: Material 3 Design
