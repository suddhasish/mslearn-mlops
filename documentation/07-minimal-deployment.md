## Minimal MVP deployment (train + inference endpoint)

This page describes the minimal set of resources you should enable to train a model and expose an inference endpoint while avoiding premium/quota resources.

Goals
- Keep only the essentials to train and serve: Azure ML Workspace, Storage Account, Key Vault, ACR (image registry), Azure ML compute (training and optionally inference), and minimal monitoring.
- Avoid services that incur extra cost or tenant-scoped permissions: Power BI, MSSQL, API Management, Front Door, Traffic Manager, Synapse, DevOps Function Apps, etc.

What to use
- For training: Azure ML compute (cluster) in the workspace. This repo contains example training under `src/model/train.py`.
- For inference (minimal): Use Azure ML managed endpoints (recommended) or a small AKS cluster if you need custom container orchestration.
  - Azure ML managed endpoints let you avoid AKS cost/ops for an MVP.

Quick checklist
1. Copy the minimal tfvars file:
   - cp infrastructure/terraform.tfvars.minimal infrastructure/terraform.tfvars
2. Edit `infrastructure/terraform.tfvars` (the copied file):
   - Set `notification_email` to your email.
   - Optionally set `project_name` and `location`.
3. Ensure GitHub Actions secrets are set for CI runs (if you plan to use CI):
   - `PROJECT_NAME` (recommended to match the tfvars project_name)
   - `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`
4. Ensure the service principal used by CI has access to the remote state storage account (Storage Blob Data Contributor) and that no stale locks exist.
5. Run in local dev (or let CI run):
   - terraform init
   - terraform plan -var-file=terraform.tfvars
   - terraform apply -var-file=terraform.tfvars

Notes and best practices
- The repo already uses feature flags (variables in `infrastructure/variables.tf`) to gate premium resources. The minimal tfvars file explicitly disables them.
- If you want a small AKS: set `enable_aks_deployment = true` in your tfvars and keep node counts very small (1-2) to control cost.
- For production or high-availability, enable private endpoints and consider API Management / Front Door behind WAF.

Next steps
- After a successful minimal deploy, run a test training job from `src/model/train.py` or via Azure ML SDK to validate compute and storage.
- Create a minimal inference deployment using Azure ML managed endpoints (preferred) or a small AKS/Container Instance.

Troubleshooting
- "Resource already exists" errors: run the import script `infrastructure/import-existing-resources.sh` (CI already runs this before plan if present).
- Backend authorization/lock issues: grant the CI SP `Storage Blob Data Contributor` on the backend storage account and clear any stale locks.

If you'd like, I can also:
- Add a GitHub Actions job that runs `terraform plan` with the `terraform.tfvars.minimal` automatically for pull requests.
- Remove (prune) the Terraform code for gated resources from the repo entirely (I recommend keeping them behind flags unless you want them permanently removed).
