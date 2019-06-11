#!/bin/bash
set -x

VAULT_NAME=${1}

set +e
az keyvault secret show --vault-name ${VAULT_NAME} --name aks-ssh-pub-key --query id

if [ $? -eq 3 ] ; then
    set -e
    TMP_DIR=$(mktemp -d)
    pushd ${TMP_DIR}

    ssh-keygen -f key -C aks-ssh -t rsa -b 2048 -q -N ""
    az keyvault secret set --vault-name ${VAULT_NAME} --name aks-ssh-pub-key --file key.pub
    az keyvault secret set --vault-name ${VAULT_NAME} --name aks-ssh-private-key --file key

    ls -la

    popd

    rm -rf ${TMP_DIR}
    else

    echo "AKS SSH key already exists in vault, skipping..."
fi

