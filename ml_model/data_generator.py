import pandas as pd
import numpy as np
import json
import os
import random
from datetime import datetime, timedelta

# Set random seed for reproducibility
np.random.seed(42)

# Define the number of samples to generate
NUM_PATIENTS = 100
NUM_THERAPISTS = 10
PLANS_PER_PATIENT = 3
PROGRESS_LOGS_PER_PLAN = 10

# Create directory for the simulated data
os.makedirs('simulated_data', exist_ok=True)

# Helper functions for generating random data
def generate_patient_id():
    return f"patient_{random.randint(1000, 9999)}"

def generate_therapist_id():
    return f"therapist_{random.randint(1000, 9999)}"

def generate_plan_id():
    return f"plan_{random.randint(10000, 99999)}"

def generate_progress_id():
    return f"progress_{random.randint(10000, 99999)}"

def generate_email(user_type, user_id):
    domains = ['gmail.com', 'yahoo.com', 'outlook.com', 'hotmail.com', 'example.com']
    return f"{user_type}_{user_id}@{random.choice(domains)}"

def generate_name():
    first_names = ['James', 'Robert', 'John', 'Michael', 'David', 'William', 'Richard', 'Joseph', 'Thomas', 'Charles',
                  'Mary', 'Patricia', 'Jennifer', 'Linda', 'Elizabeth', 'Barbara', 'Susan', 'Jessica', 'Sarah', 'Karen']
    last_names = ['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez',
                 'Hernandez', 'Lopez', 'Gonzalez', 'Wilson', 'Anderson', 'Thomas', 'Taylor', 'Moore', 'Jackson', 'Martin']
    return f"{random.choice(first_names)} {random.choice(last_names)}"

def generate_body_part():
    return random.choice(['Knee', 'Shoulder', 'Ankle', 'Wrist', 'Elbow', 'Hip', 'Back', 'Neck'])

def generate_pain_level():
    return random.randint(1, 10)

def generate_previous_injuries():
    injuries = ['ACL tear', 'Meniscus tear', 'Rotator cuff injury', 'Ankle sprain', 'Tendonitis',
                'Fracture', 'Dislocation', 'Muscle strain', 'Ligament sprain', 'None']
    return random.choice(injuries)

def generate_surgical_history():
    surgeries = ['ACL reconstruction', 'Meniscus repair', 'Rotator cuff repair', 'Ankle ligament reconstruction',
                'Joint replacement', 'Fracture fixation', 'Arthroscopy', 'None']
    return random.choice(surgeries)

def generate_medications():
    medications = ['NSAIDs', 'Pain relievers', 'Muscle relaxants', 'Anti-inflammatory medication', 'None']
    return random.choice(medications)

def generate_allergies():
    allergies = ['Penicillin', 'Aspirin', 'NSAIDs', 'Latex', 'None']
    return random.choice(allergies)

def generate_rehab_goal():
    goals = ['Pain reduction', 'Improve range of motion', 'Increase strength', 'Return to sports',
            'Improve daily function', 'Prevent re-injury', 'Post-surgery recovery']
    return random.choice(goals)

