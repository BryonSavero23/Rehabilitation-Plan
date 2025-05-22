import os
import json
import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.tree import DecisionTreeClassifier
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.metrics import accuracy_score, classification_report
import joblib

# Load simulated data
def load_data():
    """Load simulated data from JSON files and prepare for training"""
    print("Loading simulated data...")
    
    patients = []
    plans = []
    progress_logs = []
    
    # Load patient data
    patient_dir = 'simulated_data/users'
    for filename in os.listdir(patient_dir):
        if filename.startswith('patient_'):
            with open(os.path.join(patient_dir, filename), 'r') as f:
                patient = json.load(f)
                patients.append(patient)
    
    # Load plan data
    plan_dir = 'simulated_data/plans'
    for filename in os.listdir(plan_dir):
        with open(os.path.join(plan_dir, filename), 'r') as f:
            plan = json.load(f)
            plans.append(plan)
    
    # Load progress data
    progress_dir = 'simulated_data/progress'
    for filename in os.listdir(progress_dir):
        with open(os.path.join(progress_dir, filename), 'r') as f:
            progress = json.load(f)
            progress_logs.append(progress)
    
    print(f"Loaded {len(patients)} patients, {len(plans)} plans, and {len(progress_logs)} progress logs.")
    return patients, plans, progress_logs

def prepare_data_for_exercise_recommendation(patients, plans):
    """Prepare data for exercise recommendation model"""
    print("Preparing data for exercise recommendation model...")
    
    data = []
    
    for plan in plans:
        # Skip plans without exercises
        if not plan['exercises']:
            continue
        
        # Find the patient for this plan
        patient_id = plan['userId']
        patient = next((p for p in patients if p['id'] == patient_id), None)
        
        if not patient:
            continue
        
        # Extract features
        body_part = patient['physicalCondition'].get('bodyPart', 'Unknown')
        pain_level = patient['physicalCondition'].get('painLevel', 5)
        pain_location = patient['physicalCondition'].get('painLocation', 'Unknown')
        previous_injuries = patient['medicalHistory'].get('previousInjuries', 'None')
        surgical_history = patient['medicalHistory'].get('surgicalHistory', 'None')
        
        # Get rehab goals
        goals = patient.get('rehabilitationGoals', [])
        primary_goal = goals[0] if goals else 'Pain reduction'
        
        # For each exercise in the plan, create a training example
        for exercise in plan['exercises']:
            data.append({
                'body_part': body_part,
                'pain_level': pain_level,
                'pain_location': pain_location,
                'previous_injuries': previous_injuries,
                'surgical_history': surgical_history,
                'primary_goal': primary_goal,
                'exercise_name': exercise['name'],
                'exercise_difficulty': exercise['difficultyLevel'],
                'sets': exercise['sets'],
                'reps': exercise['reps']
            })
    
    # Convert to DataFrame
    df = pd.DataFrame(data)
    print(f"Created {len(df)} training examples for exercise recommendation.")
    return df

def prepare_data_for_plan_adjustment(plans, progress_logs):
    """Prepare data for plan adjustment model"""
    print("Preparing data for plan adjustment model...")
    
    data = []
    
    # Group progress logs by plan
    plan_logs = {}
    for log in progress_logs:
        plan_id = log['planId']
        if plan_id not in plan_logs:
            plan_logs[plan_id] = []
        plan_logs[plan_id].append(log)
    
    for plan_id, logs in plan_logs.items():
        # Find the plan
        plan = next((p for p in plans if p['id'] == plan_id), None)
        if not plan:
            continue
        
        # Sort logs by date
        logs.sort(key=lambda x: x['date'])
        
        # Need at least 3 logs to make adjustment decisions
        if len(logs) < 3:
            continue
        
        # For each consecutive set of 3 logs, create a training example
        for i in range(len(logs) - 3):
            log1, log2, log3 = logs[i], logs[i+1], logs[i+2]
            
            # Extract features
            avg_pain = np.mean([
                np.mean([ex_log['painLevel'] for ex_log in log1['exerciseLogs']]),
                np.mean([ex_log['painLevel'] for ex_log in log2['exerciseLogs']]),
                np.mean([ex_log['painLevel'] for ex_log in log3['exerciseLogs']])
            ])
            
            avg_adherence = np.mean([
                log1['adherencePercentage'],
                log2['adherencePercentage'],
                log3['adherencePercentage']
            ])
            
            avg_rating = np.mean([
                log1['overallRating'],
                log2['overallRating'],
                log3['overallRating']
            ])
            
            # Determine if plan was adjusted after these logs
            # In real application, this would be based on actual data
            # For simulation, we'll use a heuristic
            should_adjust = (avg_pain > 7 and avg_adherence < 70) or (avg_pain < 3 and avg_adherence > 90)
            
            # Determine adjustment type
            adjustment_type = 'no_change'
            if avg_pain > 7 and avg_adherence < 70:
                adjustment_type = 'decrease_difficulty'
            elif avg_pain < 3 and avg_adherence > 90:
                adjustment_type = 'increase_difficulty'
            
            data.append({
                'avg_pain': avg_pain,
                'avg_adherence': avg_adherence,
                'avg_rating': avg_rating,
                'should_adjust': should_adjust,
                'adjustment_type': adjustment_type
            })
    
    # Convert to DataFrame
    df = pd.DataFrame(data)
    print(f"Created {len(df)} training examples for plan adjustment.")
    return df

