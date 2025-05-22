# Personalized Rehabilitation Plans (PRP)

A mobile application for creating personalized rehabilitation plans using Flutter and machine learning. The app focuses on upper and lower limb rehabilitation, providing tailored exercises and adaptive plans based on user feedback and progress.

## Project Structure

```
personalized_rehabilitation_plans/
├── lib/                           # Flutter app code
│   ├── main.dart                  # Entry point
│   ├── models/                    # Data models
│   ├── screens/                   # UI screens
│   ├── services/                  # Business logic and API services
│   ├── utils/                     # Utility functions
│   └── widgets/                   # Reusable UI components
├── assets/                        # Images, fonts, etc.
├── ml_model/                      # Python ML code for plan generation
│   ├── data_generator.py          # Simulated data generator
│   ├── model_training.py          # ML model training
│   └── requirements.txt           # Python dependencies
├── pubspec.yaml                   # Flutter dependencies
└── README.md                      # Project documentation
```

## Setup Instructions

### Prerequisites

- Flutter SDK (latest stable version)
- Firebase account
- Python 3.8+ (for ML model training)
- Android Studio / VS Code with Flutter extensions

### Flutter App Setup

1. Clone the repository:
   ```
   git clone [repository-url]
   cd personalized_rehabilitation_plans
   ```

2. Create a Firebase project:
   - Go to the [Firebase Console](https://console.firebase.google.com/)
   - Create a new project
   - Add Android and iOS apps to the project
   - Download and add the configuration files:
     - `google-services.json` for Android
     - `GoogleService-Info.plist` for iOS

3. Install Flutter dependencies:
   ```
   flutter pub get
   ```

4. Run the app:
   ```
   flutter run
   ```

### ML Model Setup (for development)

1. Navigate to the ml_model directory:
   ```
   cd ml_model
   ```

2. Create a Python virtual environment:
   ```
   python -m venv venv
   ```

3. Activate the virtual environment:
   - On Windows:
     ```
     venv\Scripts\activate
     ```
   - On macOS/Linux:
     ```
     source venv/bin/activate
     ```

4. Install dependencies:
   ```
   pip install -r requirements.txt
   ```

5. Generate simulated data:
   ```
   python data_generator.py
   ```

6. Train the ML models:
   ```
   python model_training.py
   ```

## Simulating Data

For testing purposes, you can generate simulated user, plan, and progress data:

1. Generate simulated data:
   ```
   cd ml_model
   python data_generator.py
   ```

2. Import simulated data to Firebase:
   - For development and testing, you can manually upload the JSON files in the `simulated_data` directory to your Firebase Firestore database
   - Alternatively, use the Firebase Admin SDK script (not included, but can be created based on the generated data)

## Core Features

- **Personalized Rehabilitation Plans**: Generate tailored exercise plans based on user inputs about their medical history, physical condition, and rehabilitation goals.
- **Dynamic Plan Adjustments**: Automatically adapt rehabilitation plans based on user progress and feedback.
- **Progress Tracking**: Monitor and visualize recovery journey with interactive charts and metrics.
- **Therapist Collaboration**: Enable healthcare professionals to review and adjust plans remotely.
- **User-Friendly Interface**: Intuitive design for both patients and therapists to facilitate easy management of rehabilitation plans.

## Machine Learning Models

The system uses two primary machine learning models:

1. **Exercise Recommendation Model**: Recommends appropriate exercises, difficulty levels, and intensity (sets/reps) based on user's condition and goals.
   - Implemented using Decision Trees and Random Forests

2. **Plan Adjustment Model**: Determines when and how to adjust a rehabilitation plan based on user progress and feedback.
   - Uses Decision Trees for determining when to adjust
   - Uses Random Forests for determining the type of adjustment needed

## Project Status

This project is a prototype/simulation for demonstration purposes. Real-world implementation would require:
- Clinical validation of the rehabilitation exercises and protocols
- Integration with medical systems and proper regulatory compliance
- Expanded dataset training for the machine learning models
- Professional UX/UI review and refinement

## License

[Specify your license information here]

## Acknowledgments

- Inspired by the need for personalized healthcare solutions
- Built as a Final Year Project for Bachelor of Science in Computer Science at Universiti Sains Malaysia