def generate_exercises(body_part, goal, pain_level):
    """
    Generate a list of exercises based on body part, goal, and pain level
    """
    exercises = []
    exercise_count = random.randint(3, 6)
    
    knee_exercises = [
        {'name': 'Straight Leg Raises', 'description': 'Lie flat on your back and lift your leg straight up', 'bodyPart': 'Knee'},
        {'name': 'Hamstring Curls', 'description': 'Lie face down and bend your knee, bringing your heel toward your buttock', 'bodyPart': 'Knee'},
        {'name': 'Wall Squats', 'description': 'Stand with your back against a wall and bend your knees', 'bodyPart': 'Knee'},
        {'name': 'Step-Ups', 'description': 'Step up onto a platform with one leg, then the other', 'bodyPart': 'Knee'},
        {'name': 'Knee Extensions', 'description': 'Sit in a chair and straighten your knee', 'bodyPart': 'Knee'},
        {'name': 'Terminal Knee Extensions', 'description': 'Extend your knee against resistance', 'bodyPart': 'Knee'}
    ]
    
    shoulder_exercises = [
        {'name': 'Pendulum Exercise', 'description': 'Lean forward and let your arm hang, make small circles', 'bodyPart': 'Shoulder'},
        {'name': 'Wall Crawl', 'description': 'Face a wall and walk your fingers up the wall', 'bodyPart': 'Shoulder'},
        {'name': 'External Rotation', 'description': 'With elbow at side, rotate arm outward', 'bodyPart': 'Shoulder'},
        {'name': 'Internal Rotation', 'description': 'With elbow at side, rotate arm inward', 'bodyPart': 'Shoulder'},
        {'name': 'Shoulder Flexion', 'description': 'Raise your arm forward and upward', 'bodyPart': 'Shoulder'},
        {'name': 'Shoulder Abduction', 'description': 'Raise your arm out to the side', 'bodyPart': 'Shoulder'}
    ]
    
    ankle_exercises = [
        {'name': 'Ankle Pumps', 'description': 'Move your foot up and down', 'bodyPart': 'Ankle'},
        {'name': 'Ankle Circles', 'description': 'Rotate your ankle in circles', 'bodyPart': 'Ankle'},
        {'name': 'Heel Raises', 'description': 'Stand and rise up on your toes', 'bodyPart': 'Ankle'},
        {'name': 'Toe Raises', 'description': 'Stand and lift your toes off the ground', 'bodyPart': 'Ankle'},
        {'name': 'Resistance Band Eversion', 'description': 'Turn foot outward against resistance', 'bodyPart': 'Ankle'},
        {'name': 'Resistance Band Inversion', 'description': 'Turn foot inward against resistance', 'bodyPart': 'Ankle'}
    ]
    
    # Exercise pools for other body parts
    exercise_pools = {
        'Knee': knee_exercises,
        'Shoulder': shoulder_exercises,
        'Ankle': ankle_exercises,
        'Wrist': [{'name': f'Wrist Exercise {i}', 'description': f'Description for wrist exercise {i}', 'bodyPart': 'Wrist'} for i in range(1, 7)],
        'Elbow': [{'name': f'Elbow Exercise {i}', 'description': f'Description for elbow exercise {i}', 'bodyPart': 'Elbow'} for i in range(1, 7)],
        'Hip': [{'name': f'Hip Exercise {i}', 'description': f'Description for hip exercise {i}', 'bodyPart': 'Hip'} for i in range(1, 7)],
        'Back': [{'name': f'Back Exercise {i}', 'description': f'Description for back exercise {i}', 'bodyPart': 'Back'} for i in range(1, 7)],
        'Neck': [{'name': f'Neck Exercise {i}', 'description': f'Description for neck exercise {i}', 'bodyPart': 'Neck'} for i in range(1, 7)]
    }
    
    # Select appropriate difficulty level based on pain
    if pain_level > 7:
        difficulty = 'beginner'
    elif pain_level > 4:
        difficulty = 'intermediate'
    else:
        difficulty = 'advanced'
    
    # Select exercises from the appropriate pool
    pool = exercise_pools.get(body_part, exercise_pools['Knee'])  # Default to knee if body part not found
    selected_exercises = random.sample(pool, min(exercise_count, len(pool)))
    
    for i, ex in enumerate(selected_exercises):
        exercise_id = f"ex_{body_part.lower()}_{i+1}_{random.randint(1000, 9999)}"
        exercise = {
            'id': exercise_id,
            'name': ex['name'],
            'description': ex['description'],
            'bodyPart': ex['bodyPart'],
            'sets': random.randint(2, 4),
            'reps': random.randint(8, 15),
            'durationSeconds': random.randint(30, 90),
            'difficultyLevel': difficulty
        }
        exercises.append(exercise)
    
    return exercises

