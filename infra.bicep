targetScope = 'resourceGroup'

param tenantId string = subscription().tenantId

param envName string

@description('Location for all resources.')
param location string = resourceGroup().location

@description('The administrator password of the SQL logical server.')
@secure()
param administratorLoginPassword string

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${envName}-appinsights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

//
// Database
//

resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: '${envName}-sqlserver'
  location: location
  properties: {
    administratorLogin: 'sqladmin_${uniqueString(envName)}'
    administratorLoginPassword: administratorLoginPassword
  }
}

resource sqlServerFirewallRules 'Microsoft.Sql/servers/firewallRules@2022-05-01-preview' = {
  name: 'allow-azure'
  parent: sqlServer
  properties: {
    endIpAddress: '0.0.0.0'
    startIpAddress: '0.0.0.0'
  }
}

resource sqlDb 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  parent: sqlServer
  name: '${envName}-db'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
}

resource serverAdmin 'Microsoft.Sql/servers/administrators@2022-05-01-preview' = {
  name: 'ActiveDirectory'
  parent: sqlServer
  properties: {
    administratorType: 'ActiveDirectory'
    login: 'xxx@xxx.xxx'
    sid: 'xxx'
    tenantId: tenantId
  }
}

//
// Function App
//

resource funcStorageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: '${envName}func'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'Storage'
}

resource hostingPlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: '${envName}-plan'
  location: location
  kind: 'windows'
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    //reserved: true     // required for using linux
  }
}

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${envName}-func-identity'
  location: location
}

var identityId = userAssignedIdentity.id

resource functionApp 'Microsoft.Web/sites@2018-11-01' = {
  name: '${envName}-func'
  location: location
  kind: 'functionapp'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      windowsFxVersion:'DOTNET|6.0'
      //alwaysOn: true  // not available on consumption
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${funcStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${funcStorageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'false'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${funcStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${funcStorageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: '${envName}-func'   
        }        
        {
          name: 'DeploymentEnvironmentName'
          value: envName
        } 
        {
          name: 'ManagedIdentityClientId'
          value: userAssignedIdentity.properties.clientId
        } 
        {
          name: 'ServerName'
          value: sqlServer.properties.fullyQualifiedDomainName
        }        
      ]
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
    }
    httpsOnly: true
  }
}
