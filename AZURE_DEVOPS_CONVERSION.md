# Azure DevOps Pipeline Conversion

## 🎯 Overview

This repository contains both **GitHub Actions** workflows and **Azure DevOps** pipelines for MLOps continuous deployment.

The GitHub Actions workflow (`.github/workflows/cd-deploy.yml`) has been converted to an Azure DevOps pipeline (`azure-pipelines/cd-deploy.yml`) with complete feature parity.

## 📍 Quick Navigation

### GitHub Actions (Original)
- 📁 **Location**: `.github/workflows/cd-deploy.yml`
- 📊 **Size**: 979 lines
- 🔧 **Trigger**: `workflow_dispatch` (manual)
- ⚙️ **Authentication**: `AZURE_CREDENTIALS` secret

### Azure DevOps (New)
- 📁 **Location**: `azure-pipelines/cd-deploy.yml`
- 📊 **Size**: 1,299 lines
- 🔧 **Trigger**: Manual with parameters
- ⚙️ **Authentication**: Service connection

## 🚀 Getting Started with Azure DevOps

### Quick Start (15 minutes)
👉 **Follow**: [`azure-pipelines/QUICKSTART.md`](azure-pipelines/QUICKSTART.md)

### Complete Documentation
👉 **Read**: [`azure-pipelines/README.md`](azure-pipelines/README.md)

### Migration Guide
👉 **Use**: [`azure-pipelines/MIGRATION_CHECKLIST.md`](azure-pipelines/MIGRATION_CHECKLIST.md)

### Technical Details
👉 **Review**: [`azure-pipelines/CONVERSION_NOTES.md`](azure-pipelines/CONVERSION_NOTES.md)

## 📊 Comparison

### High-Level Comparison

| Feature | GitHub Actions | Azure DevOps |
|---------|---------------|--------------|
| **Workflow File** | `.github/workflows/cd-deploy.yml` | `azure-pipelines/cd-deploy.yml` |
| **Lines of Code** | 979 | 1,299 |
| **Stages/Jobs** | 6 jobs | 6 stages |
| **Manual Trigger** | ✅ `workflow_dispatch` | ✅ Parameters |
| **Parameters** | 8 inputs | 8 parameters |
| **Authentication** | Secret-based | Service connection |
| **Approval Gates** | Environment protection | Explicit approval stage |
| **Staging Deploy** | ✅ Managed Online Endpoint | ✅ Managed Online Endpoint |
| **Production Deploy** | ✅ Blue/Green | ✅ Blue/Green |
| **Traffic Rollout** | ✅ 10% → 50% → 100% | ✅ 10% → 50% → 100% |
| **Auto Rollback** | ✅ On failure | ✅ On failure |
| **Health Checks** | ✅ Yes | ✅ Yes |
| **Smoke Tests** | ✅ Yes | ✅ Yes |
| **Documentation** | Inline comments | 50KB+ documentation |

### Syntax Comparison

| Concept | GitHub Actions | Azure DevOps |
|---------|----------------|--------------|
| **Trigger** | `on: workflow_dispatch:` | `trigger: none` + `parameters:` |
| **Authentication** | `azure/login@v2` + secret | `AzureCLI@2` + service connection |
| **Dependencies** | `needs: job-name` | `dependsOn: StageName` |
| **Conditionals** | `if: success()` | `condition: succeeded()` |
| **Set Output** | `echo "var=val" >> $GITHUB_OUTPUT` | `echo "##vso[task.setvariable]"` |
| **Reference Output** | `${{ needs.job.outputs.var }}` | `$[ stageDependencies.Stage.Job.outputs['Task.var'] ]` |
| **Mask Secret** | `echo "::add-mask::$SECRET"` | `echo "##vso[task.setvariable;issecret=true]"` |
| **Job Summary** | `echo "text" >> $GITHUB_STEP_SUMMARY` | `echo "text"` |
| **Environment** | `environment: name:` | `deployment:` + `environment:` |

## 🏗️ Pipeline Architecture

### Both Platforms Implement

```
┌─────────────────────────────────────────────────────────┐
│  Stage 1: Resolve Inputs                                │
│  • Generate deployment ID                               │
│  • Resolve infrastructure (dev/prod)                    │
│  • Validate parameters                                  │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  Stage 2: Deploy to Staging                             │
│  • Create managed online endpoint                       │
│  • Deploy model                                         │
│  • Run health checks                                    │
│  • Run endpoint tests                                   │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  Stage 3: Prepare Production                            │
│  • Create production endpoint                           │
│  • Create BLUE deployment (first-time)                  │
│  • Create GREEN deployment (new version)                │
│  • Test GREEN in isolation (0% traffic)                 │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  Stage 4: Production Approval                           │
│  • Manual intervention required                         │
│  • Display rollout plan                                 │
│  • Await human approval                                 │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  Stage 5: Gradual Rollout                               │
│  • Phase 1: 10% → GREEN (smoke test)                    │
│  • Phase 2: 50% → GREEN (smoke test)                    │
│  • Phase 3: 100% → GREEN (smoke test)                   │
│  • Auto rollback on any failure                         │
│  • Scale down BLUE (cost optimization)                  │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  Stage 6: Post-Deployment Validation                    │
│  • Verify 100% traffic on GREEN                         │
│  • Log deployment metrics                               │
│  • Success notification                                 │
└─────────────────────────────────────────────────────────┘
```