def train_exercise_recommendation_model(df):
    """Train a model to recommend exercises based on patient and condition data"""
    print("Training exercise recommendation model...")
    
    # Prepare features and target
    X = df[['body_part', 'pain_level', 'pain_location', 'previous_injuries', 
            'surgical_history', 'primary_goal']]
    y_difficulty = df['exercise_difficulty']
    y_sets = df['sets']
    y_reps = df['reps']
    
    # Encode categorical features
    categorical_features = ['body_part', 'pain_location', 'previous_injuries', 
                           'surgical_history', 'primary_goal']
    encoder = OneHotEncoder(sparse=False, handle_unknown='ignore')
    X_cat = pd.DataFrame(
        encoder.fit_transform(X[categorical_features]),
        columns=encoder.get_feature_names_out(categorical_features)
    )
    
    # Combine with numerical features
    X_num = X[['pain_level']].reset_index(drop=True)
    X_processed = pd.concat([X_num, X_cat], axis=1)
    
    # Split data
    X_train, X_test, y_train_diff, y_test_diff = train_test_split(
        X_processed, y_difficulty, test_size=0.2, random_state=42
    )
    _, _, y_train_sets, y_test_sets = train_test_split(
        X_processed, y_sets, test_size=0.2, random_state=42
    )
    _, _, y_train_reps, y_test_reps = train_test_split(
        X_processed, y_reps, test_size=0.2, random_state=42
    )
    
     # Train models for difficulty, sets, and reps
    # Decision Tree for difficulty level (categorical)
    dt_diff = DecisionTreeClassifier(max_depth=5, random_state=42)
    dt_diff.fit(X_train, y_train_diff)
    
    # Random Forest for sets and reps (numerical)
    rf_sets = RandomForestClassifier(n_estimators=50, random_state=42)
    rf_sets.fit(X_train, y_train_sets)
    
    rf_reps = RandomForestClassifier(n_estimators=50, random_state=42)
    rf_reps.fit(X_train, y_train_reps)
    
    # Evaluate models
    y_pred_diff = dt_diff.predict(X_test)
    y_pred_sets = rf_sets.predict(X_test)
    y_pred_reps = rf_reps.predict(X_test)
    
    print("Difficulty level prediction accuracy:", accuracy_score(y_test_diff, y_pred_diff))
    print("Sets prediction accuracy:", accuracy_score(y_test_sets, y_pred_sets))
    print("Reps prediction accuracy:", accuracy_score(y_test_reps, y_pred_reps))
    
    # Save models and encoders
    os.makedirs('models', exist_ok=True)
    joblib.dump(dt_diff, 'models/difficulty_model.pkl')
    joblib.dump(rf_sets, 'models/sets_model.pkl')
    joblib.dump(rf_reps, 'models/reps_model.pkl')
    joblib.dump(encoder, 'models/feature_encoder.pkl')
    
    print("Exercise recommendation models saved.")
    return dt_diff, rf_sets, rf_reps, encoder

