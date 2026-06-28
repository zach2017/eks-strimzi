@echo off
REM ============================================================================
REM EKS-Strimzi Deployment Script (Windows)
REM ============================================================================

setlocal enabledelayedexpansion

set ENVIRONMENT=%1
set ACTION=%2

if "!ENVIRONMENT!"=="" set ENVIRONMENT=dev
if "!ACTION!"=="" set ACTION=plan

REM Validate environment
if not "!ENVIRONMENT!"=="dev" if not "!ENVIRONMENT!"=="staging" if not "!ENVIRONMENT!"=="prod" (
    echo [ERROR] Invalid environment. Must be dev, staging, or prod
    exit /b 1
)

set SCRIPT_DIR=%~dp0
set TERRAFORM_DIR=%SCRIPT_DIR%..\..\terraform
cd /d "!TERRAFORM_DIR!"

echo [INFO] Running action '!ACTION!' for environment '!ENVIRONMENT!'

if "!ACTION!"=="init" (
    echo [INFO] Initializing Terraform...
    call terraform init -upgrade
) else if "!ACTION!"=="plan" (
    echo [INFO] Planning Terraform changes...
    call terraform plan -var-file="environments\!ENVIRONMENT!\terraform.tfvars" -out="!ENVIRONMENT!.tfplan"
) else if "!ACTION!"=="apply" (
    echo [INFO] Applying Terraform changes...
    if not exist "!ENVIRONMENT!.tfplan" (
        echo [INFO] Plan file not found. Creating new plan...
        call terraform plan -var-file="environments\!ENVIRONMENT!\terraform.tfvars" -out="!ENVIRONMENT!.tfplan"
    )
    call terraform apply "!ENVIRONMENT!.tfplan"
    echo [INFO] Configuring kubectl...
    for /f "delims=" %%i in ('terraform output -raw cluster_name 2^>nul') do set CLUSTER_NAME=%%i
    for /f "delims=" %%i in ('terraform output -raw aws_region 2^>nul') do set REGION=%%i
    if not "!CLUSTER_NAME!"=="" (
        call aws eks update-kubeconfig --region !REGION! --name !CLUSTER_NAME!
        echo [INFO] kubectl configured
    )
) else if "!ACTION!"=="destroy" (
    echo [WARNING] About to destroy all resources for !ENVIRONMENT! environment!
    set /p confirm=Type 'yes' to confirm: 
    if "!confirm!"=="yes" (
        call terraform destroy -var-file="environments\!ENVIRONMENT!\terraform.tfvars" -auto-approve
    ) else (
        echo [INFO] Destroy cancelled
    )
) else if "!ACTION!"=="outputs" (
    call terraform output -var-file="environments\!ENVIRONMENT!\terraform.tfvars"
) else (
    echo [ERROR] Unknown action: !ACTION!
    exit /b 1
)

echo [INFO] Done!
endlocal
