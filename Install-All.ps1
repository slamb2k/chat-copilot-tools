param(
  [switch]
  # Don't configure authentication for frontend and backend apps
  $NoAuth = $false
)

# Auth
$YOUR_BACKEND_APPLICATION_ID = "fe4c3059-f4cf-418a-a198-1445800ad9b6"
$YOUR_FRONTEND_APPLICATION_ID = "e06ff0af-a0e8-4b86-8019-bd45005028b4"
$YOUR_TENANT_ID = "dfa165cb-f90a-4669-bf02-639bf2576013"

# Azure
$YOUR_AZURE_OPENAI_ENDPOINT = "https://silamb-openai.openai.azure.com/"
$YOUR_AZURE_REGION = "australiaeast"
$YOUR_AZURE_WEBAPP_REGION = "westus2"
$YOUR_DEPLOYMENT_NAME = "clara-lucas"

# Secrets (Moving to dotnet secrets)
$YOUR_SUBSCRIPTION_ID = "f6612970-039c-4746-a93c-06bd00d6230c" # NEW EXTERNAL SUB
$YOUR_AI_KEY = "9ba0dfcaee414c1ab90b024a91c60907"
$YOUR_AI_SERVICE = "AzureOpenAI"

# Load environment variables
. .\Dot-Env.ps1
dotenv

# Install dependencies
.\Install.ps1

# Configure variables and config to install
If ($NoAuth) {
  . .\Configure.ps1 -AIService $YOUR_AI_SERVICE -APIKey $YOUR_AI_KEY -Endpoint $YOUR_AZURE_OPENAI_ENDPOINT
}
Else {
  . .\Configure.ps1 -AIService $YOUR_AI_SERVICE -APIKey $YOUR_AI_KEY -Endpoint $YOUR_AZURE_OPENAI_ENDPOINT -FrontendClientId $YOUR_FRONTEND_APPLICATION_ID -BackendClientId $YOUR_BACKEND_APPLICATION_ID -TenantId $YOUR_TENANT_ID -Instance $ENV_INSTANCE
}

# Start the both the backend and frontend locally
#.\Start.ps1

# Deploy the infrastructure to Azure
Set-Location deploy

.\deploy-azure.ps1 -Subscription $YOUR_SUBSCRIPTION_ID -DeploymentName $YOUR_DEPLOYMENT_NAME -AIService AzureOpenAI -AIApiKey $YOUR_AI_KEY -AIEndpoint $YOUR_AZURE_OPENAI_ENDPOINT -BackendClientId $YOUR_BACKEND_APPLICATION_ID -TenantId $YOUR_TENANT_ID -Region $YOUR_AZURE_REGION -WebAppRegion $YOUR_AZURE_WEBAPP_REGION

# Install pre-requisites, build and deploy the web api

# InstrumentationKey=e726087f-6433-4761-a293-4650c933ffe3;IngestionEndpoint=https://australiaeast-1.in.applicationinsights.azure.com/;LiveEndpoint=https://australiaeast.livediagnostics.monitor.azure.com/

# dotnet user-secrets set "SemanticMemory:Services:AzureOpenAIText:APIKey" "$YOUR_AI_KEY"
# dotnet user-secrets set "SemanticMemory:Services:AzureOpenAIEmbedding:APIKey" "$YOUR_AI_KEY"
# dotnet user-secrets set "SemanticMemory:Services:OpenAI:APIKey" "$YOUR_AI_KEY"

# $ENV_COGNITIVE_API_KEY = "d87ed46abec945cbba66d925551315f2"
# $ENV_FORM_REC_API_KEY = "hjePBqBR91mqVB4v7w74U0FMVgwBnTzxhvGLmOTBvKAzSeB8euTX"

# dotnet user-secrets set "SemanticMemory:Services:AzureCognitiveSearch:APIKey" "$ENV_COGNITIVE_API_KEY"
# dotnet user-secrets set "SemanticMemory:Services:AzureFormRecognizer:APIKey" "$ENV_FORM_REC_API_KEY"

.\package-webapi.ps1

.\deploy-webapi.ps1 -Subscription $YOUR_SUBSCRIPTION_ID -ResourceGroupName "rg-$YOUR_DEPLOYMENT_NAME" -DeploymentName $YOUR_DEPLOYMENT_NAME

# Install pre-requisites, build and deploy the web app
#curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
#npm install -g @azure/static-web-apps-cli
#sudo apt install zip

.\deploy-webapp.ps1 -Subscription $YOUR_SUBSCRIPTION_ID -ResourceGroupName "rg-$YOUR_DEPLOYMENT_NAME" -DeploymentName $YOUR_DEPLOYMENT_NAME -FrontendClientId $YOUR_FRONTEND_APPLICATION_ID