def generate_date_in_past(days_back=365):
    """Generate a random date within the last year"""
    days_ago = random.randint(0, days_back)
    return (datetime.now() - timedelta(days=days_ago)).isoformat()

def generate_random_patient():
    """Generate a random patient profile"""
    patient_id = generate_patient_id()
    body_part = generate_body_part()
    medical_history = {
        'previousInjuries': generate_previous_injuries(),
        'surgicalHistory': generate_surgical_history(),
        'medications': generate_medications(),
        'allergies': generate_allergies()
    }
    
    physical_condition = {
        'bodyPart': body_part,
        'painLevel': generate_pain_level(),
        'mobilityLimitations': 'Limited range of motion and strength',
        'painLocation': random.choice(['Joint', 'Muscle', 'Tendon', 'Ligament'])
    }
    
    rehab_goals = [generate_rehab_goal() for _ in range(random.randint(1, 3))]
    
    patient = {
        'id': patient_id,
        'name': generate_name(),
        'email': generate_email('patient', patient_id.split('_')[1]),
        'role': 'patient',
        'profileImageUrl': None,
        'medicalHistory': medical_history,
        'physicalCondition': physical_condition,
        'rehabilitationGoals': rehab_goals,
        'createdAt': generate_date_in_past()
    }
    
    return patient, patient_id

def generate_random_therapist():
    """Generate a random therapist profile"""
    therapist_id = generate_therapist_id()
    
    therapist = {
        'id': therapist_id,
        'name': generate_name(),
        'email': generate_email('therapist', therapist_id.split('_')[1]),
        'role': 'therapist',
        'profileImageUrl': None,
        'createdAt': generate_date_in_past()
    }
    
    return therapist, therapist_id

def generate_rehabilitation_plan(patient_id, therapist_id=None):
    """Generate a random rehabilitation plan"""
    plan_id = generate_plan_id()
    
    # Fetch patient data to use consistent body part and goals
    with open(f'simulated_data/users/{patient_id}.json', 'r') as f:
        patient = json.load(f)
    
    body_part = patient['physicalCondition']['bodyPart']
    pain_level = patient['physicalCondition']['painLevel']
    
    goals = {}
    if patient['rehabilitationGoals']:
        goals['primary'] = patient['rehabilitationGoals'][0]
        goals['bodyPart'] = body_part
        if pain_level > 7:
            goals['painReduction'] = 'high'
        elif pain_level > 4:
            goals['painReduction'] = 'medium'
        else:
            goals['painReduction'] = 'low'
    
    # Generate exercises
    exercises = generate_exercises(body_part, goals.get('primary', 'Pain reduction'), pain_level)
    
    # Generate random dates
    start_date = datetime.fromisoformat(patient['createdAt'].replace('Z', ''))
    start_date = start_date + timedelta(days=random.randint(1, 30))
    
    plan = {
        'id': plan_id,
        'userId': patient_id,
        'therapistId': therapist_id,
        'title': f"{body_part} Rehabilitation Plan",
        'description': f"Personalized rehabilitation plan for {body_part} recovery",
        'exercises': exercises,
        'startDate': start_date.isoformat(),
        'endDate': None,
        'status': random.choice(['active', 'completed', 'paused']),
        'goals': goals,
        'lastUpdated': start_date.isoformat(),
        'isDynamicallyAdjusted': random.choice([True, False])
    }
    
    return plan, plan_id

