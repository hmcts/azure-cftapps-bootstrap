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

## Running the script: 

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
./run.sh <env-name> <subscription>
```

Where the `<subscription>` = cftapps, mgmt or papi

If there's an error and you need to re-run you can add the `--force` argument, do not use this on an in use subscription as it will delete the SP and applications needed for AKS to function:

```bash
./run.sh --force <env-name> <subscription>
```

Where the `<subscription>` = cftapps, mgmt or papi

## GitHub secrets:

GitHub users need to be created manually
The format is:

Username: hmcts-flux-env
Email: flux-env@hmcts.net

Email address is made by creating a group in office 365 and after creation updating it to allow external email addresses to send to it

You'll need to enable 2FA on the account, copy the recovery codes to a file on your machine
Set the users avatar to have the flux.png image that's stored in this repo

Generate a private key with:
```
$ ssh-keygen -f ~/.ssh/hmcts-flux-env
```

Upload the public key to the users github account

Ask someone with [GitHub owner permission](https://github.com/orgs/hmcts/people?utf8=%E2%9C%93&query=+role%3Aowner) to add the user to the organisation in the [Flux](https://github.com/orgs/hmcts/teams/flux/members) team 

Then store all the values in the subscription key vault with the following script:
```
$ ./set-github-secrets
usage: ./set-github-secrets <subscription-display-name> <key_vault> <username> <password> <private_key_path> <recovery_tokens_path>
```
e.g.
```
$ ./set-github-secrets DCD-MGMT-SBOX mgmt-sbox hmcts-flux-mgmt-sandbox "the-user-password" ~/.ssh/flux-mgmt-sandbox /tmp/recovery-tokens
```

## Azure DevOps service connection:
Install the azure devops cli extension
```
$ az extension add --name azure-devops
```

Run:
```bash
$ ./create-service-connection.sh
usage: ./create-service-connection.sh <subscription-display-name> <key_vault>
```

e.g.
```bash
$ ./create-service-connection.sh DCD-CFTAPPS-ITHC cftapps-ithc
```

If you need to re-run it you can add the `--force` flag after the script name.
