# DEV Edge Learning Architecture (AKS, APIM, Front Door, Traffic Manager)

Below is a detailed architecture diagram for your DEV learning environment, showing how inference endpoints flow through AKS, APIM, Front Door, and Traffic Manager, with supporting Azure ML, Storage, Key Vault, and monitoring components.

## Diagram (Mermaid source)

```mermaid
flowchart TD
    subgraph User
      U1[Client / User]
    end
    subgraph Edge
      FD[Azure Front Door]
      TM[Traffic Manager]
    end
    subgraph API
      APIM[API Management]
    end
    subgraph Serving
      AKS[AKS Cluster]
      AML[Azure ML Workspace]
      EP[Managed Online Endpoint]
    end
    subgraph Data
      STG[Storage Account]
      KV[Key Vault]
    end
    subgraph Monitoring
      LA[Log Analytics]
      AI[App Insights]
    end

    U1 --> FD
    FD --> TM
    TM --> APIM
    APIM --> AKS
    APIM --> EP
    AKS -->|Model| AML
    EP -->|Model| AML
    AML --> STG
    AML --> KV
    AKS --> LA
    AKS --> AI
    EP --> LA
    EP --> AI
    APIM --> LA
    APIM --> AI
    FD --> LA
    FD --> AI

    classDef infra fill:#f9f,stroke:#333,stroke-width:2px;
    classDef monitor fill:#cff,stroke:#333,stroke-width:2px;
    classDef data fill:#fcf,stroke:#333,stroke-width:2px;
    classDef api fill:#ffc,stroke:#333,stroke-width:2px;
    classDef edge fill:#cff,stroke:#333,stroke-width:2px;
    classDef serving fill:#cfc,stroke:#333,stroke-width:2px;

    class FD,TM edge;
    class APIM api;
    class AKS,AML,EP serving;
    class STG,KV data;
    class LA,AI monitor;
```

## How to use
- View this diagram in VS Code markdown preview, or paste into https://mermaid.live for a rendered image.
- To export as PNG: use the Mermaid Live Editor or VS Code Mermaid extension.

## Component notes
- **Front Door**: Global entry, WAF, routes to Traffic Manager or APIM.
- **Traffic Manager**: DNS-based routing/failover, health probes.
- **API Management**: Auth, rate limiting, policies, developer portal.
- **AKS**: Custom model serving, ingress controller, microservices.
- **AML Managed Endpoint**: Direct managed serving (alternative to AKS for simple cases).
- **Azure ML Workspace**: Training, model registry, pipeline orchestration.
- **Storage Account**: Datasets, artifacts, model files.
- **Key Vault**: Secrets, keys, credentials.
- **Log Analytics / App Insights**: Monitoring, logs, metrics, alerts.

## Flow
- User requests enter via Front Door, routed by Traffic Manager to APIM, which authenticates and forwards to AKS or AML endpoint.
- Model serving in AKS or AML endpoint; logs/metrics sent to monitoring.
- Data and secrets accessed from Storage and Key Vault.

---
Edit this diagram as your architecture evolves. For production, add private endpoints, scale out AKS, and enable advanced APIM/Front Door policies.
