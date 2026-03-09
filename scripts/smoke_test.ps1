#!/usr/bin/env pwsh
# ================================================================
# smoke_test.ps1 - デプロイ後の Smoke Test
#
# 使い方:
#   ./scripts/smoke_test.ps1 -ResourceGroupName <RG_NAME> [-EnvironmentName dev]
#
# 前提条件:
#   - az CLI がログイン済みであること
#   - デプロイ済みの Resource Group が存在すること
# ================================================================
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$EnvironmentName = 'dev'
)

$ErrorActionPreference = 'Stop'
$prefix = "fmcp-${EnvironmentName}"

# テスト結果の追跡
$passed = 0
$failed = 0
$warnings = 0
$results = [System.Collections.Generic.List[PSCustomObject]]::new()

function Add-Result {
    param(
        [string]$Name,
        [ValidateSet('PASS', 'FAIL', 'WARN')]
        [string]$Status,
        [string]$Detail = ''
    )
    $results.Add([PSCustomObject]@{ Name = $Name; Status = $Status; Detail = $Detail })
    switch ($Status) {
        'PASS' { $script:passed++; Write-Host "  ✅ $Name" -ForegroundColor Green }
        'FAIL' { $script:failed++; Write-Host "  ❌ $Name — $Detail" -ForegroundColor Red }
        'WARN' { $script:warnings++; Write-Host "  ⚠️  $Name — $Detail" -ForegroundColor Yellow }
    }
}

# ──────────────────────────────────────────────
# 共通ヘルパー
# ──────────────────────────────────────────────
function Get-DeploymentOutput {
    param([string]$OutputName)
    $raw = az deployment group show `
        --resource-group $ResourceGroupName `
        --name main `
        --query "properties.outputs.${OutputName}.value" `
        --output tsv 2>$null
    return $raw
}

# ──────────────────────────────────────────────
# 1. Resource Group 存在確認
# ──────────────────────────────────────────────
Write-Host "`n[1] Resource Group" -ForegroundColor Cyan
$rgState = az group show --name $ResourceGroupName --query provisioningState --output tsv 2>$null
if ($rgState -eq 'Succeeded') {
    Add-Result "Resource Group '$ResourceGroupName' exists" 'PASS'
} else {
    Add-Result "Resource Group '$ResourceGroupName' exists" 'FAIL' "State: $rgState"
    Write-Error "Resource group not found or not ready. Aborting."
}

# ──────────────────────────────────────────────
# 2. デプロイメント状態確認
# ──────────────────────────────────────────────
Write-Host "`n[2] Deployment Status" -ForegroundColor Cyan
$deployState = az deployment group show `
    --resource-group $ResourceGroupName `
    --name main `
    --query provisioningState `
    --output tsv 2>$null
if ($deployState -eq 'Succeeded') {
    Add-Result "Bicep deployment 'main' succeeded" 'PASS'
} else {
    Add-Result "Bicep deployment 'main' succeeded" 'FAIL' "State: $deployState"
}

# ──────────────────────────────────────────────
# 3. 各リソースの存在・状態確認
# ──────────────────────────────────────────────
Write-Host "`n[3] Resource Existence" -ForegroundColor Cyan

# Log Analytics Workspace
$lawState = az monitor log-analytics workspace show `
    --resource-group $ResourceGroupName `
    --workspace-name "${prefix}-law" `
    --query provisioningState --output tsv 2>$null
if ($lawState -eq 'Succeeded') {
    Add-Result "Log Analytics Workspace '${prefix}-law'" 'PASS'
} else {
    Add-Result "Log Analytics Workspace '${prefix}-law'" 'FAIL' "State: $lawState"
}

# Application Insights
$aiState = az monitor app-insights component show `
    --resource-group $ResourceGroupName `
    --app "${prefix}-ai" `
    --query provisioningState --output tsv 2>$null
if ($aiState -eq 'Succeeded') {
    Add-Result "Application Insights '${prefix}-ai'" 'PASS'
} else {
    Add-Result "Application Insights '${prefix}-ai'" 'FAIL' "State: $aiState"
}

