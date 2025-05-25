# Complete Enhanced backend/app.py with feedback analysis and original functionality
from flask import Flask, request, jsonify
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
import shutil
import json
from datetime import datetime, timedelta
from flask_cors import CORS
import logging

app = Flask(__name__)
CORS(app)

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Create directories for models and data if they don't exist
os.makedirs('models', exist_ok=True)
os.makedirs('data', exist_ok=True)

# Global variables for models
encoder = None
difficulty_model = None
sets_model = None
reps_model = None
feedback_analyzer = None
plan_optimizer = None

class FeedbackAnalyzer:
    """Analyzes exercise feedback and provides personalized recommendations"""
    
    def __init__(self):
        self.pain_threshold_high = 7
        self.pain_threshold_low = 3
        self.completion_threshold_low = 0.7
        self.difficulty_adjustment_factors = {
            'easy': 1.2,  # Increase by 20%
            'perfect': 1.0,  # No change
            'hard': 0.8   # Decrease by 20%
        }
    
    def analyze_feedback(self, feedback_data):
        """Analyze exercise feedback and provide recommendations"""
        try:
            # Extract key metrics
            pain_before = feedback_data.get('painLevelBefore', 5)
            pain_after = feedback_data.get('painLevelAfter', 5)
            pain_change = pain_after - pain_before
            difficulty_rating = feedback_data.get('difficultyRating', 'perfect')
            completion_rate = self._calculate_completion_rate(feedback_data)
            
            # Initialize recommendations list
            recommendations = []
            adjustments = {}
            
            # Analyze pain levels
            pain_analysis = self._analyze_pain_levels(pain_before, pain_after, pain_change)
            recommendations.extend(pain_analysis['recommendations'])
            adjustments.update(pain_analysis['adjustments'])
            
            # Analyze difficulty
            difficulty_analysis = self._analyze_difficulty(difficulty_rating, completion_rate)
            recommendations.extend(difficulty_analysis['recommendations'])
            adjustments.update(difficulty_analysis['adjustments'])
            
            # Analyze completion rate
            completion_analysis = self._analyze_completion_rate(completion_rate)
            recommendations.extend(completion_analysis['recommendations'])
            adjustments.update(completion_analysis['adjustments'])
            
            # Calculate overall exercise effectiveness score
            effectiveness_score = self._calculate_effectiveness_score(
                pain_change, completion_rate, difficulty_rating
            )
            
            return {
                'recommendations': recommendations,
                'adjustments': adjustments,
                'effectiveness_score': effectiveness_score,
                'pain_analysis': {
                    'pain_change': pain_change,
                    'is_beneficial': pain_change <= 0,
                    'severity': self._get_pain_severity(pain_after)
                },
                'completion_analysis': {
                    'completion_rate': completion_rate,
                    'is_adequate': completion_rate >= self.completion_threshold_low
                },
                'difficulty_analysis': {
                    'rating': difficulty_rating,
                    'is_appropriate': difficulty_rating == 'perfect'
                }
            }
            
        except Exception as e:
            logger.error(f"Error analyzing feedback: {e}")
            return {
                'recommendations': ['Unable to analyze feedback at this time'],
                'adjustments': {},
                'effectiveness_score': 0.5,
                'error': str(e)
            }
    
    def _calculate_completion_rate(self, feedback_data):
        """Calculate completion rate based on sets and reps"""
        completed_sets = feedback_data.get('completedSets', 0)
        target_sets = feedback_data.get('targetSets', 1)
        completed_reps = feedback_data.get('completedReps', 0)
        target_reps = feedback_data.get('targetReps', 1)
        
        sets_completion = completed_sets / max(target_sets, 1)
        reps_completion = completed_reps / max(target_reps, 1)
        
        return (sets_completion + reps_completion) / 2
    
    def _analyze_pain_levels(self, pain_before, pain_after, pain_change):
        """Analyze pain level changes and provide recommendations"""
        recommendations = []
        adjustments = {}
        
        if pain_after >= self.pain_threshold_high:
            recommendations.append("High pain level detected. Consider reducing exercise intensity.")
            adjustments['intensity_multiplier'] = 0.7
            adjustments['rest_time_multiplier'] = 1.5
        elif pain_change > 2:
            recommendations.append("Pain increased significantly. Monitor closely and consider modifications.")
            adjustments['intensity_multiplier'] = 0.8
        elif pain_change < -2:
            recommendations.append("Great! Pain decreased significantly. This exercise is very beneficial.")
            adjustments['intensity_multiplier'] = 1.1
        elif pain_change <= 0:
            recommendations.append("Exercise helped maintain or reduce pain levels. Continue as prescribed.")
        
        if pain_before >= self.pain_threshold_high and pain_after < pain_before:
            recommendations.append("Excellent progress! Pre-exercise pain was high but improved.")
        
        return {
            'recommendations': recommendations,
            'adjustments': adjustments
        }
    
    def _analyze_difficulty(self, difficulty_rating, completion_rate):
        """Analyze difficulty rating and provide recommendations"""
        recommendations = []
        adjustments = {}
        
        if difficulty_rating == 'easy':
            recommendations.append("Exercise seems too easy. Consider increasing intensity next time.")
            adjustments['sets_multiplier'] = 1.2
            adjustments['reps_multiplier'] = 1.1
            adjustments['difficulty_level'] = 'intermediate'
        elif difficulty_rating == 'hard':
            if completion_rate < 0.7:
                recommendations.append("Exercise is too challenging. Reducing intensity recommended.")
                adjustments['sets_multiplier'] = 0.8
                adjustments['reps_multiplier'] = 0.9
                adjustments['difficulty_level'] = 'beginner'
            else:
                recommendations.append("Exercise is challenging but manageable. Good work!")
        elif difficulty_rating == 'perfect':
            recommendations.append("Perfect difficulty level! Maintain current intensity.")
        
        return {
            'recommendations': recommendations,
            'adjustments': adjustments
        }
    
    def _analyze_completion_rate(self, completion_rate):
        """Analyze completion rate and provide recommendations"""
        recommendations = []
        adjustments = {}
        
        if completion_rate < 0.5:
            recommendations.append("Low completion rate. Focus on form over quantity.")
            adjustments['sets_multiplier'] = 0.7
            adjustments['reps_multiplier'] = 0.8
        elif completion_rate < self.completion_threshold_low:
            recommendations.append("Completion rate could be improved. Consider slight intensity reduction.")
            adjustments['sets_multiplier'] = 0.9
        elif completion_rate >= 1.0:
            recommendations.append("Excellent completion rate! You might be ready for more challenge.")
            adjustments['sets_multiplier'] = 1.1
        
        return {
            'recommendations': recommendations,
            'adjustments': adjustments
        }
    
    def _calculate_effectiveness_score(self, pain_change, completion_rate, difficulty_rating):
        """Calculate overall exercise effectiveness score (0-1)"""
        score = 0.5  # Base score
        
        # Pain contribution (40% of score)
        if pain_change <= -2:
            score += 0.4  # Significant pain reduction
        elif pain_change <= 0:
            score += 0.2  # Pain maintained or slightly reduced
        elif pain_change <= 2:
            score -= 0.1  # Slight pain increase
        else:
            score -= 0.3  # Significant pain increase
        
        # Completion contribution (30% of score)
        if completion_rate >= 0.9:
            score += 0.3
        elif completion_rate >= 0.7:
            score += 0.2
        elif completion_rate >= 0.5:
            score += 0.1
        else:
            score -= 0.2
        
        # Difficulty contribution (30% of score)
        if difficulty_rating == 'perfect':
            score += 0.3
        elif difficulty_rating == 'easy':
            score += 0.1
        else:  # hard
            score += 0.15
        
        return max(0.0, min(1.0, score))
    
    def _get_pain_severity(self, pain_level):
        """Get pain severity description"""
        if pain_level == 0:
            return 'no_pain'
        elif pain_level <= 3:
            return 'mild'
        elif pain_level <= 5:
            return 'moderate'
        elif pain_level <= 7:
            return 'severe'
        else:
            return 'very_severe'

