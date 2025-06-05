# Osmos – Health & Wellness Mobile App

Osmos is a cross-platform mobile app for health, wellness, and self-care. It empowers users to log food, track mood, manage reminders, interact with an AI assistant, and more. Built with Flutter and Firebase, Osmos is modular, cloud-integrated, and ready for real-world use.

---

## Features

- **Personalized Dashboard** (Patient, Wellness, Caregiver)
- **Food Logging & Nutrition Stats** (with macros breakdown)
- **Mood Check-ins & Trends**
- **Reminders & Appointments**
- **AI Chatbot (Osmos AI)** – Text & Vocal modes (Groq API)
- **Modes & Location Tracking** (Home/Away, Google Maps)
- **Profile Management**
- **Push Notifications**
- **Modern, Responsive UI**

---

## Architecture

```mermaid
flowchart TD
    User((User))
    App[Flutter Mobile App]
    Firebase[Firebase (Auth, Firestore, Storage)]
    Groq[Groq API (AI, TTS)]
    Maps[Google Maps API]
    Notif[Local Notifications]

    User <--> App
    App <--> Firebase
    App <--> Groq
    App <--> Maps
    App <--> Notif
```

---

## Technologies

- **Flutter** (Dart)
- **Firebase** (Auth, Firestore, Storage)
- **Groq API** (AI chat, TTS)
- **Google Maps, Geolocator**
- **fl_chart** (charts)
- **Provider** (state management)
- **audioplayers, flutter_tts** (audio)
- **flutter_local_notifications**

---

## Setup & Installation

1. **Clone the repository:**
   ```sh
   git clone https://github.com/deglon/osmos.git
   cd osmos
   ```

2. **Install dependencies:**
   ```sh
   flutter pub get
   ```

3. **Add your Firebase config:**
   - Place your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) in the appropriate directories.

4. **Set API keys:**
   - Update your Groq API key and Google Maps API key in the code.

5. **Run the app:**
   ```sh
   flutter run
   ```

---

## Testing

- Run all tests:
  ```sh
  flutter test
  ```
- Code coverage:
  ```sh
  flutter test --coverage
  ```

---

## Contributors

- Rattazi Oussama
- Maroua Fath
- Firdevs Tanrikulu
- Milena Barkudarian

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

## Contact

For questions or support, open an issue or contact [orattazi@gmail.com].
