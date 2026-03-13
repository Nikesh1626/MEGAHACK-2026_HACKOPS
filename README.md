WellQueue: Real-Time Clinic Queue & Appointment Platform
WellQueue is an all-in-one digital platform designed to eliminate long wait times, reduce stress for patients, and streamline operations for healthcare clinics. We provide real-time visibility into clinic queues and service availability, enabling patients to make informed decisions and empowering staff with efficient management tools, including an AI Voice Agent for automated bookings.

💡 The Problem: Why Healthcare Needs Real-Time Queues
Both patients and clinics suffer from a lack of reliable, real-time information:

Patient Pain Points
Long Waits & Stress: Unclear wait times, leading to anxiety and wasted hours in crowded waiting rooms.

Confusing Navigation: Difficulty finding the right local clinic, service, or understanding triage procedures.

Call Overload: Multiple frustrating phone calls required for basic information, updates, or rescheduling.

Clinic Pain Points
Overwhelmed Receptionists: Staff are constantly interrupted by repetitive phone calls about wait times and general information.

Inefficient Management: Relying on manual, outdated logs (paper, memory) for queue tracking.

Peak Congestion: Inconsistent patient flow results in overcrowded waiting rooms during peak hours and idle time during slow periods.

🎯 The Solution: Unified, Real-Time Visibility
WellQueue connects patients and clinics on a single, integrated platform to bring transparency and efficiency to the appointment and queue management process.

Feature

Patient Benefit

Clinic Benefit

Map View

See nearby clinics, live wait times, and service availability.

Drives traffic during slow hours by displaying low wait times.

Real-Time Queue

Anonymous check-ins and turn notifications via the app or SMS.

Staff can efficiently manage, triage, and update the queue status instantly.

AI Voice Agent

Easy 24/7 phone booking, rescheduling, and confirmation.

Reduces receptionist workload by automating routine appointment management.

In-App Messaging

Direct, clear communication with clinic staff for delays and clarifications.

Enables mass announcements and targeted patient updates effortlessly.

✨ Core Features
📱 Patient Mobile App (Kotlin + Jetpack Compose)
Live Map View: Real-time queue and availability data for all integrated clinics.

Appointment Management: Simple request and confirmation system.

Check-in & Alerts: Anonymous digital check-in and push notifications for their turn.

User Experience: Multilingual and mobile-first design.

💻 Receptionist/Admin Panel (React)
Dynamic Queue Management: Real-time drag-and-drop queue control and triage tagging.

Communication Hub: Send patient messages, delay notifications, and announcements.

Scheduling: Integrated appointment booking and capacity monitoring.

🤖 Additional Services
AI Voice Calling Agent (Retell AI): Handles automated phone-based booking, rescheduling, and confirmations, syncing directly with the backend.

SMS Updates: Critical reminders and queue alerts for users without the mobile app (Low-tech mode).

🛠️ Technology Stack
WellQueue is built using modern, scalable, and real-time technologies.

Layer

Technologies

Purpose

Frontend (Patient)

Kotlin + Jetpack Compose (Native Mobile App)

High-performance, native Android experience.

Frontend (Admin)

React (or Jetpack Compose for Desktop)

Responsive web dashboard for clinic staff.

Backend

Node.js (Next.js)

High-speed server-side logic and API gateway.

Database

PostgreSQL + Redis

PostgreSQL for core data, Redis for high-speed queue management.

Real-Time

WebSockets / Firebase

Instant synchronization of queue updates between clinics and patients.

AI/Integration

Retell AI, Google Calendar API, Google Maps SDK, Firebase Cloud Messaging

Voice agent, appointment sync, location services, and push notifications.

Hosting & Infra

AWS / GCP / Azure

Cloud-native, scalable infrastructure.

## Supabase to Firebase Migration (Flutter App)

This project now uses Firebase instead of Supabase for authentication and user profile storage.

### What was migrated in code
- Replaced Supabase packages with `firebase_core`, `firebase_auth`, and `cloud_firestore`.
- Rewrote auth flow in `AuthService` to use Firebase Auth (`signUp`, `signIn`, `signOut`, `currentUser`).
- Stored signup profile data (`first_name`, `last_name`, `phone`, `age`, `email`) in Firestore under `users/{uid}`.
- Replaced app startup session check from Supabase session to Firebase current user.
- Updated profile and webhook services to read user data from Firebase Auth + Firestore.
- Added Android Google Services Gradle plugin wiring.

### Required setup steps (do this once)
1. Create a Firebase project in Firebase Console.
2. Enable **Authentication > Sign-in method > Email/Password**.
3. Enable **Firestore Database** (start in test mode first if needed).
4. Install FlutterFire CLI:
	 - `dart pub global activate flutterfire_cli`
5. From project root, run:
	 - `flutterfire configure`
6. This generates Firebase platform config (`google-services.json`, `GoogleService-Info.plist`, and `lib/firebase_options.dart` if selected).
7. For Android, ensure package name in Firebase app matches your app id (`com.example.well_queue`) or update `applicationId` and recreate config.
8. Run:
	 - `flutter clean`
	 - `flutter pub get`
	 - `flutter run`

### Firestore structure expected by app
- Collection: `users`
- Document ID: authenticated Firebase `uid`
- Fields:
	- `first_name` (string)
	- `last_name` (string)
	- `phone` (string)
	- `age` (number)
	- `email` (string)
	- `created_at` (timestamp)

### Suggested Firestore security rule (starter)
```txt
rules_version = '2';
service cloud.firestore {
	match /databases/{database}/documents {
		match /users/{userId} {
			allow read, write: if request.auth != null && request.auth.uid == userId;
		}
	}
}
```

