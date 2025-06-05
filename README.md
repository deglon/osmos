# Osmos – Health & Wellness Mobile App

Osmos is a cross-platform mobile app for health, wellness, and self-care. It empowers users to log food, track mood, manage reminders, interact with an AI assistant, and more. Built with Flutter and Firebase, Osmos is modular, cloud-integrated, and ready for real-world use.

---

## 🚀 Features

- Personalized Dashboard (Patient, Wellness, Caregiver)
- Food Logging & Nutrition Stats (with macros breakdown)
- Mood Check-ins & Trends
- Reminders & Appointments
- AI Chatbot (Osmos AI) – Text & Vocal modes (Groq API)
- Modes & Location Tracking (Home/Away, Google Maps)
- Profile Management
- Push Notifications
- Modern, Responsive UI

---

## 🏗️ Architecture

> **System Overview:**
>
> - **Flutter App**: Cross-platform UI and logic
> - **Firebase**: Auth, Firestore, Storage
> - **Groq API**: AI chat and TTS
> - **Google Maps**: Location and mapping
> - **Local Notifications**: Reminders and alerts

```
User <--> Flutter App <--> Firebase <--> Groq API
                        <--> Google Maps
                        <--> Local Notifications
```

---

## 🛠️ Technologies

- **Flutter** (Dart)
- **Firebase** (Auth, Firestore, Storage)
- **Groq API** (AI chat, TTS)
- **Google Maps, Geolocator**
- **fl_chart** (charts)
- **Provider** (state management)
- **audioplayers, flutter_tts** (audio)
- **flutter_local_notifications**

---

## 📝 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- A Firebase project (with Auth and Firestore enabled)
- (Optional) Groq API key for AI features
- (Optional) Google Maps API key for map features

### Setup Steps

1. **Clone the repository:**
    ```sh
    git clone https://github.com/deglon/osmos.git
    cd osmos
    git checkout your-branch-name
    ```

2. **Install dependencies:**
    ```sh
    flutter pub get
    ```

3. **Firebase configuration:**
    - Place your `google-services.json` (Android) in `android/app/`
    - Place your `GoogleService-Info.plist` (iOS) in `ios/Runner/`
    - Set up your Firebase project with Authentication and Firestore enabled.

4. **API Keys:**
    - Add your Groq API key and Google Maps API key in the appropriate files (see code comments).
    - **Important:** Never commit your API keys to the repository. Use environment variables or a `.env` file and add it to `.gitignore`.

5. **Run the app:**
    ```sh
    flutter run
    ```

6. **Testing:**
    ```sh
    flutter test
    ```

---

## 🧪 Testing

- **Unit Tests:** For business logic, data parsing, and utility functions.
- **Widget Tests:** For UI components and navigation flows.
- **Integration Tests:** For end-to-end flows (login, onboarding, food logging).
- **Manual Testing:** For device-specific features (location, notifications, TTS).
- **Coverage:** Run `flutter test --coverage` to check code coverage.

---



## 👥 Contributors

- Rattazi Oussama
- Maroua Fath
- Firdevs Tanrikulu
- Milena Barkudarian
---

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

## 📬 Contact

For questions or support, open an issue or contact [orattazi@gmail.com]