class ExercisePlanOptimizer:
    """Optimizes exercise plans based on user feedback and machine learning"""
    
    def __init__(self):
        self.feedback_history = []
    
    def optimize_exercise_plan(self, user_id, exercise_id, feedback_history):
        """Optimize exercise parameters based on feedback history"""
        try:
            if not feedback_history:
                return {'status': 'no_data', 'message': 'Insufficient data for optimization'}
            
            # Analyze trends
            trends = self._analyze_trends(feedback_history)
            
            # Generate optimized parameters
            optimized_params = self._generate_optimized_parameters(
                feedback_history[-1], trends
            )
            
            return {
                'status': 'success',
                'optimized_parameters': optimized_params,
                'trends': trends,
                'recommendations': self._generate_optimization_recommendations(trends)
            }
            
        except Exception as e:
            logger.error(f"Error optimizing exercise plan: {e}")
            return {'status': 'error', 'message': str(e)}
    
    def _analyze_trends(self, feedback_history):
        """Analyze trends in feedback data"""
        if len(feedback_history) < 3:
            return {'insufficient_data': True}
        
        # Extract metrics over time
        pain_levels = [f.get('painLevelAfter', 5) for f in feedback_history]
        completion_rates = [self._calculate_completion_rate_simple(f) for f in feedback_history]
        difficulty_scores = [self._get_difficulty_score(f.get('difficultyRating', 'perfect')) for f in feedback_history]
        
        return {
            'pain_trend': self._calculate_trend(pain_levels),
            'completion_trend': self._calculate_trend(completion_rates),
            'difficulty_trend': self._calculate_trend(difficulty_scores),
            'average_pain': np.mean(pain_levels),
            'average_completion': np.mean(completion_rates),
            'sessions_count': len(feedback_history)
        }
    
    def _calculate_trend(self, values):
        """Calculate trend direction (improving, stable, declining)"""
        if len(values) < 3:
            return 'insufficient_data'
        
        # Simple linear trend
        x = np.arange(len(values))
        slope = np.polyfit(x, values, 1)[0]
        
        if abs(slope) < 0.1:
            return 'stable'
        elif slope > 0:
            return 'increasing'
        else:
            return 'decreasing'
    
    def _calculate_completion_rate_simple(self, feedback):
        """Simple completion rate calculation"""
        completed = feedback.get('completedSets', 0) * feedback.get('completedReps', 0)
        target = feedback.get('targetSets', 1) * feedback.get('targetReps', 1)
        return completed / max(target, 1)
    
    def _get_difficulty_score(self, difficulty_rating):
        """Convert difficulty rating to numeric score"""
        scores = {'easy': 1, 'perfect': 2, 'hard': 3}
        return scores.get(difficulty_rating, 2)
    
    def _generate_optimized_parameters(self, latest_feedback, trends):
        """Generate optimized exercise parameters"""
        current_sets = latest_feedback.get('targetSets', 3)
        current_reps = latest_feedback.get('targetReps', 10)
        
        # Base multipliers
        sets_multiplier = 1.0
        reps_multiplier = 1.0
        
        # Adjust based on trends
        if trends.get('pain_trend') == 'increasing':
            sets_multiplier *= 0.8
            reps_multiplier *= 0.9
        elif trends.get('pain_trend') == 'decreasing':
            sets_multiplier *= 1.1
            reps_multiplier *= 1.05
        
        if trends.get('completion_trend') == 'decreasing':
            sets_multiplier *= 0.9
        elif trends.get('completion_trend') == 'increasing':
            sets_multiplier *= 1.1
        
        # Apply latest feedback adjustments
        latest_difficulty = latest_feedback.get('difficultyRating', 'perfect')
        if latest_difficulty == 'easy':
            sets_multiplier *= 1.2
            reps_multiplier *= 1.1
        elif latest_difficulty == 'hard':
            sets_multiplier *= 0.8
            reps_multiplier *= 0.9
        
        return {
            'optimized_sets': max(1, int(current_sets * sets_multiplier)),
            'optimized_reps': max(1, int(current_reps * reps_multiplier)),
            'sets_change': sets_multiplier - 1.0,
            'reps_change': reps_multiplier - 1.0
        }
    
    def _generate_optimization_recommendations(self, trends):
        """Generate recommendations based on trends"""
        recommendations = []
        
        if trends.get('pain_trend') == 'increasing':
            recommendations.append("Pain levels are increasing. Consider reducing intensity or consulting therapist.")
        elif trends.get('pain_trend') == 'decreasing':
            recommendations.append("Great progress! Pain levels are decreasing consistently.")
        
        if trends.get('completion_trend') == 'decreasing':
            recommendations.append("Completion rates are declining. Focus on consistency over intensity.")
        elif trends.get('completion_trend') == 'increasing':
            recommendations.append("Completion rates are improving. Consider gradual progression.")
        
        if trends.get('average_pain') > 7:
            recommendations.append("Average pain levels are high. Prioritize pain management.")
        
        return recommendations

