# generate_plan.py - Rehabilitation Plan Generation Module
import pandas as pd
import numpy as np
from sklearn.tree import DecisionTreeClassifier
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import OneHotEncoder
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, classification_report, confusion_matrix
from sklearn.model_selection import train_test_split
import joblib
import uuid
import os
import json
from datetime import datetime
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class PlanGenerationModel:
    def __init__(self):
        self.encoder = None
        self.difficulty_model = None
        self.sets_model = None
        self.reps_model = None
        self.metrics = None
        self.models_dir = 'models'
        
        # Ensure models directory exists
        os.makedirs(self.models_dir, exist_ok=True)
    
    def generate_sample_data(self):
        """Generate sample training data with logical pain level correlations"""
        body_parts = ['Knee', 'Shoulder', 'Ankle', 'Wrist', 'Elbow', 'Hip', 'Back', 'Neck']
        pain_levels = list(range(1, 11))
        pain_locations = ['Joint', 'Muscle', 'Tendon', 'Ligament', 'Other']
        previous_injuries = ['ACL tear', 'Meniscus tear', 'Rotator cuff injury', 'Ankle sprain', 
                             'Tendonitis', 'Fracture', 'Dislocation', 'Muscle strain', 'None']
        surgical_histories = ['ACL reconstruction', 'Meniscus repair', 'Rotator cuff repair', 
                             'Joint replacement', 'None']
        goals = ['Pain reduction', 'Improve range of motion', 'Increase strength', 
                 'Return to sports', 'Post-surgery recovery']
        
        difficulty_levels = ['beginner', 'intermediate', 'advanced']
        
        data = []
        
        # Generate sample data with more logical pain level correlations
        for _ in range(500):  # Increased sample size
            body_part = np.random.choice(body_parts)
            pain_level = np.random.choice(pain_levels)
            pain_location = np.random.choice(pain_locations)
            previous_injury = np.random.choice(previous_injuries)
            surgical_history = np.random.choice(surgical_histories)
            goal = np.random.choice(goals)
            
            # Better pain level to difficulty mapping
            if pain_level >= 8:  # High pain (8-10)
                difficulty = 'beginner'
                sets = np.random.choice([1, 2])  # Fewer sets for high pain
                reps = np.random.choice([5, 8])  # Fewer reps for high pain
            elif pain_level >= 5:  # Moderate pain (5-7)
                difficulty = np.random.choice(['beginner', 'intermediate'], p=[0.7, 0.3])
                sets = np.random.choice([2, 3])
                reps = np.random.choice([8, 10])
            else:  # Low pain (1-4)
                difficulty = np.random.choice(['intermediate', 'advanced'], p=[0.6, 0.4])
                sets = np.random.choice([3, 4])
                reps = np.random.choice([10, 12, 15])
                
            # Add some randomness but keep correlation
            if np.random.random() < 0.1:  # 10% random variation
                difficulty = np.random.choice(difficulty_levels)
                sets = np.random.choice([1, 2, 3, 4])
                reps = np.random.choice([5, 8, 10, 12, 15])
            
            data.append({
                'body_part': body_part,
                'pain_level': pain_level,
                'pain_location': pain_location,
                'previous_injuries': previous_injury,
                'surgical_history': surgical_history,
                'primary_goal': goal,
                'difficulty_level': difficulty,
                'sets': sets,
                'reps': reps
            })
        
        return pd.DataFrame(data)

    def train_models_with_metrics(self):
        """Train and save the models with metrics calculation"""
        print("Training models with metrics evaluation...")
        
        # Generate sample data
        df = self.generate_sample_data()
        
        # Prepare features and targets
        X = df[['body_part', 'pain_level', 'pain_location', 'previous_injuries', 
                'surgical_history', 'primary_goal']]
        y_difficulty = df['difficulty_level']
        y_sets = df['sets']
        y_reps = df['reps']
        
        # Split data into training and testing sets
        X_train, X_test, y_diff_train, y_diff_test = train_test_split(X, y_difficulty, test_size=0.2, random_state=42)
        _, _, y_sets_train, y_sets_test = train_test_split(X, y_sets, test_size=0.2, random_state=42)
        _, _, y_reps_train, y_reps_test = train_test_split(X, y_reps, test_size=0.2, random_state=42)
        
        # Encode categorical features
        categorical_features = ['body_part', 'pain_location', 'previous_injuries', 
                               'surgical_history', 'primary_goal']
        encoder = OneHotEncoder(sparse_output=False, handle_unknown='ignore')
        
        # Fit encoder on training data only
        X_cat_train = pd.DataFrame(
            encoder.fit_transform(X_train[categorical_features]),
            columns=encoder.get_feature_names_out(categorical_features)
        )
        
        # Transform test data
        X_cat_test = pd.DataFrame(
            encoder.transform(X_test[categorical_features]),
            columns=encoder.get_feature_names_out(categorical_features)
        )
        
        # Combine with numerical features
        X_num_train = X_train[['pain_level']].reset_index(drop=True)
        X_processed_train = pd.concat([X_num_train, X_cat_train], axis=1)
        
        X_num_test = X_test[['pain_level']].reset_index(drop=True)
        X_processed_test = pd.concat([X_num_test, X_cat_test], axis=1)
        
        # Train models
        # Decision Tree for difficulty level (categorical)
        dt_diff = DecisionTreeClassifier(max_depth=5, random_state=42)
        dt_diff.fit(X_processed_train, y_diff_train)
        
        # Random Forest for sets and reps (numerical)
        rf_sets = RandomForestClassifier(n_estimators=50, random_state=42)
        rf_sets.fit(X_processed_train, y_sets_train)
        
        rf_reps = RandomForestClassifier(n_estimators=50, random_state=42)
        rf_reps.fit(X_processed_train, y_reps_train)
        
        # Evaluate models
        y_diff_pred = dt_diff.predict(X_processed_test)
        y_sets_pred = rf_sets.predict(X_processed_test)
        y_reps_pred = rf_reps.predict(X_processed_test)
        
        # Calculate metrics for difficulty prediction
        diff_accuracy = accuracy_score(y_diff_test, y_diff_pred)
        diff_precision = precision_score(y_diff_test, y_diff_pred, average='weighted')
        diff_recall = recall_score(y_diff_test, y_diff_pred, average='weighted')
        diff_f1 = f1_score(y_diff_test, y_diff_pred, average='weighted')
        diff_report = classification_report(y_diff_test, y_diff_pred, output_dict=True)
        diff_cm = confusion_matrix(y_diff_test, y_diff_pred).tolist()
        
        # Calculate metrics for sets prediction (treating as classification problem)
        sets_accuracy = accuracy_score(y_sets_test, y_sets_pred)
        sets_report = classification_report(y_sets_test, y_sets_pred, output_dict=True)
        sets_cm = confusion_matrix(y_sets_test, y_sets_pred).tolist()
        
        # Calculate metrics for reps prediction (treating as classification problem)
        reps_accuracy = accuracy_score(y_reps_test, y_reps_pred)
        reps_report = classification_report(y_reps_test, y_reps_pred, output_dict=True)
        reps_cm = confusion_matrix(y_reps_test, y_reps_pred).tolist()
        
        # Print metrics
        print("\nDifficulty Level Prediction Metrics:")
        print(f"Accuracy: {diff_accuracy:.4f}")
        print(f"Precision: {diff_precision:.4f}")
        print(f"Recall: {diff_recall:.4f}")
        print(f"F1 Score: {diff_f1:.4f}")
        print("\nDetailed Classification Report:")
        print(classification_report(y_diff_test, y_diff_pred))
        
        print("\nSets Prediction Metrics:")
        print(f"Accuracy: {sets_accuracy:.4f}")
        print("\nDetailed Classification Report:")
        print(classification_report(y_sets_test, y_sets_pred))
        
        print("\nReps Prediction Metrics:")
        print(f"Accuracy: {reps_accuracy:.4f}")
        print("\nDetailed Classification Report:")
        print(classification_report(y_reps_test, y_reps_pred))
        
        # Store metrics for later retrieval
        metrics = {
            'difficulty': {
                'accuracy': diff_accuracy,
                'precision': diff_precision,
                'recall': diff_recall,
                'f1': diff_f1,
                'report': diff_report,
                'confusion_matrix': diff_cm
            },
            'sets': {
                'accuracy': sets_accuracy,
                'report': sets_report,
                'confusion_matrix': sets_cm
            },
            'reps': {
                'accuracy': reps_accuracy,
                'report': reps_report,
                'confusion_matrix': reps_cm
            }
        }
        
        # Save metrics to a file
        with open(f'{self.models_dir}/metrics.json', 'w') as f:
            json.dump(metrics, f, indent=4, default=str)
        
        # Save models and encoder
        try:
            joblib.dump(dt_diff, f'{self.models_dir}/difficulty_model.pkl')
            joblib.dump(rf_sets, f'{self.models_dir}/sets_model.pkl')
            joblib.dump(rf_reps, f'{self.models_dir}/reps_model.pkl')
            joblib.dump(encoder, f'{self.models_dir}/feature_encoder.pkl')
            print("Models saved successfully.")
        except Exception as e:
            print(f"Error saving models: {e}")
            raise
        
        # Store in instance variables
        self.encoder = encoder
        self.difficulty_model = dt_diff
        self.sets_model = rf_sets
        self.reps_model = rf_reps
        self.metrics = metrics
        
        return encoder, dt_diff, rf_sets, rf_reps, metrics

    def load_models(self):
        """Load trained models or train new ones if not available"""
        try:
            # Try to load all models
            self.encoder = joblib.load(f'{self.models_dir}/feature_encoder.pkl')
            self.difficulty_model = joblib.load(f'{self.models_dir}/difficulty_model.pkl')
            self.sets_model = joblib.load(f'{self.models_dir}/sets_model.pkl')
            self.reps_model = joblib.load(f'{self.models_dir}/reps_model.pkl')
            
            # Try to load metrics
            with open(f'{self.models_dir}/metrics.json', 'r') as f:
                self.metrics = json.load(f)
                
            print("Models and metrics loaded successfully.")
            return True
        except (FileNotFoundError, EOFError, Exception) as e:
            # If any error occurs during loading, retrain all models
            print(f"Error loading models or metrics: {e}. Training new models...")
            self.train_models_with_metrics()
            return True

    def get_exercise_database(self):
        """Database of exercises for different body parts"""
        exercises = {
            'knee': [
                {
                    'name': 'Straight Leg Raises',
                    'description': 'Lie flat on your back with one leg bent and the other straight. Tighten the thigh muscle of the straight leg and slowly raise it to the height of the bent knee.',
                    'bodyPart': 'Knee',
                    'durationSeconds': 30,
                },
                {
                    'name': 'Hamstring Curls',
                    'description': 'Stand facing a wall or sturdy object for balance. Bend your affected knee, bringing your heel toward your buttocks. Hold, then lower slowly.',
                    'bodyPart': 'Knee',
                    'durationSeconds': 45,
                },
                {
                    'name': 'Wall Squats',
                    'description': 'Stand with your back against a wall, feet shoulder-width apart. Slide down the wall until your knees are bent at about 45 degrees. Hold, then slide back up.',
                    'bodyPart': 'Knee',
                    'durationSeconds': 60,
                },
                {
                    'name': 'Step-Ups',
                    'description': 'Step up onto a platform with your affected leg, then step down. Repeat.',
                    'bodyPart': 'Knee',
                    'durationSeconds': 45,
                },
                {
                    'name': 'Knee Extensions',
                    'description': 'Sit in a chair and extend your affected leg until straight, then lower slowly.',
                    'bodyPart': 'Knee',
                    'durationSeconds': 30,
                }
            ],
            'shoulder': [
                {
                    'name': 'Pendulum Exercise',
                    'description': 'Lean forward slightly with support, allowing your affected arm to hang down. Swing your arm gently in small circles, then in larger circles. Repeat in the opposite direction.',
                    'bodyPart': 'Shoulder',
                    'durationSeconds': 30,
                },
                {
                    'name': 'Wall Crawl',
                    'description': 'Stand facing a wall with your affected arm. Walk your fingers up the wall as high as comfortable. Slowly lower back down.',
                    'bodyPart': 'Shoulder',
                    'durationSeconds': 45,
                },
                {
                    'name': 'External Rotation',
                    'description': 'Holding a light resistance band, keep your elbow at 90 degrees and close to your side. Rotate your forearm outward, away from your body.',
                    'bodyPart': 'Shoulder',
                    'durationSeconds': 60,
                },
                {
                    'name': 'Internal Rotation',
                    'description': 'With your elbow at your side, rotate your arm inward against resistance.',
                    'bodyPart': 'Shoulder',
                    'durationSeconds': 45,
                },
                {
                    'name': 'Shoulder Flexion',
                    'description': 'Raise your arm forward and upward as high as comfortable.',
                    'bodyPart': 'Shoulder',
                    'durationSeconds': 30,
                }
            ],
            'ankle': [
                {
                    'name': 'Ankle Pumps',
                    'description': 'Move your foot up and down, bending at the ankle. This improves circulation and range of motion.',
                    'bodyPart': 'Ankle',
                    'durationSeconds': 30,
                },
                {
                    'name': 'Ankle Circles',
                    'description': 'Rotate your ankle clockwise and counterclockwise, making circles with your toes.',
                    'bodyPart': 'Ankle',
                    'durationSeconds': 45,
                },
                {
                    'name': 'Heel Raises',
                    'description': 'Stand with feet shoulder-width apart. Raise up onto your toes, then lower back down.',
                    'bodyPart': 'Ankle',
                    'durationSeconds': 60,
                },
                {
                    'name': 'Resistance Band Eversion',
                    'description': 'With a resistance band, turn your foot outward against the resistance.',
                    'bodyPart': 'Ankle',
                    'durationSeconds': 45,
                },
                {
                    'name': 'Resistance Band Inversion',
                    'description': 'With a resistance band, turn your foot inward against the resistance.',
                    'bodyPart': 'Ankle',
                    'durationSeconds': 45,
                }
            ],
            'wrist': [
                {
                    'name': 'Wrist Flexion and Extension',
                    'description': 'Hold your arm out with palm facing down. Bend your wrist down, then up.',
                    'bodyPart': 'Wrist',
                    'durationSeconds': 30,
                },
                {
                    'name': 'Wrist Rotations',
                    'description': 'Rotate your wrist in circles, clockwise and counterclockwise.',
                    'bodyPart': 'Wrist',
                    'durationSeconds': 45,
                },
                {
                    'name': 'Finger Stretches',
                    'description': 'Spread your fingers wide, then make a fist. Repeat.',
                    'bodyPart': 'Wrist',
                    'durationSeconds': 60,
                },
                {
                    'name': 'Grip Strengthening',
                    'description': 'Squeeze a soft ball or stress ball, hold, then release.',
                    'bodyPart': 'Wrist',
                    'durationSeconds': 45,
                },
                {
                    'name': 'Wrist Stretches',
                    'description': 'Extend your arm with palm up, use your other hand to gently pull fingers back toward your body.',
                    'bodyPart': 'Wrist',
                    'durationSeconds': 30,
                }
            ],
            'elbow': [
                {
                    'name': 'Elbow Flexion and Extension',
                    'description': 'Bend and straighten your elbow slowly.',
                    'bodyPart': 'Elbow',
                    'durationSeconds': 30,
                },
                {
                    'name': 'Wrist Turns',
                    'description': 'With elbow bent at 90 degrees, rotate your palm up and down.',
                    'bodyPart': 'Elbow',
                    'durationSeconds': 45,
                },
                {
                    'name': 'Bicep Curls',
                    'description': 'Hold a light weight and bend your elbow to bring your hand toward your shoulder.',
                    'bodyPart': 'Elbow',
                    'durationSeconds': 60,
                },
                {
                    'name': 'Tricep Extensions',
                    'description': 'Hold a light weight behind your head and extend your arm upward.',
                    'bodyPart': 'Elbow',
                    'durationSeconds': 45,
                },
                {
                    'name': 'Elbow Stretches',
                    'description': 'Extend your arm and gently pull your hand toward your opposite shoulder.',
                    'bodyPart': 'Elbow',
                    'durationSeconds': 30,
                }
            ],
            'hip': [
                {
                    'name': 'Hip Abduction',
                    'description': 'Lie on your side and lift your top leg upward, away from your other leg.',
                    'bodyPart': 'Hip',
                    'durationSeconds': 30,
                },
                {
                    'name': 'Hip Flexion',
                    'description': 'Standing, lift your knee toward your chest.',
                    'bodyPart': 'Hip',
                    'durationSeconds': 45,
                },
                {
                    'name': 'Hip Extensions',
                    'description': 'Standing, extend one leg behind you, keeping it straight.',
                    'bodyPart': 'Hip',
                    'durationSeconds': 60,
                },
                {
                    'name': 'Bridges',
                    'description': 'Lie on your back with knees bent. Lift your hips forming a bridge.',
                    'bodyPart': 'Hip',
                    'durationSeconds': 45,
                },
                {
                    'name': 'Clamshells',
                    'description': 'Lie on your side with knees bent. Open your top knee like a clamshell while keeping feet together.',
                    'bodyPart': 'Hip',
                    'durationSeconds': 30,
                }
            ],
            'back': [
                {
                    'name': 'Prone Press-ups',
                    'description': 'Lie face down and press up with your hands, keeping your hips on the ground.',
                    'bodyPart': 'Back',
                    'durationSeconds': 30,
                },
                {
                    'name': 'Bridges',
                    'description': 'Lie on your back with knees bent. Lift your hips forming a bridge.',
                    'bodyPart': 'Back',
                    'durationSeconds': 45,
                },
                {
                    'name': 'Cat-Camel Stretch',
                    'description': 'On hands and knees, alternate between arching and rounding your back.',
                    'bodyPart': 'Back',
                    'durationSeconds': 60,
                },
                {
                    'name': 'Bird Dog',
                    'description': 'On hands and knees, extend opposite arm and leg simultaneously.',
                    'bodyPart': 'Back',
                    'durationSeconds': 45,
                },
                {
                    'name': 'Pelvic Tilts',
                    'description': 'Lie on your back with knees bent. Tilt your pelvis by flattening your back against the floor.',
                    'bodyPart': 'Back',
                    'durationSeconds': 30,
                }
            ],
            'neck': [
                {
                    'name': 'Neck Rotation',
                    'description': 'Slowly turn your head to look over each shoulder.',
                    'bodyPart': 'Neck',
                    'durationSeconds': 30,
                },
                {
                    'name': 'Chin Tucks',
                    'description': 'Pull your chin straight back, creating a "double chin."',
                    'bodyPart': 'Neck',
                    'durationSeconds': 45,
                },
                {
                    'name': 'Side Bend Stretch',
                    'description': 'Gently tilt your head toward each shoulder.',
                    'bodyPart': 'Neck',
                    'durationSeconds': 60,
                },
                {
                    'name': 'Neck Flexion and Extension',
                    'description': 'Gently nod your head forward and back.',
                    'bodyPart': 'Neck',
                    'durationSeconds': 45,
                },
                {
                    'name': 'Isometric Exercises',
                    'description': 'Place your hand against your head and push gently, resisting with your neck muscles.',
                    'bodyPart': 'Neck',
                    'durationSeconds': 30,
                }
            ],
            'default': [
                {
                    'name': 'Range of Motion Exercise',
                    'description': 'Gently move the affected body part through its full range of motion, stopping when you feel pain or discomfort.',
                    'bodyPart': 'General',
                    'durationSeconds': 30,
                },
                {
                    'name': 'Strengthening Exercise',
                    'description': 'Using light resistance, perform targeted strengthening movements for the affected area.',
                    'bodyPart': 'General',
                    'durationSeconds': 45,
                },
                {
                    'name': 'Stability Exercise',
                    'description': 'Focus on maintaining balance and stability while engaging the affected area.',
                    'bodyPart': 'General',
                    'durationSeconds': 60,
                }
            ]
        }
        
        return exercises

    def generate_plan(self, rehab_data):
        """Generate a personalized rehabilitation plan based on user data"""
        try:
            print("=== GENERATING PLAN ===")
            # Extract data
            medical_history = rehab_data.get('medicalHistory', {})
            physical_condition = rehab_data.get('physicalCondition', {})
            goals = rehab_data.get('rehabilitationGoals', [])
            
            body_part = physical_condition.get('bodyPart', 'Knee')
            pain_level = int(physical_condition.get('painLevel', 5))
            pain_location = physical_condition.get('painLocation', 'Joint')
            previous_injuries = medical_history.get('previousInjuries', 'None')
            surgical_history = medical_history.get('surgicalHistory', 'None')
            primary_goal = goals[0] if goals else 'Pain reduction'
            
            print(f"Processing plan for pain level: {pain_level}")
            
            # EXPLICIT LOGIC BASED ON PAIN LEVEL
            if pain_level >= 8:  # High pain (8-10)
                difficulty = 'beginner'
                sets = 1
                reps = 5
                max_duration = 15
                plan_type = "gentle, beginner-friendly"
                pain_priority = 'high'
                print(f"High pain detected: sets={sets}, reps={reps}, difficulty={difficulty}")
                
            elif pain_level >= 6:  # Moderate-high pain (6-7)
                difficulty = 'beginner'
                sets = 2
                reps = 6
                max_duration = 25
                plan_type = "careful, low-intensity"
                pain_priority = 'high'
                print(f"Moderate-high pain detected: sets={sets}, reps={reps}, difficulty={difficulty}")
                
            elif pain_level >= 4:  # Moderate pain (4-5)
                difficulty = 'intermediate'
                sets = 2
                reps = 10
                max_duration = 45
                plan_type = "balanced intensity"
                pain_priority = 'medium'
                print(f"Moderate pain detected: sets={sets}, reps={reps}, difficulty={difficulty}")
                
            elif pain_level >= 2:  # Low-moderate pain (2-3)
                difficulty = 'intermediate'
                sets = 3
                reps = 12
                max_duration = 60
                plan_type = "progressive"
                pain_priority = 'low'
                print(f"Low-moderate pain detected: sets={sets}, reps={reps}, difficulty={difficulty}")
                
            else:  # Very low pain (0-1)
                difficulty = 'advanced'
                sets = 4
                reps = 15
                max_duration = 90
                plan_type = "intensive, strength-focused"
                pain_priority = 'low'
                print(f"Very low pain detected: sets={sets}, reps={reps}, difficulty={difficulty}")
            
            # Get exercises from database
            exercise_db = self.get_exercise_database()
            body_part_key = body_part.lower()
            if body_part_key in exercise_db:
                exercises_list = exercise_db[body_part_key]
            else:
                exercises_list = exercise_db['default']
            
            # Create exercises with our explicit parameters
            exercises = []
            for i, ex in enumerate(exercises_list):
                exercise_id = f"{body_part.lower()}_{i+1}_{uuid.uuid4().hex[:4]}"
                
                # Adjust duration based on pain level
                duration = min(ex['durationSeconds'], max_duration)
                
                exercise = {
                    'id': exercise_id,
                    'name': ex['name'],
                    'description': ex['description'],
                    'bodyPart': ex['bodyPart'],
                    'sets': sets,  # Use our calculated sets
                    'reps': reps,  # Use our calculated reps
                    'durationSeconds': duration,
                    'difficultyLevel': difficulty  # Use our calculated difficulty
                }
                exercises.append(exercise)
                print(f"Created exercise {i+1}: {ex['name']} - {sets} sets, {reps} reps, {difficulty}")
            
            # Create plan title and description
            title = f"{body_part} Rehabilitation Plan"
            
            # Create description based on pain level
            if pain_level >= 8:
                description = f"A gentle, beginner-friendly plan for {body_part} recovery with high pain management focus."
            elif pain_level >= 6:
                description = f"A careful, low-intensity plan for {body_part} recovery focusing on pain management."
            elif pain_level >= 4:
                description = f"A balanced intensity plan for {body_part} recovery with moderate pain management."
            elif pain_level >= 2:
                description = f"A progressive plan for {body_part} recovery with strength and mobility focus."
            else:
                description = f"An intensive, strength-focused plan for {body_part} recovery with advanced exercises."
                
            if goals:
                description += f" Focusing on {', '.join(goals)}."
            
            # Create the rehabilitation plan
            plan = {
                'title': title,
                'description': description,
                'exercises': exercises,
                'goals': {
                    'primary': primary_goal,
                    'bodyPart': body_part,
                    'painReduction': pain_priority,
                }
            }
            
            print(f"Generated plan with {len(exercises)} exercises, pain priority: {pain_priority}")
            return plan
        
        except Exception as e:
            print(f"Error generating plan: {e}")
            raise

    def get_model_metrics(self):
        """Get model performance metrics"""
        if self.metrics is None:
            # Load metrics if not already loaded
            try:
                with open(f'{self.models_dir}/metrics.json', 'r') as f:
                    self.metrics = json.load(f)
            except FileNotFoundError:
                return {'error': 'No metrics available. Please train models first.'}
        
        return self.metrics

    def retrain_models(self):
        """Retrain all models"""
        return self.train_models_with_metrics()

# Global instance
plan_generator = PlanGenerationModel()

# Public interface functions
def initialize_plan_generator():
    """Initialize the plan generation model"""
    return plan_generator.load_models()

def generate_rehabilitation_plan(rehab_data):
    """Public interface to generate rehabilitation plan"""
    return plan_generator.generate_plan(rehab_data)

def get_plan_model_metrics():
    """Public interface to get model metrics"""
    return plan_generator.get_model_metrics()

def retrain_plan_models():
    """Public interface to retrain models"""
    return plan_generator.retrain_models()

def check_plan_generator_health():
    """Check if plan generator is ready"""
    return {
        'status': 'ok' if plan_generator.encoder is not None else 'not_initialized',
        'models_loaded': {
            'encoder': plan_generator.encoder is not None,
            'difficulty_model': plan_generator.difficulty_model is not None,
            'sets_model': plan_generator.sets_model is not None,
            'reps_model': plan_generator.reps_model is not None,
        }
    }