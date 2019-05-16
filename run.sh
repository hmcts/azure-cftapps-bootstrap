#!/usr/bin/env bash

set -e

if [ "${1}" == "--force" ] || [ "${1}" == "-f" ] ; then
  DELETE_NON_IDEMPOTENT_RESOURCES="true"
  shift
else
  DELETE_NON_IDEMPOTENT_RESOURCES="false"
fi

case "${1}" in
	"sbox"|"SBOX"|"Sbox")
		$ENV="sbox";;
	*)
		echo "Invalid environment. Exiting"
		exit 1
		;;
esac

case "${2}" in
	"cftapps"|"CFTAPPS"|"CftApps")
		$SUB="cftapps";;
	"mgmt"|"MGMT"|"Mgmt")
		$SUB="mgmt";;
	"papi"|"PAPI"|"Papi")
		$SUB="papi";;
	*)
		echo "Invalid subscription. Exiting"
		exit 1
		;;
esac

SERVER_APP_NAME="dcd_app_aks_${SUB}_${ENV}_server_v2"
CLIENT_APP_NAME="dcd_app_aks_${SUB}_${ENV}_client_v2"
SUBSCRIPTION_SP_NAME="http://dcd_sp_sub_${SUB}_${ENV}_v2"
AKS_SP_NAME="http://dcd_sp_aks_${SUB}_${ENV}_v2"

CORE_INFRA_RG="core-infra-${ENV}"
VAULT_NAME="${SUB}-${ENV}"
LOCATION="uksouth"

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

az group create --location ${LOCATION} --name ${CORE_INFRA_RG} --tags "Team Name=Software Engineering" environment=${ENV}

az storage account create --name cftapps${ENV//-/} \
  --resource-group ${CORE_INFRA_RG} \
  --sku Standard_LRS \
  --encryption-services blob \
  --kind StorageV2 \
  --location ${LOCATION} \
  --tags "Team Name=Software Engineering" environment=${ENV} \
  --https-only true

az keyvault create --name ${VAULT_NAME} \
  --resource-group ${CORE_INFRA_RG}  \
  --location ${LOCATION} \
  --enable-purge-protection true \
  --enable-soft-delete true \
  --enabled-for-deployment true  \
  --tags "Team Name=Software Engineering" environment=${ENV} \
  --enabled-for-template-deployment true
  
# addKeyvaultFullAccessPolicy ${VAULT_NAME} 9189d86a-e260-4c3d-8227-803123cdce84 # aks-cluster-admins - for RPE tenant

addKeyvaultFullAccessPolicy ${VAULT_NAME} 300e771f-856c-45cc-b899-40d78281e9c1 # devops
addKeyvaultFullAccessPolicy ${VAULT_NAME} c36eaede-a0ae-4967-8fed-0a02960b1370 # platform-engineering

SERVER_APP_PASSWORD=$(openssl rand -base64 32 | grep -o  '[[:alnum:]]' | tr -d '\n')

if [ ${DELETE_NON_IDEMPOTENT_RESOURCES} == "true" ]; then
  az ad app delete --id http://${SERVER_APP_NAME} || true
fi

export SERVER_APP_ID=$(az ad app create --display-name ${SERVER_APP_NAME} --required-resource-accesses @server-manifest.json  --identifier-uri http://${SERVER_APP_NAME} --password ${SERVER_APP_PASSWORD} --query appId -o tsv)
SERVER_SP_OBJECT_ID=$(az ad sp create --id ${SERVER_APP_ID} --query objectId -o tsv)

keyvaultSecretSet "aks-server-sp-object-id" ${SERVER_SP_OBJECT_ID}
keyvaultSecretSet "aks-server-app-id" ${SERVER_APP_ID}
keyvaultSecretSet "aks-server-app-password" ${SERVER_APP_PASSWORD}

echo "Ignore the warning about \"Property 'groupMembershipClaims' not found on root\""
az ad app update --id ${SERVER_APP_ID} --set groupMembershipClaims=All

sed "s/%%SERVER_APP_ID%%/${SERVER_APP_ID}/g" client-manifest.template.json > client-manifest.json
sleep 3

az ad app permission admin-consent --id ${SERVER_APP_ID}

CLIENT_APP_ID=$(az ad app create --display-name ${CLIENT_APP_NAME} --native-app --reply-urls http://localhost/client https://ininprodeusuxbase.microsoft.com/* --required-resource-accesses @client-manifest.json  --query appId -o tsv)
CLIENT_SP_OBJECT_ID=$(az ad sp create --id ${CLIENT_APP_ID} --query objectId -o tsv)

keyvaultSecretSet "aks-client-sp-object-id" ${CLIENT_SP_OBJECT_ID}
keyvaultSecretSet "aks-client-app-id" ${CLIENT_APP_ID}

# without the sleep I was getting: 
# Operation failed with status: 'Bad Request'. Details: 400 Client Error: Bad Request for url: https://graph.windows.net/a0d77fc4-df1e-4b0d-8e35-46750ca5a672/oauth2PermissionGrants?api-version=1.6
sleep 5

az ad app permission grant --id ${CLIENT_SP_OBJECT_ID} --api ${SERVER_APP_ID}

if [ ${DELETE_NON_IDEMPOTENT_RESOURCES} == "true" ]; then
  az ad sp delete --id ${AKS_SP_NAME} || true
fi

AKS_SP=$(az ad sp create-for-rbac --skip-assignment --name ${AKS_SP_NAME})

AKS_SP_APP_ID=$(echo ${AKS_SP} | jq -r .appId)
AKS_SP_APP_PASSWORD=$(echo ${AKS_SP} | jq -r .password)

keyvaultSecretSet "aks-sp-app-id" ${AKS_SP_APP_ID}
keyvaultSecretSet "aks-sp-app-password" ${AKS_SP_APP_PASSWORD}

if [ ${DELETE_NON_IDEMPOTENT_RESOURCES} == "true" ]; then
  az ad sp delete --id ${SUBSCRIPTION_SP_NAME} || true
fi

SUBSCRIPTION_SP=$(az ad sp create-for-rbac --skip-assignment  --name ${SUBSCRIPTION_SP_NAME})
SUBSCRIPTION_SP_APP_ID=$(echo ${SUBSCRIPTION_SP} | jq -r .appId)
SUBSCRIPTION_SP_APP_PASSWORD=$(echo ${SUBSCRIPTION_SP} | jq -r .password)

addKeyvaultFullAccessPolicySP ${VAULT_NAME} ${SUBSCRIPTION_SP_NAME}

keyvaultSecretSet "sp-app-id" ${SUBSCRIPTION_SP_APP_ID}
keyvaultSecretSet "sp-app-password" ${SUBSCRIPTION_SP_APP_PASSWORD}

echo "Server app ID: ${SERVER_APP_ID}"
echo "Server app password: ${SERVER_APP_PASSWORD}"
echo "Server app display name: ${SERVER_APP_NAME}"

echo "Client app ID: ${CLIENT_APP_ID}"
echo "Client app display name: ${CLIENT_APP_NAME}"

echo "AKS SP client id: ${AKS_SP_APP_ID}"
echo "AKS SP client secret: ${AKS_SP_APP_PASSWORD}"

echo "Subscription SP app ID: ${SUBSCRIPTION_SP_APP_ID}"
echo "Subscription SP app password: ${SUBSCRIPTION_SP_APP_PASSWORD}"
