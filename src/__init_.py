import os
import json
import logging
import requests

import azure.functions as func

# Environment variables expected:
# GITHUB_TOKEN - a Personal Access Token with 'repo' and 'workflow' scopes (NOT the built-in GITHUB_TOKEN)
# REPO_OWNER - repository owner
# REPO_NAME - repository name
# WORKFLOW_FILE - workflow file name to trigger (example: .github/workflows/cd-deploy.yml)
# REF - branch or tag to dispatch the workflow on (example: main)

GITHUB_API = "https://api.github.com"

def trigger_workflow(model_name, model_version, aml_workspace, resource_group, subscription_id):
    token = os.getenv('GITHUB_TOKEN')
    owner = os.getenv('REPO_OWNER')
    repo = os.getenv('REPO_NAME')
    workflow_file = os.getenv('WORKFLOW_FILE', '.github/workflows/cd-deploy.yml')
    ref = os.getenv('REF', 'main')

    if not token or not owner or not repo:
        logging.error('GITHUB_TOKEN, REPO_OWNER and REPO_NAME must be set in function configuration')
        return False, 'Missing configuration'

    url = f"{GITHUB_API}/repos/{owner}/{repo}/actions/workflows/{workflow_file}/dispatches"
    headers = {
        'Authorization': f"token {token}",
        'Accept': 'application/vnd.github.v3+json'
    }
    payload = {
        'ref': ref,
        'inputs': {
            'model_name': model_name,
            'model_version': str(model_version),
            'aml_workspace': aml_workspace,
            'resource_group': resource_group,
            'subscription_id': subscription_id
        }
    }

    resp = requests.post(url, headers=headers, json=payload)
    if resp.status_code in (204, 201):
        return True, 'Workflow dispatched'
    else:
        logging.error('Failed to dispatch workflow: %s %s', resp.status_code, resp.text)
        return False, resp.text

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Azure Function received a request to trigger GitHub workflow')
    try:
        data = req.get_json()
    except ValueError:
        return func.HttpResponse('Invalid JSON', status_code=400)

    # Azure Event Grid sends events as an array; AML may wrap data differently.
    if isinstance(data, list) and len(data) > 0:
        event = data[0]
    else:
        event = data

    # Try to read a few common fields (adjust based on your AML event schema)
    try:
        model_name = event.get('data', {}).get('modelName') or event.get('data', {}).get('name') or os.getenv('DEFAULT_MODEL_NAME', 'best-model')
        model_version = event.get('data', {}).get('modelVersion') or event.get('data', {}).get('version') or os.getenv('DEFAULT_MODEL_VERSION', '1')
        aml_workspace = event.get('data', {}).get('workspaceName') or os.getenv('AML_WORKSPACE')
        resource_group = event.get('data', {}).get('resourceGroup') or os.getenv('RESOURCE_GROUP')
        subscription_id = event.get('data', {}).get('subscriptionId') or os.getenv('SUBSCRIPTION_ID')
    except Exception as e:
        logging.error('Failed to parse event: %s', e)
        return func.HttpResponse('Bad event payload', status_code=400)

    success, message = trigger_workflow(model_name, model_version, aml_workspace, resource_group, subscription_id)
    if success:
        return func.HttpResponse(message, status_code=202)
    else:
        return func.HttpResponse(str(message), status_code=500)
