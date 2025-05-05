@allowed(['dev', 'prod'])
param environment string

param appServiceName string
param appServicePlanName string
param location string
param runtimeStack string  // e.g., 'DOTNETCORE|7.0' or 'v4.0'
param appSettings array = []
param tags object = {}
param enableAppInsights bool = true

var appInsightsName = 'appi-${appServiceName}'

// App Insights resource (optional)
resource appInsights 'Microsoft.Insights/components@2020-02-02' = if (enableAppInsights) {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

// Build final app settings
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

// Determine if Linux or Windows
var isLinux = contains(toLower(runtimeStack), 'dotnetcore')

// App Service
resource appService 'Microsoft.Web/sites@2022-03-01' = {
  name: appServiceName
  location: location
  kind: isLinux ? 'app,linux' : 'app'
  tags: tags
  properties: {
    serverFarmId: appServicePlanName
    siteConfig: {
      appSettings: finalAppSettings
      alwaysOn: environment == 'prod'
      linuxFxVersion: isLinux ? runtimeStack : null
      netFrameworkVersion: !isLinux && contains(runtimeStack, 'v') ? runtimeStack : null
    }
    httpsOnly: true
    reserved: isLinux  // required for Linux App Services
  }
}

output appServiceId string = appService.id
output appInsightsId string = enableAppInsights ? appInsights.id : ''
