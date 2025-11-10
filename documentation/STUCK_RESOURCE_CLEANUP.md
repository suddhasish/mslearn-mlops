## Handling stuck resource deletions (timeouts during terraform destroy)

### Problem
Azure Front Door, Traffic Manager, APIM, and AKS can timeout during `terraform destroy` due to long deletion times (10–45 minutes). GitHub Actions and local terminals may cancel after hitting default timeouts.

### Symptoms
- Error: `waiting for the deletion of Front Door Profile ... context deadline exceeded`
- Error: `context has been cancelled: StatusCode=200`
- Terraform destroy hangs or times out after 30–60 minutes

### Quick fix (manual cleanup)

Use the cleanup script to manually delete stuck resources:

```powershell
# Dry run (shows what would be deleted)
./deployment/cleanup-stuck-resources.ps1 -ResourceGroupName <your-rg> -All

# Delete Front Door only
./deployment/cleanup-stuck-resources.ps1 -ResourceGroupName <your-rg> -FrontDoor -Force

# Delete all long-running resources
./deployment/cleanup-stuck-resources.ps1 -ResourceGroupName <your-rg> -All -Force
```

After deletion completes (check Azure Portal), re-run:
```powershell
terraform destroy -auto-approve
```

Or remove from Terraform state if already gone:
```powershell
terraform state rm azurerm_cdn_frontdoor_profile.mlops
terraform state rm azurerm_traffic_manager_profile.mlops
terraform state rm azurerm_api_management.mlops
terraform state rm azurerm_kubernetes_cluster.mlops
```

### Prevention strategies

**Option 1: Increase workflow timeout**
- Add `timeout-minutes: 90` to destroy jobs in `.github/workflows/infrastructure-deploy.yml`

**Option 2: Use async destroy in CI**
- Delete long-running resources with `--no-wait` flag in CI
- Add a polling step to check status before marking job complete

**Option 3: Disable in dev**
- Set `enable_front_door = false`, `enable_traffic_manager = false`, `enable_api_management = false`, `enable_aks_deployment = false` in `terraform.tfvars.minimal`
- Only enable for learning/production when needed

**Option 4: Pre-delete with Azure CLI**
- Add a workflow step before `terraform destroy` to delete known slow resources:
  ```bash
  az cdn fd profile delete -g <rg> --profile-name <name> --yes --no-wait
  az aks delete -g <rg> --name <name> --yes --no-wait
  ```

### Resource deletion times (typical)
- Front Door: 15–30 minutes
- Traffic Manager: 2–5 minutes
- API Management: 30–45 minutes
- AKS: 10–20 minutes
- Most other resources: <5 minutes

### Troubleshooting

**Resource stuck in "Deleting" state for hours**
- Check Activity Log in Azure Portal for errors
- If soft-delete is enabled (Key Vault), purge manually: `az keyvault purge --name <name>`
- For Front Door, ensure all endpoints/routes removed before deleting profile

**Terraform state out of sync after manual deletion**
- Run `terraform refresh` to sync state with Azure
- Or use `terraform state rm <address>` to remove from state without touching Azure

**CI job cancelled mid-destroy**
- Resume locally: `terraform destroy -auto-approve`
- Check for partial deletions in Azure Portal; clean up manually if needed
