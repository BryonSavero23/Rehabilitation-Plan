# app.py - Main Flask Application (Modularized)
from flask import Flask, request, jsonify
import os
from datetime import datetime
from flask_cors import CORS
import logging

# Import our custom modules
import generate_plan
import adapt_plan

app = Flask(__name__)
CORS(app)

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# API routes - Plan Generation
@app.route('/api/generate_plan', methods=['POST'])
def api_generate_plan():
    try:
        print("Received request")
        print(request.json) 
        rehab_data = request.json
        plan = generate_plan.generate_rehabilitation_plan(rehab_data)
        return jsonify(plan)
    except Exception as e:
        print(f"Error in /generate_plan: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/model_metrics', methods=['GET'])
def get_model_metrics():
    try:
        metrics = generate_plan.get_plan_model_metrics()
        return jsonify(metrics)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/retrain_models', methods=['POST'])
def retrain_models():
    try:
        encoder, difficulty_model, sets_model, reps_model, metrics = generate_plan.retrain_plan_models()
        return jsonify({
            'status': 'success',
            'message': 'Models retrained successfully',
            'metrics': metrics
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# API routes - Feedback Analysis and Plan Adaptation
@app.route('/api/analyze_feedback', methods=['POST'])
def analyze_feedback():
    """Analyze exercise feedback and provide recommendations"""
    try:
        data = request.json
        feedback_data = data.get('feedback', {})
        
        logger.info(f"Analyzing feedback for exercise: {feedback_data.get('exerciseName')}")
        
        # Analyze the feedback using our module
        result = adapt_plan.analyze_exercise_feedback(feedback_data)
        return jsonify(result)
        
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
        
        # Optimize using our module
        result = adapt_plan.optimize_plan_based_on_feedback(user_id, exercise_id, feedback_history)
        return jsonify(result)
        
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
        
        result = adapt_plan.get_feedback_trends(user_id, days_back)
        return jsonify(result)
        
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
        
        result = adapt_plan.get_exercise_insights(user_id, exercise_id)
        return jsonify(result)
        
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
        
        result = adapt_plan.get_user_analytics(user_id, time_period)
        return jsonify(result)
        
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
        
        # Generate the actual plan using our module
        plan = generate_plan.generate_rehabilitation_plan(rehab_data)
        
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

# Health check endpoint
@app.route('/api/health', methods=['GET'])
def health_check():
    plan_health = generate_plan.check_plan_generator_health()
    adaptation_health = adapt_plan.check_adaptation_health()
    
    return jsonify({
        'status': 'ok',
        'timestamp': datetime.now().isoformat(),
        'services': {
            'plan_generation': plan_health['status'],
            'feedback_analyzer': adaptation_health['services']['feedback_analyzer'],
            'plan_optimizer': adaptation_health['services']['plan_optimizer']
        },
        'modules': {
            'generate_plan': plan_health,
            'adapt_plan': adaptation_health
        }
    })

# Initialize modules on startup
def initialize():
    try:
        print("Initializing plan generation module...")
        generate_plan.initialize_plan_generator()
        print("Plan generation module initialized successfully")
        
        print("Adaptation module ready")
        print("All modules initialized successfully")
    except Exception as e:
        print(f"Error initializing modules: {e}")

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
    print("✅ Modular architecture")
    
    port = int(os.environ.get('PORT', 5000))
    app.run(debug=False, host='0.0.0.0', port=port)