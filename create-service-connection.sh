#!/bin/bash
set -e

if [ "${1}" == "--force" ] || [ "${1}" == "-f" ] ; then
  DELETE_NON_IDEMPOTENT_RESOURCES="true"
  shift
else
  DELETE_NON_IDEMPOTENT_RESOURCES="false"
fi

SUBSCRIPTION_DISPLAY_NAME=${1}
KEY_VAULT=${2}

function usage() {
  echo "usage: ./create-service-connection.sh <subscription-display-name> <key_vault>"
}

if [ -z "${SUBSCRIPTION_DISPLAY_NAME}" ] || [ -z "${KEY_VAULT}" ] ; then
  usage
  exit 1
fi

function keyvault_secret_show() {
  local SECRET=${1}
  az keyvault secret show --vault-name ${KEY_VAULT} --name ${SECRET} --subscription ${SUBSCRIPTION_DISPLAY_NAME} -o tsv --query value
}

SP_APP_ID=$(keyvault_secret_show sp-app-id)
export AZURE_DEVOPS_EXT_AZURE_RM_SERVICE_PRINCIPAL_KEY=$(keyvault_secret_show sp-app-password)

SUBSCRIPTION_ID=$(az account list --query "[?name=='${SUBSCRIPTION_DISPLAY_NAME}'].id" -o tsv)
TENANT_ID=$(az account list --query "[?name=='${SUBSCRIPTION_DISPLAY_NAME}'].tenantId" -o tsv)

if [ ${DELETE_NON_IDEMPOTENT_RESOURCES} == "true" ]; then
  ID=$(az devops service-endpoint list --organization https://dev.azure.com/hmcts/ --project CNP --query "[?name=='${SUBSCRIPTION_DISPLAY_NAME}'].id" -o tsv)
  if [ -z ${ID} ] ; then
    echo "Connection doesn't exist, continuing"
  else
    az devops service-endpoint delete --id ${ID} --organization https://dev.azure.com/hmcts/ --project CNP --yes
  fi
fi

az devops service-endpoint create --name ${SUBSCRIPTION_DISPLAY_NAME} \
 --service-endpoint-type azurerm \
 --authorization-scheme ServicePrincipal  \
 --azure-rm-tenant-id ${TENANT_ID} \
 --azure-rm-service-principal-id ${SP_APP_ID} \
 --azure-rm-subscription-id ${SUBSCRIPTION_ID} \
 --project CNP \
 --organization https://dev.azure.com/hmcts/ \
 --azure-rm-subscription-name ${SUBSCRIPTION_DISPLAY_NAME}
