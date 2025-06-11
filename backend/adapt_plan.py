# adapt_plan.py - Plan Adaptation and Feedback Analysis Module
import numpy as np
import uuid
import os
import json
from datetime import datetime, timedelta
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

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
        self.data_dir = 'data'
        os.makedirs(self.data_dir, exist_ok=True)
    
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

    def store_feedback(self, feedback_data, analysis_result):
        """Store feedback data for future analysis"""
        try:
            feedback_id = str(uuid.uuid4())
            feedback_file = f"{self.data_dir}/feedback_{feedback_id}.json"
            
            with open(feedback_file, 'w') as f:
                json.dump({
                    'id': feedback_id,
                    'feedback': feedback_data,
                    'analysis': analysis_result,
                    'timestamp': datetime.now().isoformat()
                }, f, indent=2)
            
            return feedback_id
        except Exception as e:
            logger.error(f"Error storing feedback: {e}")
            return None


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


class MockDataGenerator:
    """Generates mock trend and insight data for API endpoints"""
    
    @staticmethod
    def get_feedback_trends(user_id, days_back=30):
        """Generate mock trend data based on typical rehabilitation patterns"""
        return {
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
    
    @staticmethod
    def get_exercise_insights(user_id, exercise_id):
        """Generate mock insights data for specific exercise"""
        return {
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
    
    @staticmethod
    def get_user_analytics(user_id, time_period=30):
        """Generate comprehensive analytics for a user"""
        return {
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


# Global instances
feedback_analyzer = FeedbackAnalyzer()
plan_optimizer = ExercisePlanOptimizer()
mock_data = MockDataGenerator()

# Public interface functions
def analyze_exercise_feedback(feedback_data):
    """Public interface to analyze exercise feedback"""
    analysis_result = feedback_analyzer.analyze_feedback(feedback_data)
    
    # Store feedback for future analysis
    feedback_id = feedback_analyzer.store_feedback(feedback_data, analysis_result)
    
    return {
        'status': 'success',
        'feedback_id': feedback_id,
        'analysis': analysis_result
    }

def optimize_plan_based_on_feedback(user_id, exercise_id, feedback_history):
    """Public interface to optimize exercise plan"""
    return plan_optimizer.optimize_exercise_plan(user_id, exercise_id, feedback_history)

def get_feedback_trends(user_id, days_back=30):
    """Public interface to get feedback trends"""
    trends = mock_data.get_feedback_trends(user_id, days_back)
    return {
        'status': 'success',
        'trends': trends,
        'user_id': user_id,
        'period_days': days_back
    }

def get_exercise_insights(user_id, exercise_id):
    """Public interface to get exercise insights"""
    insights = mock_data.get_exercise_insights(user_id, exercise_id)
    return {
        'status': 'success',
        'insights': insights,
        'exercise_id': exercise_id,
        'user_id': user_id
    }

def get_user_analytics(user_id, time_period=30):
    """Public interface to get user analytics"""
    analytics = mock_data.get_user_analytics(user_id, time_period)
    return {
        'status': 'success',
        'analytics': analytics,
        'user_id': user_id,
        'time_period_days': time_period,
        'generated_at': datetime.now().isoformat()
    }

def check_adaptation_health():
    """Check if adaptation services are ready"""
    return {
        'status': 'ok',
        'services': {
            'feedback_analyzer': 'available',
            'plan_optimizer': 'available',
            'mock_data_generator': 'available'
        },
        'data_directory': os.path.exists('data')
    }