"""
Scoring script for Azure ML Managed Online Endpoints.
This script is optimized for Azure ML's managed endpoint environment.
"""
import os
import json
import logging
import joblib
import numpy as np

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Global variables
model = None

def init():
    """
    Initialize the model. Called once when the deployment starts.
    Azure ML automatically downloads the model and sets AZUREML_MODEL_DIR.
    """
    global model
    
    try:
        # Azure ML sets this environment variable to the model directory
        model_dir = os.getenv("AZUREML_MODEL_DIR")
        
        if not model_dir:
            raise ValueError("AZUREML_MODEL_DIR environment variable not set")
        
        logger.info(f"Loading model from: {model_dir}")
        
        # Find the model file (usually .pkl or .joblib)
        model_files = []
        for root, dirs, files in os.walk(model_dir):
            for file in files:
                if file.endswith(('.pkl', '.joblib', '.model')):
                    model_files.append(os.path.join(root, file))
        
        if not model_files:
            raise FileNotFoundError(f"No model file found in {model_dir}")
        
        model_path = model_files[0]  # Use first model file found
        logger.info(f"Loading model from: {model_path}")
        
        model = joblib.load(model_path)
        logger.info("Model loaded successfully")
        
    except Exception as e:
        logger.error(f"Error initializing model: {str(e)}")
        raise

def run(raw_data):
    """
    Make predictions on input data.
    
    Args:
        raw_data: JSON string containing input data
        
    Returns:
        JSON string with predictions
    """
    global model
    
    try:
        # Parse input data
        data = json.loads(raw_data)
        logger.info(f"Received request with data: {data}")
        
        # Extract input features
        # Support multiple input formats
        if "input_data" in data:
            input_array = np.array(data["input_data"])
        elif "data" in data:
            input_array = np.array(data["data"])
        elif isinstance(data, list):
            input_array = np.array(data)
        else:
            raise ValueError(f"Unsupported input format. Use 'input_data' or 'data' key, or send a list directly.")
        
        # Ensure 2D array
        if input_array.ndim == 1:
            input_array = input_array.reshape(1, -1)
        
        logger.info(f"Input shape: {input_array.shape}")
        
        # Make prediction
        predictions = model.predict(input_array)
        
        # Format response
        result = {
            "predictions": predictions.tolist()
        }
        
        # Add probabilities if classifier
        if hasattr(model, "predict_proba"):
            probabilities = model.predict_proba(input_array)
            result["probabilities"] = probabilities.tolist()
        
        logger.info(f"Predictions: {predictions.tolist()}")
        
        return json.dumps(result)
        
    except Exception as e:
        error_msg = f"Error during prediction: {str(e)}"
        logger.error(error_msg)
        return json.dumps({"error": error_msg})
