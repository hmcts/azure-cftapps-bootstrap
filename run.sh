#!/usr/bin/env bash

set -ex

if [ "${1}" == "--force" ] || [ "${1}" == "-f" ] ; then
  DELETE_NON_IDEMPOTENT_RESOURCES="true"
  shift
else
  DELETE_NON_IDEMPOTENT_RESOURCES="false"
fi

case "${1}" in
	"sbox"|"SBOX"|"Sbox")
		ENV="sbox"
    LONG_ENV="sandbox"
    CRITICALITY="Low"
		;;
	"demo"|"DEMO"|"Demo")
		ENV="demo"
    LONG_ENV="demo"
    CRITICALITY="Medium"
		;;
  "test"|"TEST"|"Test")
    ENV="test"
    LONG_ENV="test"
    CRITICALITY="Medium"
    ;;
	"ithc"|"ITHC"|"Ithc")
		ENV="ithc"
    LONG_ENV="ithc"
    CRITICALITY="Medium"
		;;
  "stg"|"STG"|"Stg")
    ENV="stg"
    LONG_ENV="staging"
    CRITICALITY="High"
    ;;
  "prod"|"PROD"|"Prod")
    ENV="prod"
    LONG_ENV="production"
    CRITICALITY="High"
    # for some reason this vault is already taken, snowflaking prod for now till we have a better solution
    VAULT_NAME="cft-apps-prod"
    ;;
	*)
		echo "Invalid environment. Exiting"
		exit 1
		;;
esac

INFRA_RG_PREFIX="${ENV}"
VAULT_NAME="${SUB}-${ENV}"

case "${2}" in
	"cftapps"|"CFTAPPS"|"CftApps")
		SUB="cftapps";;
	"mgmt"|"MGMT"|"Mgmt")
		SUB="mgmt"
		INFRA_RG_PREFIX="${SUB}-${INFRA_RG_PREFIX}"
		;;
	"papi"|"PAPI"|"Papi")
		SUB="papi";;
	"dmz"|"DMZ"|"Dmz")
		SUB="dmz";;

	*)
		echo "Invalid subscription. Exiting"
		exit 1
		;;
esac

SERVER_APP_NAME="dcd_app_aks_${SUB}_${ENV}_server_v2"
SERVER_APP_DISPLAY_NAME="AKS ${SUB} ${ENV} server"
CLIENT_APP_NAME="dcd_app_aks_${SUB}_${ENV}_client_v2"
CLIENT_APP_DISPLAY_NAME="AKS ${SUB} ${ENV} client"
OPERATIONS_SP_NAME="dcd_sp_ado_${ENV}_operations_v2"
SUBSCRIPTION_SP_NAME="dcd_sp_sub_${SUB}_${ENV}_v2"
AKS_SP_NAME="dcd_sp_aks_${SUB}_${ENV}_v2"

CORE_INFRA_RG="core-infra-${INFRA_RG_PREFIX}-rg"
LOCATION="uksouth"

COMMON_TAGS=(
  "managedBy=Platform Engineering" 
  "solutionOwner=CFT" 
  "activityName=AKS" 
  "dataClassification=internal" 
  "automation=" 
  "costCentre=10245117" 
  "environment=${LONG_ENV}" 
  "criticality=${CRITICALITY}"
)

function usage() {
  echo "usage: ./run.sh <env>" 
}

function keyvaultSecretSet() {
    az keyvault secret set --vault-name ${VAULT_NAME} --name ${1} --value ${2}
}

function addKeyvaultFullAccessPolicy() {
    az keyvault set-policy --name $1 \
    --object-id $2 \
    --secret-permissions backup delete get list purge recover restore set \
    --certificate-permissions backup create delete deleteissuers get getissuers import list listissuers managecontacts manageissuers purge recover restore setissuers update \
    --key-permissions backup create decrypt delete encrypt get import list purge recover restore sign unwrapKey update verify wrapKey
}

