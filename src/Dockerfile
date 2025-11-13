# Dockerfile for ML Inference on AKS
# Model files are downloaded by the workflow and copied during build
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies for inference
RUN pip install --no-cache-dir \
    scikit-learn==1.5.0 \
    pandas==2.2.0 \
    numpy==1.26.0 \
    joblib==1.4.0 \
    flask==3.0.0 \
    gunicorn==21.2.0 \
    prometheus-client==0.19.0

# Copy scoring script and model
COPY score.py .
COPY model/ ./model/

# Set environment variables
ENV MODEL_NAME=diabetes_classification \
    MODEL_VERSION=v1 \
    DEPLOYMENT_NAME=production \
    AZUREML_MODEL_FILE=/app/model/model.pkl \
    PYTHONUNBUFFERED=1 \
    WORKERS=4 \
    THREADS=2 \
    TIMEOUT=120 \
    PORT=5001

# Create Flask wrapper for the scoring script
RUN echo 'from flask import Flask, request, jsonify\n\
import score\n\
import logging\n\
\n\
app = Flask(__name__)\n\
logging.basicConfig(level=logging.INFO)\n\
logger = logging.getLogger(__name__)\n\
\n\
# Initialize model on startup\n\
try:\n\
    score.init()\n\
    logger.info("Model initialized successfully")\n\
except Exception as e:\n\
    logger.error(f"Failed to initialize model: {e}")\n\
    raise\n\
\n\
@app.route("/score", methods=["POST"])\n\
def predict():\n\
    try:\n\
        data = request.get_json()\n\
        result = score.run(data)\n\
        return jsonify(result)\n\
    except Exception as e:\n\
        return jsonify({"error": str(e)}), 500\n\
\n\
@app.route("/health", methods=["GET"])\n\
def health():\n\
    result, status_code = score.health()\n\
    return jsonify(result), status_code\n\
\n\
@app.route("/readiness", methods=["GET"])\n\
def readiness():\n\
    result, status_code = score.readiness()\n\
    return jsonify(result), status_code\n\
\n\
@app.route("/liveness", methods=["GET"])\n\
def liveness():\n\
    result, status_code = score.liveness()\n\
    return jsonify(result), status_code\n\
\n\
@app.route("/metrics", methods=["GET"])\n\
def metrics():\n\
    from flask import Response\n\
    data, status_code, headers = score.metrics()\n\
    return Response(data, status=status_code, headers=headers)\n\
\n\
if __name__ == "__main__":\n\
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", 5001)))' > app.py

# Expose port
EXPOSE 5001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:5001/health || exit 1

# Run with gunicorn for production
CMD ["sh", "-c", "gunicorn --bind 0.0.0.0:${PORT} --workers ${WORKERS} --threads ${THREADS} --timeout ${TIMEOUT} --access-logfile - --error-logfile - app:app"]
