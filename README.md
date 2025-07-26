# Azure Policy as Code - Phase 1 Implementation:

## Project Overview

This project implements Azure Policy as Code to enforce region restrictions using Terraform and GitHub Actions CI/CD. The policy restricts resource creation to only the 'East US' region and is automatically deployed when pull requests are merged to the main branch.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Setup Instructions](#setup-instructions)
- [Implementation Details](#implementation-details)
- [CI/CD Workflow](#cicd-workflow)
- [Testing the Implementation](#testing-the-implementation)
- [Verification Steps](#verification-steps)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌───────────────────┐
│   Developer     │    │   GitHub Repo    │    │   Azure Portal    │
│                 │    │                  │    │                   │
│ Feature Branch  │───▶│  Pull Request    │───▶│   Policy Applied  │
│                 │    │                  │    │                   │
│ main.tf         │    │  GitHub Actions  │    │ East US Only      │
│ policy.json     │    │  (CI/CD)         │    │ Enforcement       │
└─────────────────┘    └──────────────────┘    └───────────────────┘
```

### Workflow Flow:
1. **Development**: Developer creates policy definition and Terraform code on feature branch
2. **Validation**: Pull Request triggers GitHub Actions for validation (terraform validate, plan)
3. **Deployment**: Merge to main branch automatically deploys policy to Azure subscription
4. **Enforcement**: Policy immediately begins enforcing East US region restriction

## Prerequisites

### Azure Requirements
- Azure Subscription with sufficient permissions
- Service Principal with the following roles:
  - **Resource Policy Contributor** (to create/manage policy definitions)
  - **Contributor** (to assign policies to subscription)

### Development Tools
- Git
- GitHub account
- Azure CLI (for initial setup)
- Terraform >= 1.6.6
- Code editor (VS Code recommended)

### Knowledge Prerequisites
- Basic understanding of Azure Policy
- Terraform fundamentals
- GitHub Actions basics
- JSON syntax

## Project Structure

```
azure-policy-as-code/
├── .github/
│   └── workflows/
│       └── deploy-policy.yml          # CI/CD workflow
├── terraform/
│   ├── main.tf                        # Terraform configuration
│   ├── provider.tf                    # Azure provider configuration
│   └── variables.tf                   # Variable definitions (optional)
├── policy/
│   └── allow-only-eastus.json         # Azure Policy definition
├── README.md                          # This file
└── .gitignore                         # Git ignore file
```

## Setup Instructions

### Step 1: Create Azure Service Principal

```bash
# Login to Azure
az login

# Create service principal
az ad sp create-for-rbac --name "policy-as-code-sp" --role "Contributor" --scopes "/subscriptions/{your-subscription-id}"

# Note the output - you'll need these values:
# - appId (ARM_CLIENT_ID)
# - password (ARM_CLIENT_SECRET)
# - tenant (ARM_TENANT_ID)
```

### Step 2: Assign Required Permissions

```bash
# Assign Resource Policy Contributor role
az role assignment create \
  --assignee "{service-principal-app-id}" \
  --role "Resource Policy Contributor" \
  --scope "/subscriptions/{your-subscription-id}"
```

### Step 3: Configure GitHub Repository

1. **Create repository secrets** (Settings → Secrets and variables → Actions):
   - `ARM_CLIENT_ID`: Service Principal Application ID
   - `ARM_CLIENT_SECRET`: Service Principal Password
   - `ARM_SUBSCRIPTION_ID`: Your Azure Subscription ID
   - `ARM_TENANT_ID`: Your Azure Tenant ID

### Step 4: Create Project Files

## Implementation Details

### 1. Azure Policy Definition (`policy/allow-only-eastus.json`)

```json
{
  "if": {
    "field": "location",
    "notEquals": "eastus"
  },
  "then": {
    "effect": "deny"
  }
}
```

**Policy Logic:**
- **Condition**: If resource location is NOT equal to "eastus"
- **Action**: Deny the resource creation
- **Effect**: Prevents deployment of resources outside East US region

### 2. Terraform Configuration (`terraform/main.tf`)

```hcl
# Get current Azure context (subscription info)
data "azurerm_client_config" "current" {}

# Create custom Azure Policy definition
resource "azurerm_policy_definition" "allow_only_eastus" {
  name         = "allow-only-eastus"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Allow Only East US Region"
  description  = "Only East US region is allowed"
  policy_rule  = file("${path.module}/../policy/allow-only-eastus.json")
}

# Assign policy to subscription
resource "azurerm_subscription_policy_assignment" "assign_policy" {
  name                 = "enforce-eastus"
  display_name         = "Enforce East US Only"
  policy_definition_id = azurerm_policy_definition.allow_only_eastus.id
  subscription_id      = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
}
```

### 3. Azure Provider Configuration (`terraform/provider.tf`)

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}
```

## CI/CD Workflow

### GitHub Actions Workflow (`.github/workflows/deploy-policy.yml`)

```yaml
name: Deploy Azure Policy

on:
  # Trigger on pull requests for validation
  pull_request:
    branches:
      - main
  
  # Trigger on merge to main for deployment
  push:
    branches:
      - main

jobs:
  # Validation job for pull requests
  validate:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.6.6

      - name: Terraform Init
        working-directory: terraform
        run: terraform init
        env:
          ARM_CLIENT_ID: ${{ secrets.ARM_CLIENT_ID }}
          ARM_CLIENT_SECRET: ${{ secrets.ARM_CLIENT_SECRET }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.ARM_SUBSCRIPTION_ID }}
          ARM_TENANT_ID: ${{ secrets.ARM_TENANT_ID }}

      - name: Terraform Validate
        working-directory: terraform
        run: terraform validate

      - name: Terraform Plan
        working-directory: terraform
        run: terraform plan -input=false
        env:
          ARM_CLIENT_ID: ${{ secrets.ARM_CLIENT_ID }}
          ARM_CLIENT_SECRET: ${{ secrets.ARM_CLIENT_SECRET }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.ARM_SUBSCRIPTION_ID }}
          ARM_TENANT_ID: ${{ secrets.ARM_TENANT_ID }}

  # Deployment job for merged PRs
  deploy:
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.6.6

      - name: Terraform Init
        working-directory: terraform
        run: terraform init
        env:
          ARM_CLIENT_ID: ${{ secrets.ARM_CLIENT_ID }}
          ARM_CLIENT_SECRET: ${{ secrets.ARM_CLIENT_SECRET }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.ARM_SUBSCRIPTION_ID }}
          ARM_TENANT_ID: ${{ secrets.ARM_TENANT_ID }}

      - name: Terraform Apply
        working-directory: terraform
        run: terraform apply -auto-approve -input=false
        env:
          ARM_CLIENT_ID: ${{ secrets.ARM_CLIENT_ID }}
          ARM_CLIENT_SECRET: ${{ secrets.ARM_CLIENT_SECRET }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.ARM_SUBSCRIPTION_ID }}
          ARM_TENANT_ID: ${{ secrets.ARM_TENANT_ID }}

      - name: Deployment Success
        if: success()
        run: |
          echo "✅ Azure Policy successfully deployed!"
          echo "Triggered by: Merge to main branch"
```

### Workflow Stages Explained

#### 1. **Pull Request Validation**
- **Trigger**: When PR is created/updated targeting main branch
- **Actions**:
  - Checkout code
  - Setup Terraform
  - Initialize Terraform with Azure backend
  - Validate Terraform syntax
  - Generate and review execution plan
- **Purpose**: Catch issues before merge, ensure policy is valid

#### 2. **Automatic Deployment**
- **Trigger**: When PR is merged to main branch (push event)
- **Actions**:
  - Checkout latest code
  - Setup Terraform
  - Initialize Terraform
  - Apply changes automatically
  - Deploy policy to Azure subscription
- **Purpose**: Automate policy deployment without manual intervention

## Testing the Implementation

### Test Scenario 1: Policy Creation Validation

1. **Create feature branch**:
   ```bash
   git checkout -b feature/add-region-policy
   ```

2. **Add policy files** (as shown in implementation)

3. **Create Pull Request**:
   - GitHub Actions will run validation
   - Check Actions tab for results
   - Ensure all checks pass

### Test Scenario 2: Automated Deployment

1. **Merge Pull Request**:
   - Click "Merge pull request" in GitHub
   - GitHub Actions automatically triggers deployment

2. **Monitor deployment**:
   - Check Actions tab for deployment status
   - Verify successful completion

### Test Scenario 3: Policy Enforcement

1. **Test policy blocking** (should fail):
   ```bash
   # Try creating resource in West US
   az group create --name test-rg-westus --location westus
   ```

2. **Test policy allowing** (should succeed):
   ```bash
   # Create resource in East US
   az group create --name test-rg-eastus --location eastus
   ```

## Verification Steps

### 1. Verify Policy Definition in Azure Portal

1. Navigate to **Azure Portal → Policy → Definitions**
2. Filter by **Type: Custom**
3. Look for **"Allow Only East US Region"**
4. Verify policy rule shows location restriction

### 2. Verify Policy Assignment

1. Navigate to **Policy → Assignments**
2. Find **"Enforce East US Only"** assignment
3. Verify scope is set to your subscription
4. Check assignment status

### 3. Verify Policy Compliance

1. Navigate to **Policy → Compliance**
2. Find your policy assignment
3. Review compliance state
4. Check for any non-compliant resources

### 4. CLI Verification

```bash
# List custom policies
az policy definition list --query "[?policyType=='Custom'].{Name:name,DisplayName:displayName}"

# List policy assignments
az policy assignment list --query "[].{Name:name,DisplayName:displayName}"

# Test policy enforcement
az group create --name test-policy --location westus2
# Should return: Policy violation error
```

## Troubleshooting

### Common Issues and Solutions

#### 1. **Permission Errors**
```
Error: AuthorizationFailed - does not have authorization to perform action 'Microsoft.Authorization/policyDefinitions/write'
```

**Solution:**
- Verify service principal has "Resource Policy Contributor" role
- Check role assignment scope covers the subscription
- Refresh credentials if recently granted

#### 2. **Policy Rule JSON Errors**
```
Error: InvalidPolicyRule - Failed to parse policy rule
```

**Solution:**
- Validate JSON syntax in policy file
- Ensure policy rule structure matches Azure Policy schema
- Remove any wrapper objects if using external JSON file

#### 3. **GitHub Actions Failures**
```
Error: terraform init failed
```

**Solution:**
- Verify all required secrets are configured in GitHub
- Check secret names match exactly (case-sensitive)
- Ensure service principal credentials are valid

#### 4. **Terraform State Issues**
```
Error: resource already exists
```

**Solution:**
- Use `terraform import` for existing resources
- Or destroy existing resources and redeploy
- Check for naming conflicts

### Debug Commands

```bash
# Check Azure login
az account show

# Verify service principal permissions
az role assignment list --assignee "{service-principal-id}"

# Test Terraform locally
cd terraform
terraform init
terraform plan
terraform validate

# Check policy syntax
az policy definition validate --rules policy/allow-only-eastus.json
```

## Best Practices

### 1. **Security**
- Use least-privilege principle for service principal permissions
- Store sensitive data in GitHub Secrets, never in code
- Regularly rotate service principal credentials
- Use managed identities when possible

### 2. **Code Organization**
- Separate policy definitions from Terraform configuration
- Use meaningful naming conventions
- Include comprehensive documentation
- Version control all policy changes

### 3. **CI/CD Pipeline**
- Always validate before deployment
- Use automated testing for policy rules
- Implement proper error handling
- Monitor deployment results

### 4. **Policy Management**
- Start with audit mode before enforcement
- Test policies in development environment first
- Document policy business justification
- Plan for policy exceptions if needed

### 5. **Monitoring and Compliance**
- Regularly review policy compliance
- Set up alerts for policy violations
- Monitor policy assignment status
- Document compliance reporting process

## Next Steps (Phase 2 Preparation)

Phase 1 successfully implements:
- ✅ Custom Azure Policy creation
- ✅ Policy-as-Code with version control
- ✅ Automated CI/CD deployment
- ✅ Region restriction enforcement

**Phase 2 will demonstrate:**
- Policy-driven Terraform deployment failures
- Resource creation attempts in blocked regions
- Comprehensive failure handling and reporting

## Conclusion

This implementation provides a robust foundation for Azure Policy as Code with the following benefits:

- **Automated Governance**: Policies are automatically enforced without manual intervention
- **Version Control**: All policy changes are tracked and auditable
- **Consistent Deployment**: CI/CD ensures reliable and repeatable deployments
- **Immediate Enforcement**: Policies take effect immediately after deployment
- **Compliance Assurance**: Region restrictions are automatically enforced across the subscription

The solution demonstrates modern DevOps practices applied to cloud governance, ensuring that infrastructure compliance is built into the development workflow rather than being an afterthought.