@allowed(['dev', 'prod'])
param environment string

param appServiceName string
param appServicePlanName string
param location string
param runtimeStack string
param appSettings array = []
param connectionStrings array = []
param tags object = {}
param enableAppInsights bool = true
param virtualNetworkSubnetId string = ''

var appInsightsName = 'appi-${appServiceName}'

// App Insights (optional)
resource appInsights 'Microsoft.Insights/components@2020-02-02' = if (enableAppInsights) {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

// App settings
var finalAppSettings = [
  {
    name: 'WEBSITE_RUN_FROM_PACKAGE'
    value: '1'
  }
  ...(enableAppInsights ? [
    {
      name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
      value: appInsights.properties.InstrumentationKey
    }
    {
      name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
      value: appInsights.properties.ConnectionString
    }
    {
      name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
      value: '~3'
    }
  ] : [])
  ...appSettings
]

// Detect platform
var isLinux = contains(toLower(runtimeStack), 'dotnetcore')

resource appService 'Microsoft.Web/sites@2022-03-01' = {
  name: appServiceName
  location: location
  kind: isLinux ? 'app,linux' : 'app'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanName
    reserved: isLinux
    httpsOnly: true
    clientAffinityEnabled: true
    clientCertEnabled: false
    clientCertMode: 'Optional'
    minTlsVersion: '1.2'
    scmMinTlsVersion: '1.2'
    siteConfig: {
      appSettings: finalAppSettings
      connectionStrings: connectionStrings
      linuxFxVersion: isLinux ? runtimeStack : null
      netFrameworkVersion: !isLinux && contains(runtimeStack, 'v') ? runtimeStack : null
      alwaysOn: environment == 'prod'
      http20Enabled: true
      healthCheckPath: '/health'
      metadata: [
        {
          name: 'CURRENT_STACK'
          value: isLinux ? 'dotnetcore' : 'dotnet'
        }
      ]
    }
    virtualNetworkSubnetId: virtualNetworkSubnetId
  }
}

output appServiceId string = appService.id
output appInsightsId string = enableAppInsights ? appInsights.id : ''