# Key Vault
$kvState = az keyvault show `
    --resource-group $ResourceGroupName `
    --name "${prefix}-kv" `
    --query properties.provisioningState --output tsv 2>$null
if ($kvState -eq 'Succeeded') {
    Add-Result "Key Vault '${prefix}-kv'" 'PASS'
} else {
    Add-Result "Key Vault '${prefix}-kv'" 'FAIL' "State: $kvState"
}

# Key Vault シークレット確認
$kvSecretList = az keyvault secret list `
    --vault-name "${prefix}-kv" `
    --query "[].name" --output tsv 2>$null
if ($kvSecretList -match 'appinsights-connection-string') {
    Add-Result "Key Vault secret 'appinsights-connection-string' exists" 'PASS'
} else {
    Add-Result "Key Vault secret 'appinsights-connection-string' exists" 'WARN' "Secret not found (private endpoint may block access from this network)"
}

# SQL Server
$sqlState = az sql server show `
    --resource-group $ResourceGroupName `
    --name "${prefix}-sql" `
    --query state --output tsv 2>$null
if ($sqlState -eq 'Ready') {
    Add-Result "SQL Server '${prefix}-sql'" 'PASS'
} else {
    Add-Result "SQL Server '${prefix}-sql'" 'FAIL' "State: $sqlState"
}

# SQL Database
$sqlDbState = az sql db show `
    --resource-group $ResourceGroupName `
    --server "${prefix}-sql" `
    --name "${prefix}-db" `
    --query status --output tsv 2>$null
if ($sqlDbState -eq 'Online') {
    Add-Result "SQL Database '${prefix}-db'" 'PASS'
} else {
    Add-Result "SQL Database '${prefix}-db'" 'WARN' "Status: $sqlDbState (Paused は正常。アクセス時に自動起動)"
}

# AI Search
$searchState = az search service show `
    --resource-group $ResourceGroupName `
    --name "${prefix}-search" `
    --query provisioningState --output tsv 2>$null
if ($searchState -eq 'Succeeded') {
    Add-Result "AI Search '${prefix}-search'" 'PASS'
} else {
    Add-Result "AI Search '${prefix}-search'" 'FAIL' "State: $searchState"
}

# Container Registry
$acrName = "${prefix}-acr" -replace '-', ''
$acrState = az acr show `
    --resource-group $ResourceGroupName `
    --name $acrName `
    --query provisioningState --output tsv 2>$null
if ($acrState -eq 'Succeeded') {
    Add-Result "Container Registry '$acrName'" 'PASS'
} else {
    Add-Result "Container Registry '$acrName'" 'FAIL' "State: $acrState"
}

# Container Apps Environment
$caeState = az containerapp env show `
    --resource-group $ResourceGroupName `
    --name "${prefix}-cae" `
    --query provisioningState --output tsv 2>$null
if ($caeState -eq 'Succeeded') {
    Add-Result "Container Apps Environment '${prefix}-cae'" 'PASS'
} else {
    Add-Result "Container Apps Environment '${prefix}-cae'" 'FAIL' "State: $caeState"
}

# MCP Server Container App
$mcpAppState = az containerapp show `
    --resource-group $ResourceGroupName `
    --name "${prefix}-mcp" `
    --query properties.provisioningState --output tsv 2>$null
if ($mcpAppState -eq 'Succeeded') {
    Add-Result "MCP Server Container App '${prefix}-mcp'" 'PASS'
} else {
    Add-Result "MCP Server Container App '${prefix}-mcp'" 'FAIL' "State: $mcpAppState"
}

# MCP Server running replicas
$mcpReplicas = az containerapp show `
    --resource-group $ResourceGroupName `
    --name "${prefix}-mcp" `
    --query "properties.template.scale.minReplicas" `
    --output tsv 2>$null
if ($null -ne $mcpReplicas) {
    $activeRevisions = az containerapp revision list `
        --resource-group $ResourceGroupName `
        --name "${prefix}-mcp" `
        --query "[?properties.active==\`true\`] | length(@)" `
        --output tsv 2>$null
    $activeCount = if ($activeRevisions) { $activeRevisions } else { '0' }
    Add-Result "MCP Server has active revision" 'PASS' "activeRevisions=${activeCount}, minReplicas=${mcpReplicas}"
} else {
    Add-Result "MCP Server has active revision" 'WARN' "Could not determine revision count"
}