# Updated generate_sample_data function with better pain level logic
def generate_sample_data():
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

# Train and save the models with metrics calculation
def train_models_with_metrics():
    print("Training models with metrics evaluation...")
    
    # Generate sample data
    df = generate_sample_data()
    
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
    
    # Ensure models directory exists
    os.makedirs('models', exist_ok=True)
    
    # Save metrics to a file
    with open('models/metrics.json', 'w') as f:
        json.dump(metrics, f, indent=4, default=str)
    
    # Save models and encoder
    try:
        joblib.dump(dt_diff, 'models/difficulty_model.pkl')
        joblib.dump(rf_sets, 'models/sets_model.pkl')
        joblib.dump(rf_reps, 'models/reps_model.pkl')
        joblib.dump(encoder, 'models/feature_encoder.pkl')
        print("Models saved successfully.")
    except Exception as e:
        print(f"Error saving models: {e}")
        raise
    
    return encoder, dt_diff, rf_sets, rf_reps, metrics

# Load or train models with metrics
def get_models_with_metrics():
    try:
        # Try to load all models
        encoder = joblib.load('models/feature_encoder.pkl')
        dt_diff = joblib.load('models/difficulty_model.pkl')
        rf_sets = joblib.load('models/sets_model.pkl')
        rf_reps = joblib.load('models/reps_model.pkl')
        
        # Try to load metrics
        with open('models/metrics.json', 'r') as f:
            metrics = json.load(f)
            
        print("Models and metrics loaded successfully.")
        return encoder, dt_diff, rf_sets, rf_reps, metrics
    except (FileNotFoundError, EOFError, Exception) as e:
        # If any error occurs during loading, retrain all models
        print(f"Error loading models or metrics: {e}. Training new models...")
        return train_models_with_metrics()

