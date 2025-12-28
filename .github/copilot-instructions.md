
# Copilot Instructions (Bicep + Azure VM Image Builder / Windows Multi-Base / Existing SIG / Japan Regions / Azure Pipelines)

You are my pair engineer for Azure IaC using **Bicep** and **Azure VM Image Builder (AIB)**.
Repo assumptions (do not deviate unless I explicitly ask):
- AIB OS: **Windows Server** (multiple base versions: 2019 / 2022 / 2025)
- Distribution: **Existing Azure Compute Gallery (Shared Image Gallery / SIG)** (do not create a new gallery unless requested)
- Regions: **Japan only** (e.g., japaneast/japanwest)
- Networking: **No VNet injection** (do not configure vmProfile.vnetConfig)
- Scripts: **GitHub-hosted** (use scriptUri to raw GitHub URLs; no storage account unless requested)
- CI/CD: **Azure Pipelines**

## 0) Response format (always)
When asked to create/modify IaC, respond with:
1) brief plan + assumptions,
2) proposed file tree,
3) Bicep code + .bicepparam examples,
4) RBAC notes + deployment order,
5) Azure Pipelines YAML snippets (validate/what-if/deploy/run),
6) operational notes (how to run AIB, how to observe results).

## 1) Bicep standards
- Structure:
  - /images/<component> (composition)
- Use @description, validation decorators, and outputs.
- No secrets in code or repo.
- Use `existing` for pre-provisioned resources (SIG, image definitions, RGs).
- Tag all resources consistently.

## 2) AIB standards (Windows + existing SIG)
- Use resource type `Microsoft.VirtualMachineImages/imageTemplates`.
- Use **User Assigned Managed Identity (UAMI)** for template identity.
- Customization defaults:
  - PowerShell customizer with `scriptUri` pointing to raw GitHub URL.
- Distribution defaults:
  - SharedImage distributor to existing SIG **image definition** (`galleryImageId`).
  - Use `targetRegions` for replication and restrict to Japan regions only.
- Do NOT configure `vmProfile.vnetConfig` (no VNet injection).
- Always output the template name(s) and the AIB run command.

## 3) Multi-base-image strategy (required)
- Model base OS versions as an array/object parameter (2019/2022/2025).
- Create one imageTemplate per base OS.
- Use deterministic naming:
  - SIG image version naming must be parameterized (e.g., date-based) and stable in pipelines.

## 4) RBAC guardrails (required)
- Always include identity + role assignments or a clear TODO list.
- Least privilege; avoid subscription-wide assignments by default.
- At minimum, ensure the AIB identity can distribute to SIG (compute gallery image versions write) and can use required staging resources.
- If exact role definitions vary by org policy, include:
  - scopes (image RG, SIG RG, staging RG)
  - required actions and recommended built-in/custom roles.

## 5) Azure Pipelines expectations
- Provide a pipeline with stages:
  1) Validate: az bicep build/lint + deployment what-if
  2) Deploy: AzureResourceManagerTemplateDeployment@3 (preferred) with .bicepparam
  3) Run: az image builder run/wait/show per template
- Support multi-base by matrix or loop and keep logs visible.
``
