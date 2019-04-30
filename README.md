# azure-compute-bootstrap

Creates all the required infrastructure for a new compute subscription

Requires:
* azure-cli >= 2.0.62
* envsubst (brew install gettext && brew link --force gettext )
* jq (brew install jq)


## Role assignment setup:

Initial creation:
```bash
az role definition create --role-definition '{ \
    "Name": "Role assigner", \
    "Description": "Allows performing role assignments.", \
    "Actions": [ \
        "Microsoft.Authorization/roleAssignments/read", \
        "Microsoft.Authorization/roleAssignments/write", \
        "Microsoft.Authorization/roleAssignments/delete", \
    ], \
    "AssignableScopes": ["/subscriptions/<sub-id>"] \
}'

```

Updating it:

First find the ID:
```bash 
az role definition list --query "[?roleName=='Role assigner'].id" -o tsv
```

and the current scopes:
```bash
az role definition list --query "[?roleName=='Role assigner'].assignableScopes"
```

then replace the id and assignable scopes and replace the below:

```bash
az role definition update --role-definition '{ \
    "roleName": "Role assigner", \
    "id": "<query-for-this> e.g. /subscriptions/50f88971-400a-4855-8924-c38a47112ce4/providers/Microsoft.Authorization/roleDefinitions/d9e36deb-d0a5-47a1-9065-381822359971", \
    "roleType": "CustomRole", \
    "type": "Microsoft.Authorization/roleDefinitions", \
    "Description": "Allows performing role assignments.", \
    "Actions": [ \
        "Microsoft.Authorization/roleAssignments/read", \
        "Microsoft.Authorization/roleAssignments/write", \
        "Microsoft.Authorization/roleAssignments/delete", \
    ], \
    "AssignableScopes": ["/subscriptions/<id-1>", "/subscriptions/<id-2>"] \
}'
```

## What does this create?

* Key Vault for storing credentials created as part of this run
* Access policies for keyvault for subscription sp, devops and platform engineering teams
* Storage account used for storing terraform state
* 2 AD applications for AKS RBAC setup
* SP for AKS cluster operation
* SP for managing resources in the cluster - contributor + "Role assigner" custom role

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
./run.sh <env-name> <role-assigner-role-definition-id:
```

If there's an error and you need to re-run you can add the `--force` argument, do not use this on an in use subscription as it will delete the SP and applications needed for AKS to function:

```bash
./run.sh --force <env-name> <role-assigner-role-definition-id e.g. d9e36deb-d0a5-47a1-9065-381822359971>:
```