# Exercise database
def get_exercise_database():
    """
    Database of exercises for different body parts
    """
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

def generate_plan(rehab_data):
    """
    Generate a personalized rehabilitation plan based on user data
    """
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
        
        # EXPLICIT LOGIC BASED ON PAIN LEVEL - NO ML PREDICTIONS
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
        exercise_db = get_exercise_database()
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

# Initialize global components
feedback_analyzer = FeedbackAnalyzer()
plan_optimizer = ExercisePlanOptimizer()

# API routes - Original functionality
@app.route('/api/generate_plan', methods=['POST'])
def api_generate_plan():
    try:
        print("Received request")
        print(request.json) 
        rehab_data = request.json
        plan = generate_plan(rehab_data)
        return jsonify(plan)
    except Exception as e:
        print(f"Error in /generate_plan: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/health', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'ok',
        'timestamp': datetime.now().isoformat(),
        'services': {
            'plan_generation': 'available',
            'feedback_analyzer': 'available',
            'plan_optimizer': 'available'
        }
    })

@app.route('/api/model_metrics', methods=['GET'])
def get_model_metrics():
    try:
        # Load metrics from file
        with open('models/metrics.json', 'r') as f:
            metrics = json.load(f)
        return jsonify(metrics)
    except FileNotFoundError:
        # If metrics file doesn't exist, train models to generate metrics
        try:
            _, _, _, _, metrics = train_models_with_metrics()
            return jsonify(metrics)
        except Exception as e:
            return jsonify({'error': f'Error generating metrics: {str(e)}'}), 500
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/retrain_models', methods=['POST'])
def retrain_models():
    try:
        _, _, _, _, metrics = train_models_with_metrics()
        return jsonify({
            'status': 'success',
            'message': 'Models retrained successfully',
            'metrics': metrics
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# New API endpoints for feedback analysis
@app.route('/api/analyze_feedback', methods=['POST'])
def analyze_feedback():
    """Analyze exercise feedback and provide recommendations"""
    try:
        data = request.json
        feedback_data = data.get('feedback', {})
        
        logger.info(f"Analyzing feedback for exercise: {feedback_data.get('exerciseName')}")
        
        # Analyze the feedback
        analysis_result = feedback_analyzer.analyze_feedback(feedback_data)
        
        # Store feedback for future analysis (in production, save to database)
        feedback_id = str(uuid.uuid4())
        feedback_file = f"data/feedback_{feedback_id}.json"
        with open(feedback_file, 'w') as f:
            json.dump({
                'id': feedback_id,
                'feedback': feedback_data,
                'analysis': analysis_result,
                'timestamp': datetime.now().isoformat()
            }, f, indent=2)
        
        return jsonify({
            'status': 'success',
            'feedback_id': feedback_id,
            'analysis': analysis_result
        })
        
    except Exception as e:
        logger.error(f"Error in analyze_feedback: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/optimize_plan', methods=['POST'])
def optimize_exercise_plan():
    """Optimize exercise plan based on feedback history"""
    try:
        data = request.json
        user_id = data.get('userId')
        exercise_id = data.get('exerciseId')
        feedback_history = data.get('feedbackHistory', [])
        
        logger.info(f"Optimizing plan for user {user_id}, exercise {exercise_id}")
        
        # Optimize the plan
        optimization_result = plan_optimizer.optimize_exercise_plan(
            user_id, exercise_id, feedback_history
        )
        
        return jsonify(optimization_result)
        
    except Exception as e:
        logger.error(f"Error in optimize_plan: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/feedback_trends', methods=['POST'])
def get_feedback_trends():
    """Get feedback trends for a user"""
    try:
        data = request.json
        user_id = data.get('userId')
        days_back = data.get('daysBack', 30)
        
        # In production, fetch from database
        # For now, return mock trend data based on typical rehabilitation patterns
        mock_trends = {
            'pain_levels': [6, 5.5, 5, 4.5, 4, 3.5, 3],
            'completion_rates': [0.7, 0.75, 0.8, 0.85, 0.9, 0.92, 0.95],
            'difficulty_ratings': ['hard', 'hard', 'perfect', 'perfect', 'perfect', 'easy', 'easy'],
            'dates': ['2024-01-01', '2024-01-02', '2024-01-03', '2024-01-04', 
                     '2024-01-05', '2024-01-06', '2024-01-07'],
            'overall_trend': 'improving',
            'recommendations': [
                'Pain levels are decreasing consistently - excellent progress!',
                'Completion rates are improving steadily',
                'Recent exercises seem too easy - consider progression'
            ]
        }
        
        return jsonify({
            'status': 'success',
            'trends': mock_trends,
            'user_id': user_id,
            'period_days': days_back
        })
        
    except Exception as e:
        logger.error(f"Error getting feedback trends: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/exercise_insights', methods=['POST'])
def get_exercise_insights():
    """Get insights for a specific exercise"""
    try:
        data = request.json
        user_id = data.get('userId')
        exercise_id = data.get('exerciseId')
        
        # Mock insights data (in production, calculate from real feedback)
        mock_insights = {
            'total_attempts': 15,
            'average_completion': 0.87,
            'pain_improvement': -2.3,  # Negative means improvement
            'difficulty_trend': 'stable',
            'last_performed': '2024-01-07',
            'recommendations': [
                'Exercise is showing good pain reduction benefits',
                'Completion rate is excellent - consider slight progression',
                'Maintain current difficulty level'
            ],
            'effectiveness_score': 0.83,
            'pain_levels_over_time': [6, 5, 4, 4, 3, 3, 2],
            'difficulty_distribution': {
                'easy': 3,
                'perfect': 10,
                'hard': 2
            }
        }
        
        return jsonify({
            'status': 'success',
            'insights': mock_insights,
            'exercise_id': exercise_id,
            'user_id': user_id
        })
        
    except Exception as e:
        logger.error(f"Error getting exercise insights: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/user_analytics', methods=['POST'])
def get_user_analytics():
    """Get comprehensive analytics for a user"""
    try:
        data = request.json
        user_id = data.get('userId')
        time_period = data.get('timePeriod', 30)  # days
        
        # Mock comprehensive analytics data
        mock_analytics = {
            'summary': {
                'total_sessions': 25,
                'average_pain_reduction': 2.1,
                'overall_adherence': 0.85,
                'effectiveness_score': 0.78
            },
            'pain_analytics': {
                'average_pre_pain': 6.2,
                'average_post_pain': 4.1,
                'pain_reduction_trend': 'improving',
                'best_exercises_for_pain': [
                    'Straight Leg Raises',
                    'Wall Squats',
                    'Knee Extensions'
                ]
            },
            'difficulty_analytics': {
                'distribution': {'easy': 30, 'perfect': 60, 'hard': 10},
                'trend': 'becoming_easier',
                'progression_ready': True
            },
            'completion_analytics': {
                'average_completion': 0.87,
                'trend': 'improving',
                'consistency_score': 0.82
            },
            'recommendations': [
                'Excellent progress with consistent pain reduction',
                'Ready for progression to more challenging exercises',
                'Maintain current exercise frequency',
                'Consider adding strength-focused exercises'
            ],
            'goals_progress': {
                'pain_reduction': 0.85,  # 85% achieved
                'range_of_motion': 0.72,
                'strength': 0.60,
                'daily_function': 0.78
            }
        }
        
        return jsonify({
            'status': 'success',
            'analytics': mock_analytics,
            'user_id': user_id,
            'time_period_days': time_period,
            'generated_at': datetime.now().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Error getting user analytics: {e}")
        return jsonify({'error': str(e)}), 500

# Debug endpoint for testing
@app.route('/api/debug_plan', methods=['POST'])
def debug_generate_plan():
    try:
        print("=== DEBUG PLAN GENERATION ===")
        rehab_data = request.json
        print(f"Received data: {rehab_data}")
        
        # Extract pain level specifically
        physical_condition = rehab_data.get('physicalCondition', {})
        pain_level = physical_condition.get('painLevel')
        
        print(f"Pain level received: {pain_level} (type: {type(pain_level)})")
        
        # Try to convert to int
        try:
            pain_level_int = int(pain_level)
            print(f"Pain level as int: {pain_level_int}")
        except (ValueError, TypeError) as e:
            print(f"Error converting pain level to int: {e}")
            pain_level_int = 5
        
        # Show what category it falls into
        if pain_level_int >= 8:
            category = "High pain (8-10)"
            expected_sets = 1
            expected_reps = 5
            expected_difficulty = "beginner"
        elif pain_level_int >= 6:
            category = "Moderate-high pain (6-7)"
            expected_sets = 2
            expected_reps = 6
            expected_difficulty = "beginner"
        elif pain_level_int >= 4:
            category = "Moderate pain (4-5)"
            expected_sets = 2
            expected_reps = 10
            expected_difficulty = "intermediate"
        elif pain_level_int >= 2:
            category = "Low-moderate pain (2-3)"
            expected_sets = 3
            expected_reps = 12
            expected_difficulty = "intermediate"
        else:
            category = "Very low pain (0-1)"
            expected_sets = 4
            expected_reps = 15
            expected_difficulty = "advanced"
        
        print(f"Pain category: {category}")
        print(f"Expected: {expected_sets} sets, {expected_reps} reps, {expected_difficulty}")
        
        # Generate the actual plan
        plan = generate_plan(rehab_data)
        
        # Check if the plan matches expectations
        if plan['exercises']:
            actual_sets = plan['exercises'][0]['sets']
            actual_reps = plan['exercises'][0]['reps']
            actual_difficulty = plan['exercises'][0]['difficultyLevel']
            
            print(f"Actual result: {actual_sets} sets, {actual_reps} reps, {actual_difficulty}")
            
            if (actual_sets == expected_sets and 
                actual_reps == expected_reps and 
                actual_difficulty == expected_difficulty):
                print("✅ Plan generation working correctly!")
            else:
                print("❌ Plan generation not working as expected!")
        
        print("=== END DEBUG ===")
        return jsonify({
            'debug_info': {
                'received_pain_level': pain_level,
                'pain_level_type': str(type(pain_level)),
                'converted_pain_level': pain_level_int,
                'pain_category': category,
                'expected_sets': expected_sets,
                'expected_reps': expected_reps,
                'expected_difficulty': expected_difficulty,
            },
            'plan': plan
        })
        
    except Exception as e:
        print(f"Debug error: {e}")
        return jsonify({'error': str(e), 'debug_info': 'Error occurred'}), 500

# Initialize models and metrics on startup
def initialize():
    try:
        global encoder, difficulty_model, sets_model, reps_model
        encoder, difficulty_model, sets_model, reps_model, _ = get_models_with_metrics()
        print("Models and metrics initialized successfully")
        print("Feedback analyzer and plan optimizer ready")
    except Exception as e:
        print(f"Error initializing models and metrics: {e}")

# Initialize on startup
with app.app_context():
    initialize()

if __name__ == '__main__':
    print("Starting Enhanced Flask backend server...")
    print("Server will be available at: http://localhost:5000")
    print("\n=== Available Endpoints ===")
    print("Health check: GET /api/health")
    print("Generate plan: POST /api/generate_plan")
    print("Model metrics: GET /api/model_metrics")
    print("Retrain models: POST /api/retrain_models")
    print("\n=== Feedback Analysis Endpoints ===")
    print("Analyze feedback: POST /api/analyze_feedback")
    print("Optimize plan: POST /api/optimize_plan")
    print("Feedback trends: POST /api/feedback_trends")
    print("Exercise insights: POST /api/exercise_insights")
    print("User analytics: POST /api/user_analytics")
    print("Debug plan: POST /api/debug_plan")
    print("\n=== Features ===")
    print("✅ Pain level-based plan generation")
    print("✅ Exercise feedback analysis")
    print("✅ AI-powered recommendations")
    print("✅ Plan optimization based on user data")
    print("✅ Comprehensive analytics and insights")
    print("✅ Real-time feedback processing")
    
    app.run(debug=True, host='0.0.0.0', port=5000)