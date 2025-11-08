## DEV edge learning profile (AKS + APIM + Front Door + Traffic Manager)

Purpose
- Enable the full path for realtime inference in DEV: AKS cluster for serving, API Management for governance, Front Door for global entry/WAF, and Traffic Manager for DNS-based routing/failover.
- Keep costs and complexity controlled (single small AKS node, public networking, minimal extras).

How to use
1) Copy the learning tfvars:
   - cp infrastructure/terraform.tfvars.dev-edge-learning infrastructure/terraform.tfvars
2) Edit values:
   - project_name, location, notification_email
3) Deploy:
   - terraform init
   - terraform plan -var-file=terraform.tfvars
   - terraform apply -var-file=terraform.tfvars
4) After deploy:
   - Get APIM gateway URL and/or Front Door endpoint hostname
   - Verify health probes in Traffic Manager and Front Door
   - Deploy your model to AKS or use the AKS ingress controller as an origin behind APIM/Front Door

Notes
- AKS is gated by `enable_aks_deployment` and will be created with 1 node (no autoscaling) to keep costs predictable.
- APIM/Front Door/Traffic Manager are enabled by flags in this profile. For private networking and WAF policies, adapt after you validate the basic flow.
- Other premium/tenant-scoped services (Power BI, SQL, Logic Apps, Communication Services) stay disabled here.

Caveats and costs
- Even with 1-node AKS, you will incur cost while the node is running. Delete or scale down when not in use.
- Front Door and APIM bill by usage and/or capacity; for learning runs, costs are typically small but non-zero.
- Keep log retention at 30 days for DEV.

Troubleshooting
- If Terraform reports resources already exist, run the import script (CI runs it automatically in this repo before plan).
- Ensure the CI/service principal has Storage Blob Data Contributor on the remote backend storage account and no state lock is present.
- Quotas/region: if APIM or Front Door SKUs fail in your region, pick a nearby region with capacity.

Next
- Wire the AKS service/ingress as an APIM backend and secure with a subscription key.
- Put Front Door in front of APIM for global entry + WAF.
- Add a smoke test step that calls the Front Door URL and validates response latency and shape.
