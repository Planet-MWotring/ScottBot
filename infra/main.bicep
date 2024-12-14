// Parameters
param location string = resourceGroup().location
param appServicePlanSku string = 'P1v2'
param appServiceName string
param storageAccountName string
param keyVaultName string
param speechServiceName string

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroup().name
  location: location
}

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: '${appServiceName}-plan'
  location: location
  sku: {
    name: appServicePlanSku
    tier: 'PremiumV2'
  }
  kind: 'app'
}

// App Service with Managed Identity
resource appService 'Microsoft.Web/sites@2021-02-01' = {
  name: appServiceName
  location: location
  serverFarmId: appServicePlan.id
  kind: 'app'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
  }
}

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }
}

// Blob Container
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2021-04-01' = {
  parent: storageAccount
  name: 'default'
}

resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = {
  parent: blobService
  name: 'audiofiles'
  properties: {
    publicAccess: 'None'
  }
}

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: appService.identity.principalId
        permissions: {
          secrets: [
            'get','list'
          ]
        }
      }
    ]
  }
}

// Azure Speech Service
resource speechService 'Microsoft.CognitiveServices/accounts@2017-04-18' = {
  name: speechServiceName
  location: location
  sku: {
    name: 'S0'
  }
  kind: 'SpeechServices'
  properties: {
    apiProperties: {
      qnaRuntimeEndpoint: 'https://westus.api.cognitive.microsoft.com/sts/v1.0/issuetoken'
    }
  }
}

// Outputs
output appServiceEndpoint string = appService.properties.defaultHostName
output storageAccountEndpoint string = storageAccount.properties.primaryEndpoints.blob
output keyVaultUri string = keyVault.properties.vaultUri
output speechServiceEndpoint string = speechService.properties.endpoint
