# 🎓 College Student & Timetable Management App

A modern Flutter application designed to help Class Representatives (CRs) or faculty manage student details and daily class schedules efficiently. This app uses **Firebase Cloud Firestore** for real-time data storage and synchronization.

## ✨ Features

### 👨‍🎓 Student Management
* **View Students:** specific lists for **CE** (Computer Engineering) and **IT** departments.
* **Add Student:** Easy-to-use dialog to add Name, Roll No, Enrollment No, and Department.
* **Edit/Delete:** Update student details or remove them from the database with a single tap.
* **Real-time Updates:** The list updates instantly when changes are made.

### 📅 Timetable Management
* **Daily Schedule:** Organizes classes by day (Monday to Saturday).
* **Add Class:** Input Subject Name, Faculty Name, Day, and Time Slot.
* **Visual Cards:** Color-coded or clean card design for easy reading.
* **Edit/Delete:** Modify schedule slots or cancel classes easily.

## 🛠️ Tech Stack

* **Frontend:** [Flutter](https://flutter.dev/) (Dart)
* **Backend:** [Firebase Cloud Firestore](https://firebase.google.com/products/firestore)
* **UI Components:** Material Design 3


## 🗄️ Database Structure (Cloud Firestore)

The app uses two main collections in Firebase:

### 1. Collection: `student`
| Field | Type | Description |
| :--- | :--- | :--- |
| `name` | String | Name of the student |
| `rollNo` | String | Class Roll Number |
| `enrollmentNo` | String | University Enrollment ID |
| `department` | String | "Computer" or "IT" |

### 2. Collection: `subject`
| Field | Type | Description |
| :--- | :--- | :--- |
| `subjectName` | String | e.g., "CCT", "Java" |
| `facultyName` | String | e.g., "Arzoo Sir" |
| `timeSlot` | String | e.g., "8:00 - 9:45" |
| `day` | String | e.g., "Monday" |
| `timestamp` | ServerTimestamp | Used for sorting |

## 🚀 How to Run Locally

### Prerequisites
* Flutter SDK installed.
* A Firebase Project set up.

### Installation Steps

1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/your-username/your-repo-name.git](https://github.com/your-username/your-repo-name.git)
    ```

2.  **Install Dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Firebase Setup (Crucial):**
    * Go to the [Firebase Console](https://console.firebase.google.com/).
    * Create a new project.
    * Add an Android App (package name: `com.example.demo1` or whatever is in your `AndroidManifest.xml`).
    * Download the **`google-services.json`** file.
    * Place the file in: `android/app/google-services.json`.
    * *(If using iOS, download `GoogleService-Info.plist` and place it in `ios/Runner`).*

4.  **Run the App:**
    ```bash
    flutter run
    ```


## 👤 Author

*B.Tech Computer Engineering (5th Sem)*  
RK University

---
*Created with ❤️ using Flutter*
