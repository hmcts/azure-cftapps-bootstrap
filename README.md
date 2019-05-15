# azure-cftapps-bootstrap

Creates all the required infrastructure for a new cftapps subscription

Requires:
* azure-cli >= 2.0.62
* jq (brew install jq)

## What does this create?

* Key Vault for storing credentials created as part of this run
* Access policies for keyvault for subscription sp, devops and platform engineering teams
* Storage account used for storing terraform state
* 2 AD applications for AKS RBAC setup
* SP for AKS cluster operation
* SP for managing resources in the subscription - Contributor on resource group(s) assigned through ops-resource-groups

## Running the script: 

This script needs to be run from a user with GA access in Azure,
It is needed to be GA so that:
* admin consent can be given for an application
* applications can be created in AD
* SPs can be created in AD
* role assignments added - owner to subscription is sufficient for this

The user also must have their active subscription for the `azure-cli` set to the one they want to run it in
```bash
az account set -s <sub-id>
```


```bash
./run.sh <env-name>
```

If there's an error and you need to re-run you can add the `--force` argument, do not use this on an in use subscription as it will delete the SP and applications needed for AKS to function:

```bash
./run.sh --force <env-name>
```
