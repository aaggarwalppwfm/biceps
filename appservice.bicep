// appservice.bicep

@allowed(['dev', 'prod'])
param environment string

param appServiceName string
param appServicePlanName string
param location string
param runtimeStack string
param appSettings array = []
param tags object = {}
param enableAppInsights bool = true

var appNameWithoutPrefix = replace(appServiceName, '^(app|func)-ppwfm-', '')
var appInsightsName = 'appi-ppwfm-${appNameWithoutPrefix}'

resource appInsights 'Microsoft.Insights/components@2020-02-02' = if (enableAppInsights) {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

// Build final app settings array
var finalAppSettings = [
  // Always add WEBSITE_RUN_FROM_PACKAGE = 1
  {
    name: 'WEBSITE_RUN_FROM_PACKAGE'
    value: '1'
  }

  // Conditionally inject AppInsights settings
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

  // Add any additional user-supplied app settings
  ...appSettings
]

resource appService 'Microsoft.Web/sites@2022-03-01' = {
  name: appServiceName
  location: location
  tags: tags
  properties: {
    serverFarmId: appServicePlanName
    siteConfig: {
      appSettings: finalAppSettings
      linuxFxVersion: contains(runtimeStack, 'DOTNETCORE') ? runtimeStack : null
      netFrameworkVersion: contains(runtimeStack, 'v') ? runtimeStack : null
      alwaysOn: environment == 'prod'
    }
    httpsOnly: true
  }
}

output appServiceId string = appService.id
output appInsightsId string = enableAppInsights ? appInsights.id : ''
