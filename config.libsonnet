{
  _config+:: {
    local this = self,

    envoySelector: 'job=~".*"',

    // Default datasource name
    datasourceName: 'default',

    // Opt-in to multiCluster dashboards by overriding this and the clusterLabel.
    showMultiCluster: false,
    clusterLabel: 'cluster',

    grafanaUrl: 'https://grafana.com',

    dashboardIds: {
      'envoy-overview': 'envoy-overview-skj2',
      'envoy-upstream': 'envoy-upstream-skj2',
      'envoy-downstream': 'envoy-downstream-skj2',
    },
    dashboardUrls: {
      'envoy-overview': '%s/d/%s/envoy-overview' % [this.grafanaUrl, this.dashboardIds['envoy-overview']],
      'envoy-upstream': '%s/d/%s/envoy-upstream' % [this.grafanaUrl, this.dashboardIds['envoy-upstream']],
      'envoy-downstream': '%s/d/%s/envoy-downstream' % [this.grafanaUrl, this.dashboardIds['envoy-downstream']],
    },

    tags: ['envoy', 'envoy-mixin', 'gateway'],

    // Envoy alert configuration
    alerts: {
      enabled: true,
      ignoredClusters: '',

      upstream4xxErrorRate: {
        enabled: true,
        severity: 'info',
        interval: '5m',
        threshold: '5',  // percent
        minErrors: '5',  // minimum number of errors per second to trigger alert
      },

      upstream5xxErrorRate: {
        enabled: true,
        severity: 'critical',
        interval: '5m',
        threshold: '5',  // percent
        minErrors: '5',  // minimum number of errors per second to trigger alert
      },

      circuitBreakerOpen: {
        enabled: true,
        severity: 'warning',
        interval: '5m',
      },
    },

    // Custom annotations to display in graphs
    annotation: {
      enabled: false,
      name: 'Custom Annotation',
      tags: [],
      datasource: '-- Grafana --',
      iconColor: 'blue',
      type: 'tags',
    },
  },
}
