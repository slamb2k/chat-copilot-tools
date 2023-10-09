<#
.SYNOPSIS
Create the required Azure AD App Registrations for both the backend and frontend web resources.

.PARAMETER Subscription
Subscription in which to create the application registrations.

.PARAMETER FrontendDisplayName
The display name for the frontend's AAD app registration.

.PARAMETER BackendDisplayName
The display name for the backend's AAD app registration.
#>

param(
  [Parameter(Mandatory = $true)]
  [string]$Subscription,
    
  [Parameter(Mandatory = $false)]
  [string]$FrontendDisplayName = "app-chat-copilot-frontend",

  [Parameter(Mandatory = $false)]
  [string]$BackendDisplayName = "app-chat-copilot-backend",

  [Parameter(Mandatory = $false)]
  [string]$SignInAudience = "AzureADMyOrg"
)


# Create both of the frontend and backend app registration

$ErrorActionPreference = "Stop"

if (!$ResourceGroup) {
  $ResourceGroup = "rg-" + $DeploymentName
}

az account show --output none
if ($LASTEXITCODE -ne 0) {
  Write-Host "Log into your Azure account"
  az login --output none
}

az account set -s $Subscription
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

Write-Host "Ensuring resource group '$ResourceGroup' exists..."
az group create --location $Region --name $ResourceGroup --tags Creator=$env:UserName
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

Write-Host "Validating template file..."
az deployment group validate --name $DeploymentName --resource-group $ResourceGroup --template-file $templateFile --parameters $jsonConfig
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}


# create backend app registration and return the client ID

APP_BACKEND_ID=$(az ad app create \
    --display-name "$BACKEND_DISPLAY_NAME" \
    --sign-in-audience "$SignInAudience" \
    --query appId \
    --output tsv)

# defaults for scope and api

UUID=$(uuidgen)
WEB_API_SCOPE="access_as_user"

# set the api object as a JSON object

API_PAYLOAD=$(echo '{
    "acceptMappedClaims": null,
    "knownClientApplications": [],
    "oauth2PermissionScopes": [{
        "adminConsentDescription": "Allows the accesses to the Chat Copilot web API as a user",
        "adminConsentDisplayName": "Access Chat Copilot as a user",
        "id": "'$UUID'",
        "isEnabled": true,
        "type": "User",
        "userConsentDescription": "Allows the accesses to the Chat Copilot web API as a user",
        "userConsentDisplayName": "Access Chat Copilot as a user",
        "value": "'$WEB_API_SCOPE'"
    }],
    "preAuthorizedApplications": [],
    "requestedAccessTokenVersion": 2
}' | jq .)

# set the resource object as a JSON object

RESOURCE_PAYLOAD=$(echo '[
    {
    "resourceAccess": [
        {
        "id": "e1fe6dd8-ba31-4d61-89e7-88639da4683d",
        "type": "Scope"
        }
    ],
    "resourceAppId": "00000003-0000-0000-c000-000000000000"
    }
]' | jq .)

# create backend app registration and return the client ID
APP_BACKEND_ID=$(az ad app create `
    --display-name "$BACKEND_DISPLAY_NAME" `
    --sign-in-audience "$SIGN_IN_AUDIENCE" `
    --query appId `
    --output tsv)

# defaults for scope and api
UUID=$(uuidgen)
WEB_API_SCOPE="access_as_user"

# create frontend app registration and return the client ID
APP_FRONTEND_ID=$(az ad app create `
    --display-name "$FRONTEND_DISPLAY_NAME" `
    --sign-in-audience "$SignInAudience" `
    --query appId `
    --output tsv)

# set the resource object as a JSON object
RESOURCE_PAYLOAD=$(echo '[
    {
    "resourceAccess": [
        {
        "id": "'$UUID'",
        "type": "Scope"
        }
    ],
    "resourceAppId": "'$APP_BACKEND_ID'"
    },
    {
    "resourceAccess": [
        {
        "id": "e1fe6dd8-ba31-4d61-89e7-88639da4683d",
        "type": "Scope"
        }
    ],
    "resourceAppId": "00000003-0000-0000-c000-000000000000"
    }
]' | jq .)

# set the spa object as a JSON object
SPA_PAYLOAD=$(echo '{
    "redirectUris": [
        "http://localhost:3000"
    ]
}' | jq .)

# Update app registration with App ID URL and api object
az ad app update \
--id "$APP_FRONTEND_ID" \
--set spa="$SPA_PAYLOAD"

# set the pre-authorized applications object as a JSON object
PRE_AUTHORIZED_APPS_PAYLOAD=$(echo '{
    "preAuthorizedApplications": [
		{
			"appId": "'$APP_FRONTEND_ID'",
			"delegatedPermissionIds": [
				"'$UUID'"
			]
		}
	]
}' | jq .)

# Update app registration with App ID URL and api object
az ad app update \
--id "$APP_BACKEND_ID" \
--set api="$PRE_AUTHORIZED_APPS_PAYLOAD"

echo "==============================================================================================="
echo "Backend app registration created with client ID: $APP_BACKEND_ID"
echo "Frontend app registration created with client ID: $APP_FRONTEND_ID"
echo ""
echo "You can now call ./Configure.sh to configure the Chat Copilot solution using these app registrations:"
echo "./Configure.sh --aiservice {AI_SERVICE} --apikey {API_KEY} --endpoint {AZURE_OPENAI_ENDPOINT} --frontend-clientid $APP_FRONTEND_ID --backend-clientid $APP_BACKEND_ID --tenantid $AZURE_AD_TENANT_ID"
echo "==============================================================================================="
