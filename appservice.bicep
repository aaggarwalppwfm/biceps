// appservice.bicep

param appServiceName string
param appServicePlanName string
param location string
param runtimeStack string
param appSettings object = {}
param tags object = {}
param enableAppInsights bool = true

var appNameWithoutPrefix = replace(appServiceName, '^(app|func)-ppwfm-', '')
var appInsightsName = 'appi-ppwfm-${appNameWithoutPrefix}'

var appSettingsArray = empty(appSettings) ? [] : [
  for k in union([], keys(appSettings)): {
    name: k
    value: appSettings[k]
  }
]

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
      appSettings: [
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
      ] + appSettingsArray
      linuxFxVersion: contains(runtimeStack, 'DOTNETCORE') ? runtimeStack : null
      netFrameworkVersion: contains(runtimeStack, 'v') ? runtimeStack : null
    }
    httpsOnly: true
  }
}

output appServiceId string = appService.id
output appInsightsId string = enableAppInsights ? appInsights.id : ''
