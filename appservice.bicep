// appservice.bicep

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

resource appService 'Microsoft.Web/sites@2022-03-01' = {
  name: appServiceName
  location: location
  tags: tags
  properties: {
    serverFarmId: appServicePlanName
    siteConfig: {
      appSettings: enableAppInsights ? [
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
      ] + appSettings : appSettings
      linuxFxVersion: contains(runtimeStack, 'DOTNETCORE') ? runtimeStack : null
      netFrameworkVersion: contains(runtimeStack, 'v') ? runtimeStack : null
    }
    httpsOnly: true
  }
}

output appServiceId string = appService.id
output appInsightsId string = enableAppInsights ? appInsights.id : ''