def train_plan_adjustment_model(df):
    """Train a model to decide when and how to adjust rehabilitation plans"""
    print("Training plan adjustment model...")
    
    # Prepare features and targets
    X = df[['avg_pain', 'avg_adherence', 'avg_rating']]
    y_should_adjust = df['should_adjust']
    y_adjustment_type = df['adjustment_type']
    
    # Normalize numerical features
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    
    # Split data
    X_train, X_test, y_train_adj, y_test_adj = train_test_split(
        X_scaled, y_should_adjust, test_size=0.2, random_state=42
    )
    _, _, y_train_type, y_test_type = train_test_split(
        X_scaled, y_adjustment_type, test_size=0.2, random_state=42
    )
    
    # Train models
    # Decision Tree for adjustment decision (binary)
    dt_adjust = DecisionTreeClassifier(max_depth=3, random_state=42)
    dt_adjust.fit(X_train, y_train_adj)
    
    # Random Forest for adjustment type (categorical)
    rf_type = RandomForestClassifier(n_estimators=50, random_state=42)
    rf_type.fit(X_train, y_train_type)
    
    # Evaluate models
    y_pred_adj = dt_adjust.predict(X_test)
    y_pred_type = rf_type.predict(X_test)
    
    print("Adjustment decision accuracy:", accuracy_score(y_test_adj, y_pred_adj))
    print("Adjustment type accuracy:", accuracy_score(y_test_type, y_pred_type))
    print("\nAdjustment type classification report:")
    print(classification_report(y_test_type, y_pred_type))
    
    # Save models and scaler
    joblib.dump(dt_adjust, 'models/adjustment_decision_model.pkl')
    joblib.dump(rf_type, 'models/adjustment_type_model.pkl')
    joblib.dump(scaler, 'models/adjustment_scaler.pkl')
    
    print("Plan adjustment models saved.")
    return dt_adjust, rf_type, scaler

def test_models_with_sample_data(encoder, dt_diff, rf_sets, rf_reps, scaler, dt_adjust, rf_type):
    """Test the trained models with sample data to verify they work as expected"""
    print("\nTesting models with sample data:")
    
    # Test exercise recommendation models
    sample_patient = {
        'body_part': 'Knee',
        'pain_level': 8,
        'pain_location': 'Joint',
        'previous_injuries': 'ACL tear',
        'surgical_history': 'ACL reconstruction',
        'primary_goal': 'Improve range of motion'
    }
    
    # Prepare sample data
    sample_df = pd.DataFrame([sample_patient])
    
    # Encode categorical features
    categorical_features = ['body_part', 'pain_location', 'previous_injuries', 
                           'surgical_history', 'primary_goal']
    X_cat = pd.DataFrame(
        encoder.transform(sample_df[categorical_features]),
        columns=encoder.get_feature_names_out(categorical_features)
    )
    
    # Combine with numerical features
    X_num = sample_df[['pain_level']].reset_index(drop=True)
    X_processed = pd.concat([X_num, X_cat], axis=1)
    
    # Predict
    difficulty = dt_diff.predict(X_processed)[0]
    sets = rf_sets.predict(X_processed)[0]
    reps = rf_reps.predict(X_processed)[0]
    
    print(f"For a patient with {sample_patient['body_part']} injury and pain level {sample_patient['pain_level']}:")
    print(f"Recommended difficulty: {difficulty}")
    print(f"Recommended sets: {sets}")
    print(f"Recommended reps: {reps}")
    
    # Test plan adjustment models
    sample_progress = {
        'avg_pain': 8.5,
        'avg_adherence': 65.0,
        'avg_rating': 2.5
    }
    
    # Prepare sample data
    sample_df = pd.DataFrame([sample_progress])
    X_scaled = scaler.transform(sample_df)
    
    # Predict
    should_adjust = dt_adjust.predict(X_scaled)[0]
    adjustment_type = rf_type.predict(X_scaled)[0]
    
    print("\nFor progress with high pain and low adherence:")
    print(f"Should adjust plan: {should_adjust}")
    print(f"Recommended adjustment: {adjustment_type}")
    
    # Another test case
    sample_progress = {
        'avg_pain': 2.0,
        'avg_adherence': 95.0,
        'avg_rating': 4.5
    }
    
    # Prepare sample data
    sample_df = pd.DataFrame([sample_progress])
    X_scaled = scaler.transform(sample_df)
    
    # Predict
    should_adjust = dt_adjust.predict(X_scaled)[0]
    adjustment_type = rf_type.predict(X_scaled)[0]
    
    print("\nFor progress with low pain and high adherence:")
    print(f"Should adjust plan: {should_adjust}")
    print(f"Recommended adjustment: {adjustment_type}")

def main():
    """Main function to run the model training pipeline"""
    # Create models directory
    os.makedirs('models', exist_ok=True)
    
    # Load data
    patients, plans, progress_logs = load_data()
    
    # Prepare data for exercise recommendation
    exercise_df = prepare_data_for_exercise_recommendation(patients, plans)
    
    # Prepare data for plan adjustment
    adjustment_df = prepare_data_for_plan_adjustment(plans, progress_logs)
    
    # Train models
    dt_diff, rf_sets, rf_reps, encoder = train_exercise_recommendation_model(exercise_df)
    dt_adjust, rf_type, scaler = train_plan_adjustment_model(adjustment_df)
    
    # Test models
    test_models_with_sample_data(encoder, dt_diff, rf_sets, rf_reps, scaler, dt_adjust, rf_type)
    
    print("\nModel training complete. The models are ready for use in the application.")

if __name__ == "__main__":
    main()