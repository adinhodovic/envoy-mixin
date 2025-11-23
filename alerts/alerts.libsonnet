{
  local clusterVariableQueryString = if $._config.showMultiCluster then '&var-%(clusterLabel)s={{ $labels.%(clusterLabel)s}}' % $._config else '',
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'envoy',
        rules: if $._config.alerts.enabled then std.prune([
          if $._config.alerts.upstream4xxErrorRate.enabled then {
            alert: 'EnvoyUpstreamHighHttp4xxErrorRate',
            expr: |||
              (
                sum(
                  rate(
                    envoy_cluster_upstream_rq_xx{
                      %(envoySelector)s,
                      envoy_response_code_class="4",
                      envoy_cluster_name!~"%(ignoredClusters)s"
                    }[%(interval)s]
                  )
                ) by (%(clusterLabel)s, namespace, envoy_cluster_name)
                /
                sum(
                  rate(
                    envoy_cluster_upstream_rq_total{
                      %(envoySelector)s,
                      envoy_cluster_name!~"%(ignoredClusters)s"
                    }[%(interval)s]
                  )
                ) by (%(clusterLabel)s, namespace, envoy_cluster_name)
                * 100
              ) > %(threshold)s
              and
              sum(
                rate(
                  envoy_cluster_upstream_rq_xx{
                    %(envoySelector)s,
                    envoy_response_code_class="4",
                    envoy_cluster_name!~"%(ignoredClusters)s"
                  }[%(interval)s]
                )
              ) by (%(clusterLabel)s, namespace, envoy_cluster_name)
              > %(minErrors)s
            ||| % (
              $._config
              {
                ignoredClusters: $._config.alerts.ignoredClusters,
                interval: $._config.alerts.upstream4xxErrorRate.interval,
                threshold: $._config.alerts.upstream4xxErrorRate.threshold,
                minErrors: $._config.alerts.upstream4xxErrorRate.minErrors,
              }
            ),
            'for': '1m',
            labels: {
              severity: $._config.alerts.upstream4xxErrorRate.severity,
            },
            annotations: {
              summary: 'Envoy upstream high HTTP 4xx error rate.',
              description: 'More than %(threshold)s%% HTTP requests with status 4xx for cluster {{ $labels.envoy_cluster_name }} in {{ $labels.namespace }} the past %(interval)s.' % $._config.alerts.upstream4xxErrorRate,
              dashboard_url: $._config.dashboardUrls['envoy-upstream'] + '?var-namespace={{ $labels.namespace }}&var-envoy_cluster_name={{ $labels.envoy_cluster_name }}' + clusterVariableQueryString,
            },
          },
          if $._config.alerts.upstream5xxErrorRate.enabled then {
            alert: 'EnvoyUpstreamHighHttp5xxErrorRate',
            expr: |||
              (
                sum(
                  rate(
                    envoy_cluster_upstream_rq_xx{
                      %(envoySelector)s,
                      envoy_response_code_class="5",
                      envoy_cluster_name!~"%(ignoredClusters)s"
                    }[%(interval)s]
                  )
                ) by (%(clusterLabel)s, namespace, envoy_cluster_name)
                /
                sum(
                  rate(
                    envoy_cluster_upstream_rq_total{
                      %(envoySelector)s,
                      envoy_cluster_name!~"%(ignoredClusters)s"
                    }[%(interval)s]
                  )
                ) by (%(clusterLabel)s, namespace, envoy_cluster_name)
                * 100
              ) > %(threshold)s
              and
              sum(
                rate(
                  envoy_cluster_upstream_rq_xx{
                    %(envoySelector)s,
                    envoy_response_code_class="5",
                    envoy_cluster_name!~"%(ignoredClusters)s"
                  }[%(interval)s]
                )
              ) by (%(clusterLabel)s, namespace, envoy_cluster_name)
              > %(minErrors)s
            ||| % (
              $._config
              {
                ignoredClusters: $._config.alerts.ignoredClusters,
                interval: $._config.alerts.upstream5xxErrorRate.interval,
                threshold: $._config.alerts.upstream5xxErrorRate.threshold,
                minErrors: $._config.alerts.upstream5xxErrorRate.minErrors,
              }
            ),
            'for': '1m',
            labels: {
              severity: $._config.alerts.upstream5xxErrorRate.severity,
            },
            annotations: {
              summary: 'Envoy upstream high HTTP 5xx error rate.',
              description: 'More than %(threshold)s%% HTTP requests with status 5xx for cluster {{ $labels.envoy_cluster_name }} in {{ $labels.namespace }} the past %(interval)s.' % $._config.alerts.upstream5xxErrorRate,
              dashboard_url: $._config.dashboardUrls['envoy-upstream'] + '?var-namespace={{ $labels.namespace }}&var-envoy_cluster_name={{ $labels.envoy_cluster_name }}' + clusterVariableQueryString,
            },
          },
          if $._config.alerts.circuitBreakerOpen.enabled then {
            alert: 'EnvoyCircuitBreakerOpen',
            expr: |||
              sum(
                (
                  envoy_cluster_circuit_breakers_default_rq_open{
                    %(envoySelector)s,
                    envoy_cluster_name!~"%(ignoredClusters)s"
                  }
                  or
                  envoy_cluster_circuit_breakers_default_cx_open{
                    %(envoySelector)s,
                    envoy_cluster_name!~"%(ignoredClusters)s"
                  }
                  or
                  envoy_cluster_circuit_breakers_default_cx_pool_open{
                    %(envoySelector)s,
                    envoy_cluster_name!~"%(ignoredClusters)s"
                  }
                )
              ) by (%(clusterLabel)s, namespace, envoy_cluster_name) > 0
            ||| % (
              $._config
              {
                ignoredClusters: $._config.alerts.ignoredClusters,
              }
            ),
            'for': $._config.alerts.circuitBreakerOpen.interval,
            labels: {
              severity: $._config.alerts.circuitBreakerOpen.severity,
            },
            annotations: {
              summary: 'Envoy circuit breaker is open.',
              description: 'Circuit breaker is open for cluster {{ $labels.envoy_cluster_name }} in {{ $labels.namespace }} for the past %(interval)s.' % $._config.alerts.circuitBreakerOpen,
              dashboard_url: $._config.dashboardUrls['envoy-upstream'] + '?var-namespace={{ $labels.namespace }}&var-envoy_cluster_name={{ $labels.envoy_cluster_name }}' + clusterVariableQueryString,
            },
          },
          if $._config.alerts.upstreamConnectionFailures.enabled then {
            alert: 'EnvoyUpstreamConnectionFailures',
            expr: |||
              sum(
                increase(
                  envoy_cluster_upstream_cx_connect_fail{
                    %(envoySelector)s,
                    envoy_cluster_name!~"%(ignoredClusters)s"
                  }[%(interval)s]
                )
              ) by (%(clusterLabel)s, namespace, envoy_cluster_name)
              > %(threshold)s
            ||| % (
              $._config
              {
                ignoredClusters: $._config.alerts.ignoredClusters,
                interval: $._config.alerts.upstreamConnectionFailures.interval,
                threshold: $._config.alerts.upstreamConnectionFailures.threshold,
              }
            ),
            'for': '10m',
            labels: {
              severity: $._config.alerts.upstreamConnectionFailures.severity,
            },
            annotations: {
              summary: 'Envoy upstream connection failures detected.',
              description: 'More than %(threshold)s connection failures for cluster {{ $labels.envoy_cluster_name }} in {{ $labels.namespace }} the past %(interval)s.' % $._config.alerts.upstreamConnectionFailures,
              dashboard_url: $._config.dashboardUrls['envoy-upstream'] + '?var-namespace={{ $labels.namespace }}&var-envoy_cluster_name={{ $labels.envoy_cluster_name }}' + clusterVariableQueryString,
            },
          },
          if $._config.alerts.upstreamUnhealthyHosts.enabled then {
            alert: 'EnvoyUpstreamUnhealthyHosts',
            expr: |||
              (
                sum(
                  envoy_cluster_membership_total{
                    %(envoySelector)s,
                    envoy_cluster_name!~"%(ignoredClusters)s"
                  }
                ) by (%(clusterLabel)s, namespace, envoy_cluster_name)
                -
                sum(
                  envoy_cluster_membership_healthy{
                    %(envoySelector)s,
                    envoy_cluster_name!~"%(ignoredClusters)s"
                  }
                ) by (%(clusterLabel)s, namespace, envoy_cluster_name)
              )
              /
              sum(
                envoy_cluster_membership_total{
                  %(envoySelector)s,
                  envoy_cluster_name!~"%(ignoredClusters)s"
                }
              ) by (%(clusterLabel)s, namespace, envoy_cluster_name)
              * 100
              > %(threshold)s
            ||| % (
              $._config
              {
                ignoredClusters: $._config.alerts.ignoredClusters,
                threshold: $._config.alerts.upstreamUnhealthyHosts.threshold,
              }
            ),
            'for': $._config.alerts.upstreamUnhealthyHosts.interval,
            labels: {
              severity: $._config.alerts.upstreamUnhealthyHosts.severity,
            },
            annotations: {
              summary: 'Envoy upstream has unhealthy hosts.',
              description: 'More than %(threshold)s%% of hosts are unhealthy for cluster {{ $labels.envoy_cluster_name }} in {{ $labels.namespace }} for the past %(interval)s.' % $._config.alerts.upstreamUnhealthyHosts,
              dashboard_url: $._config.dashboardUrls['envoy-upstream'] + '?var-namespace={{ $labels.namespace }}&var-envoy_cluster_name={{ $labels.envoy_cluster_name }}' + clusterVariableQueryString,
            },
          },
        ]),
      },
    ],
  },
}