def generate_progress_log(patient_id, plan_id):
    """Generate a random progress log for a plan"""
    progress_id = generate_progress_id()
    
    # Load plan to get exercises
    with open(f'simulated_data/plans/{plan_id}.json', 'r') as f:
        plan = json.load(f)
    
    # Generate log date after plan start date
    plan_start = datetime.fromisoformat(plan['startDate'].replace('Z', ''))
    log_date = plan_start + timedelta(days=random.randint(1, 60))
    
    # Generate exercise logs
    exercise_logs = []
    for exercise in plan['exercises']:
        # Some exercises might be skipped
        if random.random() < 0.9:  # 90% chance of doing each exercise
            sets_completed = random.randint(1, exercise['sets'])
            reps_completed = random.randint(1, exercise['reps'])
            
            exercise_log = {
                'exerciseId': exercise['id'],
                'exerciseName': exercise['name'],
                'setsCompleted': sets_completed,
                'repsCompleted': reps_completed,
                'durationSeconds': exercise['durationSeconds'],
                'painLevel': random.randint(1, 10),
                'notes': random.choice([None, 'Felt good', 'Too challenging', 'Getting easier', 'Need to modify'])
            }
            exercise_logs.append(exercise_log)
    
    # Calculate adherence
    adherence = 0
    if plan['exercises']:
        total_sets_planned = sum(ex['sets'] for ex in plan['exercises'])
        total_sets_completed = sum(log['setsCompleted'] for log in exercise_logs)
        adherence = min(int((total_sets_completed / total_sets_planned) * 100), 100)
    
    # Generate metrics
    body_part = plan['goals'].get('bodyPart', 'General')
    metrics = {
        f"{body_part.lower()}_rom": random.randint(60, 180),  # Range of motion (degrees)
        f"{body_part.lower()}_strength": random.randint(3, 10)  # Strength (1-10 scale)
    }
    
    progress_log = {
        'id': progress_id,
        'userId': patient_id,
        'planId': plan_id,
        'date': log_date.isoformat(),
        'exerciseLogs': exercise_logs,
        'metrics': metrics,
        'feedback': random.choice([
            None,
            'Feeling improvement in range of motion',
            'Still experiencing pain during certain movements',
            'Exercises are getting easier to perform',
            'Need modifications for some exercises'
        ]),
        'overallRating': random.randint(1, 5),
        'adherencePercentage': adherence
    }
    
    return progress_log, progress_id

# Generate and save the data
def generate_all_data():
    """Generate all simulated data"""
    print("Generating simulated data...")
    
    # Create directories
    os.makedirs('simulated_data/users', exist_ok=True)
    os.makedirs('simulated_data/plans', exist_ok=True)
    os.makedirs('simulated_data/progress', exist_ok=True)
    
    # Generate patients
    patient_ids = []
    for _ in range(NUM_PATIENTS):
        patient, patient_id = generate_random_patient()
        patient_ids.append(patient_id)
        
        # Save patient data
        with open(f'simulated_data/users/{patient_id}.json', 'w') as f:
            json.dump(patient, f, indent=2)
    
    # Generate therapists
    therapist_ids = []
    for _ in range(NUM_THERAPISTS):
        therapist, therapist_id = generate_random_therapist()
        therapist_ids.append(therapist_id)
        
        # Save therapist data
        with open(f'simulated_data/users/{therapist_id}.json', 'w') as f:
            json.dump(therapist, f, indent=2)
    
    # Generate rehabilitation plans
    plan_ids = []
    for patient_id in patient_ids:
        for _ in range(random.randint(1, PLANS_PER_PATIENT)):
            # Randomly assign a therapist or None
            therapist_id = random.choice([None] + therapist_ids)
            plan, plan_id = generate_rehabilitation_plan(patient_id, therapist_id)
            plan_ids.append((patient_id, plan_id))
            
            # Save plan data
            with open(f'simulated_data/plans/{plan_id}.json', 'w') as f:
                json.dump(plan, f, indent=2)
    
    # Generate progress logs
    for patient_id, plan_id in plan_ids:
        for _ in range(random.randint(0, PROGRESS_LOGS_PER_PLAN)):
            progress, progress_id = generate_progress_log(patient_id, plan_id)
            
            # Save progress data
            with open(f'simulated_data/progress/{progress_id}.json', 'w') as f:
                json.dump(progress, f, indent=2)
    
    print(f"Generated {len(patient_ids)} patients")
    print(f"Generated {len(therapist_ids)} therapists")
    print(f"Generated {len(plan_ids)} rehabilitation plans")
    print("Data generation complete!")

if __name__ == "__main__":
    generate_all_data()