## 📦 File Structure

### GitHub Actions
```
.github/workflows/
└── cd-deploy.yml          # Complete workflow (979 lines)
```

### Azure DevOps
```
azure-pipelines/
├── cd-deploy.yml                   # Main pipeline (1,299 lines)
├── templates/
│   └── azure-ml-setup.yml          # Reusable template (31 lines)
├── README.md                       # Complete docs (513 lines, 16KB)
├── QUICKSTART.md                   # Quick start (327 lines, 10KB)
├── CONVERSION_NOTES.md             # Technical details (506 lines, 14KB)
└── MIGRATION_CHECKLIST.md          # Migration guide (313 lines, 10KB)

scripts/
└── test_endpoint.py                # Endpoint testing (159 lines, 5KB)
```

## 🎯 Use Cases

### When to Use GitHub Actions
- ✅ Your team is already using GitHub for source control
- ✅ You prefer GitHub's native integration
- ✅ Simpler setup for GitHub-centric workflows
- ✅ Existing GitHub Actions expertise

### When to Use Azure DevOps
- ✅ Your organization uses Azure DevOps for other projects
- ✅ Need more granular approval controls
- ✅ Want explicit stage-based visualization
- ✅ Prefer Azure-native tooling
- ✅ Need richer deployment patterns
- ✅ Want more detailed deployment tracking

## 🔧 Prerequisites

### GitHub Actions
1. GitHub repository
2. Azure credentials (service principal JSON)
3. Repository secret: `AZURE_CREDENTIALS`
4. GitHub environments: `staging`, `production`

### Azure DevOps
1. Azure DevOps project
2. Service connection: `azure-mlops-service-connection`
3. Variable group: `mlops-infrastructure`
4. Environments: `staging`, `production-approval`, `production`

## 📚 Documentation Index

| Document | Purpose | Size |
|----------|---------|------|
| [`QUICKSTART.md`](azure-pipelines/QUICKSTART.md) | 15-minute setup guide | 10KB |
| [`README.md`](azure-pipelines/README.md) | Complete documentation | 16KB |
| [`CONVERSION_NOTES.md`](azure-pipelines/CONVERSION_NOTES.md) | Technical details | 14KB |
| [`MIGRATION_CHECKLIST.md`](azure-pipelines/MIGRATION_CHECKLIST.md) | Migration steps | 10KB |

## ✅ Validation Status

All pipelines have been:
- ✅ Syntax validated (YAML)
- ✅ Logic verified (stage dependencies)
- ✅ Features confirmed (all 10 acceptance criteria)
- ✅ Documentation complete (4 guides)
- ✅ Ready for production use

## 🚦 Getting Started

### For GitHub Actions Users
1. Continue using `.github/workflows/cd-deploy.yml`
2. No action required - everything works as before

### For Azure DevOps Users
1. **Quick Start**: Follow [`azure-pipelines/QUICKSTART.md`](azure-pipelines/QUICKSTART.md) (15 minutes)
2. **Full Setup**: Read [`azure-pipelines/README.md`](azure-pipelines/README.md)
3. **Migration**: Use [`azure-pipelines/MIGRATION_CHECKLIST.md`](azure-pipelines/MIGRATION_CHECKLIST.md)

## 💡 Key Benefits of Azure DevOps Version

1. **Better Visibility**: Explicit stages show up clearly in UI
2. **Richer Approvals**: More control over who can approve
3. **Native Deployment Jobs**: Better support for deployment patterns
4. **Comprehensive Docs**: 50KB+ of documentation and guides
5. **Reusable Templates**: DRY principle for common tasks
6. **Stage Dependencies**: Explicit data flow between stages

## 🤝 Support

### GitHub Actions Support
- Workflow file: `.github/workflows/cd-deploy.yml`
- GitHub documentation
- GitHub community

### Azure DevOps Support
- Pipeline documentation: [`azure-pipelines/README.md`](azure-pipelines/README.md)
- Quick start: [`azure-pipelines/QUICKSTART.md`](azure-pipelines/QUICKSTART.md)
- Troubleshooting: See README.md
- Technical details: [`azure-pipelines/CONVERSION_NOTES.md`](azure-pipelines/CONVERSION_NOTES.md)

## 📈 Statistics

| Metric | GitHub Actions | Azure DevOps |
|--------|----------------|--------------|
| **Pipeline File** | 979 lines | 1,299 lines |
| **Documentation** | Inline comments | 1,659 lines |
| **Total Code** | 979 lines | 2,945 lines |
| **Guides** | N/A | 4 documents |
| **Templates** | 0 | 1 |
| **Scripts** | 0 | 1 (test_endpoint.py) |

## 🎉 Summary

Both platforms are **production-ready** and **fully functional**. Choose the one that best fits your team's workflow and tooling preferences.

The Azure DevOps version includes comprehensive documentation, migration guides, and best practices to help you get started quickly and confidently.

---

**Last Updated**: 2024  
**Conversion Status**: ✅ Complete  
**Production Ready**: ✅ Yes  
**Documentation**: ✅ Comprehensive