function addKeyvaultFullAccessPolicySP() {
    az keyvault set-policy --name $1 \
    --spn $2 \
    --secret-permissions backup delete get list purge recover restore set \
    --certificate-permissions backup create delete deleteissuers get getissuers import list listissuers managecontacts manageissuers purge recover restore setissuers update \
    --key-permissions backup create decrypt delete encrypt get import list purge recover restore sign unwrapKey update verify wrapKey
}

if [ -z "${ENV}" ] ; then
  usage
  exit 1
fi

az group create --location ${LOCATION} --name ${CORE_INFRA_RG} --tags "${COMMON_TAGS[@]}"

az storage account create --name ${SUB}${ENV//-/} \
  --resource-group ${CORE_INFRA_RG} \
  --sku Standard_LRS \
  --encryption-services blob \
  --kind StorageV2 \
  --location ${LOCATION} \
  --tags "${COMMON_TAGS[@]}" \
  --https-only true

az storage container create  --account-name ${SUB}${ENV//-/}  --name tfstate

az keyvault create --name ${VAULT_NAME} \
  --resource-group ${CORE_INFRA_RG}  \
  --location ${LOCATION} \
  --enable-purge-protection true \
  --enable-soft-delete true \
  --enabled-for-deployment true  \
  --tags "${COMMON_TAGS[@]}" \
  --enabled-for-template-deployment true
  
# addKeyvaultFullAccessPolicy ${VAULT_NAME} 9189d86a-e260-4c3d-8227-803123cdce84 # aks-cluster-admins - for RPE tenant

addKeyvaultFullAccessPolicy ${VAULT_NAME} 300e771f-856c-45cc-b899-40d78281e9c1 # devops
addKeyvaultFullAccessPolicy ${VAULT_NAME} c36eaede-a0ae-4967-8fed-0a02960b1370 # platform-engineering

OPERATIONS_SP_APP_ID=$(az ad sp list --all --query  "[?appDisplayName=='${OPERATIONS_SP_NAME}'].{ appId: appId }" -o tsv)

addKeyvaultFullAccessPolicySP ${VAULT_NAME} ${OPERATIONS_SP_APP_ID}

SERVER_APP_PASSWORD=$(openssl rand -base64 32 | grep -o  '[[:alnum:]]' | tr -d '\n')

if [ ${DELETE_NON_IDEMPOTENT_RESOURCES} == "true" ]; then
  az ad app delete --id http://${SERVER_APP_NAME} || true
fi

export SERVER_APP_ID=$(az ad app create --display-name "${SERVER_APP_DISPLAY_NAME}" --required-resource-accesses @server-manifest.json  --identifier-uri http://${SERVER_APP_NAME} --password ${SERVER_APP_PASSWORD} --query appId -o tsv)
SERVER_SP_OBJECT_ID=$(az ad sp create --id ${SERVER_APP_ID} --query objectId -o tsv)

keyvaultSecretSet "aks-server-sp-object-id" ${SERVER_SP_OBJECT_ID}
keyvaultSecretSet "aks-server-app-id" ${SERVER_APP_ID}
keyvaultSecretSet "aks-server-app-password" ${SERVER_APP_PASSWORD}

az ad app update --id ${SERVER_APP_ID} --set groupMembershipClaims=All

sed "s/%%SERVER_APP_ID%%/${SERVER_APP_ID}/g" client-manifest.template.json > client-manifest.json
sleep 3

az ad app permission admin-consent --id ${SERVER_APP_ID}


if [ ${DELETE_NON_IDEMPOTENT_RESOURCES} == "true" ]; then
  EXISTING_CLIENT_APP_ID=$(az ad app list --display-name "${CLIENT_APP_DISPLAY_NAME}" --query "[0].appId" -o tsv)
  az ad app delete --id ${EXISTING_CLIENT_APP_ID} || true
fi

CLIENT_APP_ID=$(az ad app create --display-name "${CLIENT_APP_DISPLAY_NAME}" --native-app --reply-urls http://localhost/client https://afd.hosting.portal.azure.net/monitoring/Content/iframe/infrainsights.app/web/base-libs/auth/auth.html --required-resource-accesses @client-manifest.json  --query appId -o tsv)
CLIENT_SP_OBJECT_ID=$(az ad sp create --id ${CLIENT_APP_ID} --query objectId -o tsv) ||

keyvaultSecretSet "aks-client-sp-object-id" ${CLIENT_SP_OBJECT_ID}
keyvaultSecretSet "aks-client-app-id" ${CLIENT_APP_ID}

# without the sleep I was getting: 
# Operation failed with status: 'Bad Request'. Details: 400 Client Error: Bad Request for url: https://graph.windows.net/a0d77fc4-df1e-4b0d-8e35-46750ca5a672/oauth2PermissionGrants?api-version=1.6
sleep 5

az ad app permission grant --id ${CLIENT_SP_OBJECT_ID} --api ${SERVER_APP_ID}

if [ ${DELETE_NON_IDEMPOTENT_RESOURCES} == "true" ]; then
  az ad app delete --id http://${AKS_SP_NAME} || true
fi

AKS_SP_APP_ID=$(az ad app create --display-name "${AKS_SP_NAME}"  --identifier-uri http://${AKS_SP_NAME} --query appId -o tsv)
AKS_SP_APP_PASSWORD=$(az ad sp credential reset --name http://${AKS_SP_NAME} --query password -o tsv)
AKS_SP_OBJECT_ID=$(az ad sp create --id ${AKS_SP_APP_ID} --query objectId -o tsv)

keyvaultSecretSet "aks-sp-app-id" ${AKS_SP_APP_ID}
keyvaultSecretSet "aks-sp-object-id" ${AKS_SP_OBJECT_ID}
keyvaultSecretSet "aks-sp-app-password" ${AKS_SP_APP_PASSWORD}

if [ ${DELETE_NON_IDEMPOTENT_RESOURCES} == "true" ]; then
  az ad app delete --id http://${SUBSCRIPTION_SP_NAME} || true
fi

SUBSCRIPTION_SP_APP_ID=$(az ad app create --display-name "${SUBSCRIPTION_SP_NAME}" --required-resource-accesses @sub-app-manifest.json  --identifier-uri http://${SUBSCRIPTION_SP_NAME} --query appId -o tsv)
SUBSCRIPTION_SP_OBJECT_ID=$(az ad sp create --id ${SUBSCRIPTION_SP_APP_ID} --query objectId -o tsv)
SUBSCRIPTION_SP=$(az ad sp credential reset --name ${SUBSCRIPTION_SP_NAME})

# Principal **** does not exist in the directory ****.
sleep 10
az role assignment create  --assignee http://${SUBSCRIPTION_SP_NAME} --role Reader
az ad app permission admin-consent --id ${SUBSCRIPTION_SP_APP_ID}

SUBSCRIPTION_SP_APP_ID=$(echo ${SUBSCRIPTION_SP} | jq -r .appId)
SUBSCRIPTION_SP_APP_PASSWORD=$(echo ${SUBSCRIPTION_SP} | jq -r .password)

addKeyvaultFullAccessPolicySP ${VAULT_NAME} http://${SUBSCRIPTION_SP_NAME}

keyvaultSecretSet "sp-app-id" ${SUBSCRIPTION_SP_APP_ID}
keyvaultSecretSet "sp-object-id" ${SUBSCRIPTION_SP_OBJECT_ID}
keyvaultSecretSet "sp-app-password" ${SUBSCRIPTION_SP_APP_PASSWORD}

./generate-ssh-key.sh ${VAULT_NAME}

echo "Server app ID: ${SERVER_APP_ID}"
echo "Server app password: ${SERVER_APP_PASSWORD}"
echo "Server app display name: ${SERVER_APP_DISPLAY_NAME}"

echo "Client app ID: ${CLIENT_APP_ID}"
echo "Client app display name: ${CLIENT_APP_DISPLAY_NAME}"

echo "AKS SP client id: ${AKS_SP_APP_ID}"
echo "AKS SP client secret: ${AKS_SP_APP_PASSWORD}"

echo "Subscription SP app ID: ${SUBSCRIPTION_SP_APP_ID}"
echo "Subscription SP app password: ${SUBSCRIPTION_SP_APP_PASSWORD}"
