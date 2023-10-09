#!/bin/bash

# Create app registrations for the frontend and backend apps

set -e

usage() {
  echo "Usage: $0 -s SUBSCRIPTION"
  echo ""
  echo "Arguments:"
  echo "  -s, --subscription SUBSCRIPTION                     Subscription in which to create the application registrations (mandatory)"
  echo "  -f, --frontend-display-name FRONTEND_DISPLAY_NAME   Client application Display Name for the frontend web app (default: app-chat-copilot-frontend)"
  echo "  -b, --backend-display-name BACKEND_DISPLAY_NAME     Client application Display Name for the backend web api (default: app-chat-copilot-backend)"
  echo "  -a, --sign-in-audience SIGN_IN_AUDIENCE             Client application sign-in audience (i.e., AzureAD or AzureADandPersonalMicrosoftAccount) (default: AzureAD)"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
  -s | --subscription)
    SUBSCRIPTION="$2"
    shift
    shift
    ;;
  -f | --frontend-display-name)
    FRONTEND_DISPLAY_NAME="$2"
    shift
    shift
    ;;
  -b | --backend-display-name)
    BACKEND_DISPLAY_NAME="$2"
    shift
    shift
    ;;
  --sign-in-audience)
    SIGN_IN_AUDIENCE="$2"
    shift
    shift
    ;;
  *)
    echo "Unknown option $1"
    usage
    exit 1
    ;;
  esac
done

az account show --output none
if [ $? -ne 0 ]; then
  echo "Log into your Azure account"
  az login --use-device-code
fi

az account set -s "$SUBSCRIPTION"

# create backend app registration and return the client ID
APP_BACKEND_ID=$(az ad app create \
  --display-name "$BACKEND_DISPLAY_NAME" \
  --sign-in-audience "$SIGN_IN_AUDIENCE" \
  --query id \
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

# Update app registration with App ID URL and api object
az ad app update \
  --id "$APP_BACKEND_ID" \
  --identifier-uris "api://$APP_BACKEND_ID" \
  --required-resource-accesses "$RESOURCE_PAYLOAD" \
  --set api="$API_PAYLOAD"

# create frontend app registration and return the client ID
APP_FRONTEND_ID=$(az ad app create \
  --display-name "$FRONTEND_DISPLAY_NAME" \
  --sign-in-audience "$SIGN_IN_AUDIENCE" \
  --query appId \
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
echo "./Configure.sh --aiservice $ENV_AI_SERVICEAI_SERVICE --apikey {API_KEY} --endpoint {AZURE_OPENAI_ENDPOINT} --frontend-clientid $APP_FRONTEND_ID --backend-clientid $APP_BACKEND_ID --tenantid $AZURE_AD_TENANT_ID"
echo "==============================================================================================="

# Construct a custom object to return both App IDs
$value = "" | Select-Object -Property FrontendAppId, BackendAppId
$value.FrontendAppId = $APP_FRONTEND_ID
$value.BackendAppId = $APP_BACKEND_ID
return $value