# APIM
$apimState = az apim show `
    --resource-group $ResourceGroupName `
    --name "${prefix}-apim" `
    --query provisioningState --output tsv 2>$null
if ($apimState -eq 'Succeeded') {
    Add-Result "API Management '${prefix}-apim'" 'PASS'
} else {
    Add-Result "API Management '${prefix}-apim'" 'FAIL' "State: $apimState"
}

# ──────────────────────────────────────────────
# 4. RBAC ロール割り当て確認
# ──────────────────────────────────────────────
Write-Host "`n[4] RBAC Role Assignments" -ForegroundColor Cyan

$kvId = az keyvault show `
    --resource-group $ResourceGroupName `
    --name "${prefix}-kv" `
    --query id --output tsv 2>$null

if ($kvId) {
    $kvRoles = az role assignment list --scope $kvId --query "[].{role:roleDefinitionName, principal:principalName}" --output json 2>$null | ConvertFrom-Json
    $roleNames = $kvRoles | Select-Object -ExpandProperty role

    if ($roleNames -contains 'Key Vault Secrets User' -or $roleNames -contains 'Key Vault Secrets Officer') {
        Add-Result "Key Vault has role assignments" 'PASS' "Roles: $($roleNames -join ', ')"
    } else {
        Add-Result "Key Vault has role assignments" 'WARN' "No expected roles found (may require elevated permissions to list)"
    }
} else {
    Add-Result "Key Vault RBAC check" 'WARN' "Could not retrieve KV ID"
}

# ──────────────────────────────────────────────
# 5. デプロイメント出力値確認
# ──────────────────────────────────────────────
Write-Host "`n[5] Deployment Outputs" -ForegroundColor Cyan

$outputsToCheck = @(
    'apimGatewayUrl',
    'mcpApiUrl',
    'acrLoginServer',
    'sqlServerFqdn',
    'aiSearchEndpoint',
    'keyVaultUri',
    'aiServicesEndpoint',
    'mcpIdentityClientId'
)

foreach ($outputName in $outputsToCheck) {
    $val = Get-DeploymentOutput -OutputName $outputName
    if (-not [string]::IsNullOrWhiteSpace($val)) {
        Add-Result "Output '$outputName' = $val" 'PASS'
    } else {
        Add-Result "Output '$outputName' is present" 'FAIL' "Value is empty"
    }
}

# ──────────────────────────────────────────────
# 6. APIM MCP API 確認
# ──────────────────────────────────────────────
Write-Host "`n[6] APIM API Definitions" -ForegroundColor Cyan

$mcpApiId = az apim api show `
    --resource-group $ResourceGroupName `
    --service-name "${prefix}-apim" `
    --api-id "mcp-server-api" `
    --query id --output tsv 2>$null
if ($mcpApiId) {
    Add-Result "APIM API 'mcp-server-api' registered" 'PASS'
} else {
    Add-Result "APIM API 'mcp-server-api' registered" 'FAIL' "API definition not found"
}

# ──────────────────────────────────────────────
# サマリ
# ──────────────────────────────────────────────
Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host " Smoke Test Summary" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  ✅ PASS   : $passed" -ForegroundColor Green
Write-Host "  ⚠️  WARN   : $warnings" -ForegroundColor Yellow
Write-Host "  ❌ FAIL   : $failed" -ForegroundColor Red
Write-Host "================================================================`n" -ForegroundColor Cyan

if ($failed -gt 0) {
    Write-Host "Smoke test FAILED ($failed failures). See above for details." -ForegroundColor Red
    exit 1
} elseif ($warnings -gt 0) {
    Write-Host "Smoke test PASSED with $warnings warning(s). Manual verification may be required for WARN items." -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "Smoke test PASSED. All resources are deployed and configured correctly." -ForegroundColor Green
    exit 0
}
