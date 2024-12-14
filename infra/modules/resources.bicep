// Parameters
param location string
param appServicePlanSku string
param appServiceName string
param storageAccountName string
param keyVaultName string
param speechServiceName string

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

// App Service
resource appService 'Microsoft.Web/sites@2021-02-01' = {
  name: appServiceName
  location: location
  serverFarmId: appServicePlan.id
  kind: 'app'
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
resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-04-01' = {
  parent: storageAccount
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
    accessPolicies: []
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
output appServiceEndpoint string = appService.defaultHostName
output storageAccountEndpoint string = storageAccount.properties.primaryEndpoints.blob
output keyVaultUri string = keyVault.properties.vaultUri
output speechServiceEndpoint string = speechService.properties.endpoint
