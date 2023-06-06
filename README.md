# Purpose

Playing with Azure SQL DB, Azure Functions, Managed Identities, and database server's roles.

# Build and Deploy

/!\ Update `serverAdmin` resource in the Bicep file.

```powershell
az login

$subscription = "Training Subscription"
az account set --subscription $subscription

$rgName = "frbar-sqldb-mi"
$envName = "frbarmi001"
$location = "West Europe"

function Deploy-Infra() { 
    az group create --name $rgName --location $location
    az deployment group create --resource-group $rgName --template-file infra.bicep --mode complete --parameters envName=$envName    
}

function Build-And-Publish() { 
    remove-item publish\* -recurse -force
    dotnet publish src\ -c Release -o publish
    Compress-Archive publish\* publish.zip -Force
    az functionapp deployment source config-zip --src .\publish.zip -n "$($envName)-func" -g $rgName
}

Deploy-Infra
Build-And-Publish

```

# Tear down

```powershell
az group delete --name $rgName
```

## SQL DB credentials

- Setup an Azure AD admin on the Azure SQL Server.
- Configure accordingly network restrictions.
- Connect to the Azure SQL Server using AAD
- Execute these queries on the `master` database: 
```
CREATE LOGIN [<envName>-func-identity] FROM EXTERNAL PROVIDER;

ALTER SERVER ROLE ##MS_DatabaseConnector## ADD MEMBER [<envName>-func-identity];
ALTER SERVER ROLE ##MS_DatabaseManager## ADD MEMBER [<envName>-func-identity];
```
