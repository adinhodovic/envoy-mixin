local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local tablePanel = g.panel.table;

// Table
local tbStandardOptions = tablePanel.standardOptions;
local tbQueryOptions = tablePanel.queryOptions;
local tbPanelOptions = tablePanel.panelOptions;
local tbOverride = tbStandardOptions.override;

{
  local dashboardName = 'envoy-overview',
  grafanaDashboards+:: {
    ['%s.json' % dashboardName]:

      local defaultVariables = util.variables($._config);

      local variables = [
        defaultVariables.datasource,
        defaultVariables.cluster,
        defaultVariables.namespace,
        defaultVariables.job,
        defaultVariables.envoyClusterName,
        defaultVariables.envoyHttpConnManagerPrefix,
        defaultVariables.pod,
      ];

      local defaultFilters = util.filters($._config);
      local queries = {
        // Summary
        envoyPodsCount: |||
          count(
            count (
              envoy_cluster_upstream_rq_total{
                %(default)s
              }
            ) by (pod)
          )
        ||| % defaultFilters,

        upstreamsCount: |||
          count(
            count(
              envoy_cluster_upstream_rq_total{
                %(default)s
              }
            ) by (envoy_cluster_name)
          )
        ||| % defaultFilters,

        downstreamsCount: |||
          count(
            count(
              envoy_http_downstream_rq_total{
                %(default)s
              }
            ) by (envoy_http_conn_manager_prefix)
          )
        ||| % defaultFilters,

        membershipHealthyPercent: |||
          sum(
            envoy_cluster_membership_healthy{
              %(default)s
            }
          )
          /
          sum(
            envoy_cluster_membership_total{
              %(default)s
            }
          )
          * 100
        ||| % defaultFilters,

        downstreamActiveCx: |||
          sum(
            envoy_http_downstream_cx_active{
              %(default)s
            }
          )
        ||| % defaultFilters,

        upstreamActiveCx: |||
          sum(
            envoy_cluster_upstream_cx_active{
              %(default)s
            }
          )
        ||| % defaultFilters,

        upstreamRateByEnvoyClusterName1h: |||
          topk(20,
            sum(
              rate(
                envoy_cluster_upstream_rq_total{
                  %(upstream)s
                }[1h]
              )
            ) by (envoy_cluster_name)
          )
        ||| % defaultFilters,

        upstreamRateByCodeClass1h: |||
          sum(
            rate(
              envoy_cluster_upstream_rq_xx{
                %(upstream)s
              }[1h]
            )
          ) by (envoy_response_code_class)
        ||| % defaultFilters,

        downstreamRateByEnvoyHttpConnManagerPrefix1h: |||
          topk(20,
            sum(
              rate(
                envoy_http_downstream_rq_total{
                  %(downstream)s
                }[1h]
              )
            ) by (envoy_http_conn_manager_prefix)
          )
        ||| % defaultFilters,

        upstreamRateByPod1h: |||
          sum(
            rate(
              envoy_cluster_upstream_rq_total{
                %(upstream)s
              }[1h]
            )
          ) by (pod)
        ||| % defaultFilters,

        // Upstream
        upstreamRate: |||
          sum(
            rate(
              envoy_cluster_upstream_rq_total{
                %(upstream)s
              }[$__rate_interval]
            )
          )
        ||| % defaultFilters,

        upstreamLatencyP50: |||
          histogram_quantile(
            0.5,
            sum(
              rate(
                envoy_cluster_upstream_rq_time_bucket{
                  %(upstream)s
                }[$__rate_interval]
              )
            ) by (le)
          )
        ||| % defaultFilters,
        upstreamLatencyP95: std.strReplace(queries.upstreamLatencyP50, '0.5', '0.95'),
        upstreamLatencyP99: std.strReplace(queries.upstreamLatencyP50, '0.5', '0.99'),

        upstreamSuccessRate5xx: |||
          sum(
            rate(
              envoy_cluster_upstream_rq_xx{
                %(upstream)s,
                envoy_response_code_class!="5"
              }[$__rate_interval]
            )
          )
          /
          sum(
            rate(
              envoy_cluster_upstream_rq_xx{
                %(upstream)s
              }[$__rate_interval]
            )
          )
          * 100
        ||| % defaultFilters,
        upstreamSucessRate4xx5xx: std.strReplace(queries.upstreamSuccessRate5xx, 'envoy_response_code_class!="5"', 'envoy_response_code_class!~"4|5"'),

        upstreamRateByCodeClass: std.strReplace(queries.upstreamRateByCodeClass1h, '1h', '$__rate_interval'),
        upstreamCxActive: |||
          sum(
            envoy_cluster_upstream_cx_active{
              %(upstream)s
            }
          ) by (envoy_cluster_name)
        ||| % defaultFilters,

        // Upstream Table

        // Used to limit the table of upstream results
        upstreamRateByEnvoyClusterName1hTop40k: |||
          topk(40,
            sum(
              rate(
                envoy_cluster_upstream_rq_total{
                  %(upstream)s
                }[1h]
              )
            ) by (envoy_cluster_name)
          )
        ||| % defaultFilters,
        local upstreamRpsTop40k = {
          rpsTop40k: |||
            and on (envoy_cluster_name) (
              %s
            )
          ||| % queries.upstreamRateByEnvoyClusterName1hTop40k,
        },

        upstreamLatencyP50ByEnvoyClusterName1h: |||
          histogram_quantile(
            0.5,
            sum(
              rate(
                envoy_cluster_upstream_rq_time_bucket{
                  %(upstream)s
                }[1h]
              )
            ) by (le, job, envoy_cluster_name)
          )
          %(rpsTop40k)s
        ||| % (defaultFilters + upstreamRpsTop40k),
        upstreamLatencyP95ByEnvoyClusterName1h: std.strReplace(queries.upstreamLatencyP50ByEnvoyClusterName1h, '0.5', '0.95'),

        upstreamSuccessRate5xxByEnvoyClusterName1h: |||
          sum(
            rate(
              envoy_cluster_upstream_rq_xx{
                %(upstream)s,
                envoy_response_code_class!="5"
              }[1h]
            )
          ) by (job, envoy_cluster_name)
          /
          sum(
            rate(
              envoy_cluster_upstream_rq_xx{
                %(upstream)s
              }[1h]
            )
          ) by (job, envoy_cluster_name)
          * 100
          %(rpsTop40k)s
        ||| % (defaultFilters + upstreamRpsTop40k),
        upstreamSucessRate4xx5xxByEnvoyClusterName1h: std.strReplace(queries.upstreamSuccessRate5xxByEnvoyClusterName1h, 'envoy_response_code_class!="5"', 'envoy_response_code_class!~"4|5"'),

        upstreamActiveCxByEnvoyClusterName1h: |||
          sum(
            avg_over_time(
              envoy_cluster_upstream_cx_active{
                %(upstream)s
              }[1h]
            )
          ) by (job, envoy_cluster_name)
          %(rpsTop40k)s
        ||| % (defaultFilters + upstreamRpsTop40k),

        upstreamDestroyCxByEnvoyClusterName1h: |||
          sum(
            increase(
              envoy_cluster_upstream_cx_destroy{
                %(upstream)s
              }[1h]
            )
          ) by (job, envoy_cluster_name)
          %(rpsTop40k)s
        ||| % (defaultFilters + upstreamRpsTop40k),

        upstreamHealthyPercentByEnvoyClusterName: |||
          sum(
            envoy_cluster_membership_healthy{
              %(upstream)s
            }
          ) by (job, envoy_cluster_name)
          /
          sum(
            envoy_cluster_membership_total{
              %(upstream)s
            }
          ) by (job, envoy_cluster_name)
          * 100
          %(rpsTop40k)s
        ||| % (defaultFilters + upstreamRpsTop40k),

        // Downstream
        downstreamRateByEnvoyHttpConnManagerPrefix: |||
          topk(20,
            sum(
              rate(
                envoy_http_downstream_rq_total{
                  %(downstream)s
                }[$__rate_interval]
              )
            ) by (envoy_http_conn_manager_prefix)
          )
        ||| % defaultFilters,

        downstreamLatencyP50: |||
          histogram_quantile(
            0.5,
            sum(
              rate(
                envoy_http_downstream_rq_time_bucket{
                  %(downstream)s
                }[$__rate_interval]
              )
            ) by (le)
          )
        ||| % defaultFilters,
        downstreamLatencyP95: std.strReplace(queries.downstreamLatencyP50, '0.5', '0.95'),
        downstreamLatencyP99: std.strReplace(queries.downstreamLatencyP50, '0.5', '0.99'),

        downstreamSuccesRate5xx: |||
          sum(
            rate(
              envoy_http_downstream_rq_xx{
                %(downstream)s,
                envoy_response_code_class!="5"
              }[$__rate_interval]
            )
          )
          /
          sum(
            rate(
              envoy_http_downstream_rq_xx{
                %(downstream)s
              }[$__rate_interval]
            )
          )
          * 100
        ||| % defaultFilters,
        downstreamSucessRate4xx5xx: std.strReplace(queries.downstreamSuccesRate5xx, 'envoy_response_code_class!="5"', 'envoy_response_code_class!~"4|5"'),

        // Downstream Table

        // Used to limit the table of downstream results
        downstreamRateByEnvoyHttpConnManagerPrefix1hTop40k: |||
          topk(40,
            sum(
              rate(
                envoy_http_downstream_rq_total{
                  %(downstream)s
                }[1h]
              )
            ) by (envoy_http_conn_manager_prefix)
          )
        ||| % defaultFilters,
        local downstreamRpsTop40k = {
          rpsTop40k: |||
            and on (envoy_http_conn_manager_prefix) (
              %s
            )
          ||| % queries.downstreamRateByEnvoyHttpConnManagerPrefix1hTop40k,
        },

        downstreamLatencyP50ByEnvoyHttpConnManagerPrefix1h: |||
          histogram_quantile(
            0.5,
            sum(
              rate(
                envoy_http_downstream_rq_time_bucket{
                  %(downstream)s
                }[1h]
              )
            ) by (le, job, envoy_http_conn_manager_prefix)
          )
          %(rpsTop40k)s
        ||| % (defaultFilters + downstreamRpsTop40k),
        downstreamLatencyP95ByEnvoyHttpConnManagerPrefix1h: std.strReplace(queries.downstreamLatencyP50ByEnvoyHttpConnManagerPrefix1h, '0.5', '0.95'),

        downstreamSuccessRate5xxByEnvoyHttpConnManagerPrefix1h: |||
          sum(
            rate(
              envoy_http_downstream_rq_xx{
                %(downstream)s,
                envoy_response_code_class!="5"
              }[1h]
            )
          ) by (job, envoy_http_conn_manager_prefix)
          /
          sum(
            rate(
              envoy_http_downstream_rq_xx{
                %(downstream)s
              }[1h]
            )
          ) by (job, envoy_http_conn_manager_prefix)
          * 100
          %(rpsTop40k)s
        ||| % (defaultFilters + downstreamRpsTop40k),
        downstreamSucessRate4xx5xxByEnvoyHttpConnManagerPrefix1h: std.strReplace(queries.downstreamSuccessRate5xxByEnvoyHttpConnManagerPrefix1h, 'envoy_response_code_class!="5"', 'envoy_response_code_class!~"4|5"'),

        downstreamActiveCxByEnvoyHttpConnManagerPrefix1h: |||
          sum(
            avg_over_time(
              envoy_http_downstream_cx_active{
                %(downstream)s
              }[1h]
            )
          ) by (job, envoy_http_conn_manager_prefix)
          %(rpsTop40k)s
        ||| % (defaultFilters + downstreamRpsTop40k),

        downstreamDestroyCxByEnvoyHttpConnManagerPrefix1h: |||
          sum(
            increase(
              envoy_http_downstream_cx_destroy{
                %(downstream)s
              }[1h]
            )
          ) by (job, envoy_http_conn_manager_prefix)
          %(rpsTop40k)s
        ||| % (defaultFilters + downstreamRpsTop40k),

        // SSL
        sslExpirationsByEnvoyTlsCertificate: |||
          min(
            envoy_listener_ssl_certificate_expiration_unix_time_seconds{
              %(default)s
            }
          ) by (job, envoy_tls_certificate)
          * 1000
        ||| % defaultFilters,
      };

      local panels = {

        // Summary
        envoyPodsCountStat:
          mixinUtils.dashboards.statPanel(
            'Envoy Pods',
            'short',
            queries.envoyPodsCount,
            description='Total number of Envoy proxy pods currently being monitored. A sudden drop may indicate pod crashes or deployment issues, while increases should align with scaling events.',
          ),

        upstreamsCountStat:
          mixinUtils.dashboards.statPanel(
            'Upstreams',
            'short',
            queries.upstreamsCount,
            description='Total count of unique upstream clusters (backend services) configured across all Envoy proxies. Changes in this metric indicate service discovery updates or configuration changes.',
          ),

        downstreamsCountStat:
          mixinUtils.dashboards.statPanel(
            'Downstreams',
            'short',
            queries.downstreamsCount,
            description='Total count of downstream HTTP connection managers (ingress listeners) across all Envoy proxies. Represents the number of distinct entry points accepting client traffic.',
          ),

        upstreamActiveCxStat:
          mixinUtils.dashboards.statPanel(
            'Upstream Active Connections',
            'short',
            queries.upstreamActiveCx,
            description='Current number of active TCP connections from Envoy proxies to upstream services. High values may indicate connection pooling issues or slow backend responses. Compare with request rate to assess connection efficiency.',
          ),

        downstreamActiveCxStat:
          mixinUtils.dashboards.statPanel(
            'Downstream Active Connections',
            'short',
            queries.downstreamActiveCx,
            description='Current number of active TCP connections from clients to Envoy proxies. Sudden spikes may indicate traffic surges or slow request processing. Monitor alongside request rates to identify connection leaks.',
          ),

        membershipHealthyPercentStat:
          mixinUtils.dashboards.statPanel(
            'Membership Healthy Percent',
            'percent',
            queries.membershipHealthyPercent,
            description='Percentage of healthy upstream endpoints across all clusters based on active health checks. Values below 100% indicate failing health checks - investigate unhealthy hosts immediately as this impacts traffic distribution and availability.',
          ),

        upstreamRateByEnvoyClusterNamePieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Upstream Rate by Envoy Cluster Name [1h]',
            'reqps',
            queries.upstreamRateByEnvoyClusterName1h,
            '{{ envoy_cluster_name }}',
            description='Distribution of upstream request traffic across backend clusters over the past hour. Shows which services receive the most traffic. Use this to identify hot spots, validate load distribution, and detect unexpected traffic patterns to specific backends.',
          ),

        upstreamRateByCodeClassPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Upstream Rate by Code Class [1h]',
            'reqps',
            queries.upstreamRateByCodeClass1h,
            '{{ envoy_response_code_class }}xx',
            description='Breakdown of upstream responses by HTTP status code class (2xx, 3xx, 4xx, 5xx) over the past hour. High proportions of 4xx may indicate client errors or misconfigurations, while 5xx indicates backend failures requiring immediate attention.',
          ),

        downstreamRateByEnvoyHttpConnManagerPrefixPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Downstream Rate by Envoy HTTP Conn Manager Prefix [1h]',
            'reqps',
            queries.downstreamRateByEnvoyHttpConnManagerPrefix1h,
            '{{ envoy_http_conn_manager_prefix }}',
            description='Distribution of incoming client traffic across different HTTP connection managers (listeners) over the past hour. Helps identify which ingress points receive the most traffic and validate routing configurations.',
          ),

        upstreamRateByPodPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Upstream Rate by Pod [1h]',
            'reqps',
            queries.upstreamRateByPod1h,
            '{{ pod }}',
            description='Distribution of upstream requests across Envoy proxy pods over the past hour. Use this to verify load balancing across proxy instances and identify if specific pods are handling disproportionate traffic, which may indicate scaling or routing issues.',
          ),

        // Upstream
        upstreamRateByEnvoyClusterNameTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Upstream Rate',
            'reqps',
            queries.upstreamRate,
            'Upstream',
            description='Aggregated upstream request rate across all selected clusters over time. Shows overall backend traffic volume. Sudden drops may indicate upstream failures or circuit breaker activations. Spikes could indicate retry storms or traffic surges.',
            stack='normal',
          ),

        upstreamLatencyTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Upstream Latency',
            'ms',
            [
              {
                expr: queries.upstreamLatencyP50,
                legend: 'P50',
              },
              {
                expr: queries.upstreamLatencyP95,
                legend: 'P95',
              },
              {
                expr: queries.upstreamLatencyP99,
                legend: 'P99',
                exemplar: true,
              },
            ],
            description='Upstream request latency percentiles (P50, P95, P99) measured from Envoy to backend services. Includes connection establishment, request transmission, backend processing, and response receipt. Increasing P95/P99 often indicates backend degradation before P50 is affected. Use exemplars to trace high-latency requests.',
          ),

        upstreamSuccessRate5xxTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Upstream Success Rate (Excluding 4xx errors)',
            'percent',
            [
              {
                expr: queries.upstreamSuccessRate5xx,
                legend: 'Success Rate',
              },
            ],
            description='Percentage of successful upstream requests (non-5xx responses). This metric treats 4xx errors as successful since they typically indicate client issues, not backend failures. Values below 99.9% may indicate backend health problems. Correlate drops with circuit breaker openings and health check failures.',
            stack='normal',
            min=0,
            max=100
          ),

        upstreamSuccessRate4xx5xxTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Upstream Success Rate (Including 4xx errors)',
            'percent',
            [
              {
                expr: queries.upstreamSucessRate4xx5xx,
                legend: 'Success Rate',
              },
            ],
            description='Percentage of successful upstream requests (non-4xx/5xx responses). This stricter metric counts both client errors (4xx) and server errors (5xx) as failures. Use this to assess overall request success from an end-user perspective. Lower rates may indicate API contract issues, authentication problems, or backend failures.',
            stack='normal',
            min=0,
            max=100
          ),

        upstreamRateByCodeClassTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Upstream Rate by Code Class',
            'reqps',
            queries.upstreamRateByCodeClass,
            '{{ envoy_response_code_class }}xx',
            description='Upstream request rate broken down by HTTP status code class (2xx success, 3xx redirects, 4xx client errors, 5xx server errors). Monitor for sudden increases in 4xx (often indicates API changes or client misconfigurations) or 5xx (backend failures requiring immediate investigation).',
            stack='normal',
          ),

        upstreamCxActiveTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Upstream Active Connections',
            'connections',
            queries.upstreamCxActive,
            '{{ envoy_cluster_name }}',
            description='Number of currently active TCP connections from Envoy to each upstream cluster. Persistent high values relative to request rate may indicate connection pooling issues, HTTP/1.1 connection reuse problems, or slow-draining connections. Compare with circuit breaker limits to identify potential bottlenecks.',
            stack='normal',
          ),

        upstreamTable:
          mixinUtils.dashboards.tablePanel(
            'Upstream Overview [1h]',
            'short',
            [
              {
                expr: queries.upstreamRateByEnvoyClusterName1hTop40k,
                legend: 'Request Rate',
              },
              {
                expr: queries.upstreamSuccessRate5xxByEnvoyClusterName1h,
                legend: 'Success Rate (5xx)',
              },
              {
                expr: queries.upstreamSucessRate4xx5xxByEnvoyClusterName1h,
                legend: 'Success Rate (4xx & 5xx)',
              },
              {
                expr: queries.upstreamLatencyP50ByEnvoyClusterName1h,
                legend: 'P50 Latency',
              },
              {
                expr: queries.upstreamLatencyP95ByEnvoyClusterName1h,
                legend: 'P95 Latency',
              },
              {
                expr: queries.upstreamActiveCxByEnvoyClusterName1h,
                legend: 'Active Connections',
              },
              {
                expr: queries.upstreamDestroyCxByEnvoyClusterName1h,
                legend: 'Destroyed Connections',
              },
              {
                expr: queries.upstreamHealthyPercentByEnvoyClusterName,
                legend: 'Healthy Cluster Percent',
              },
            ],
            description='An overview table showing various upstream metrics by Envoy cluster name [1h].',
            sortBy={ name: 'Request Rate', desc: true },
            transformations=[
              tbQueryOptions.transformation.withId(
                'merge'
              ),
              tbQueryOptions.transformation.withId(
                'organize'
              ) +
              tbQueryOptions.transformation.withOptions(
                {
                  renameByName: {
                    job: 'Job',
                    envoy_cluster_name: 'Envoy Cluster Name',
                    'Value #A': 'Request Rate',
                    'Value #B': 'Success Rate (5xx)',
                    'Value #C': 'Success Rate (4xx & 5xx)',
                    'Value #D': 'P50 Latency',
                    'Value #E': 'P95 Latency',
                    'Value #F': 'Active Connections',
                    'Value #G': 'Destroyed Connections',
                    'Value #H': 'Healthy Cluster Percent',
                  },
                  indexByName: {
                    envoy_cluster_name: 0,
                    'Value #A': 1,
                    'Value #B': 2,
                    'Value #C': 3,
                    'Value #D': 4,
                    'Value #E': 5,
                    'Value #F': 6,
                    'Value #G': 7,
                    'Value #H': 8,
                    'Value #I': 9,
                  },
                  excludeByName: {
                    job: true,
                    Time: true,
                  },
                }
              ),
            ],
            overrides=[
              tbOverride.byName.new('SSL Expirations') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.withUnit('dateTimeFromNow')
              ),
              tbOverride.byName.new('P50 Latency') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.withUnit('ms')
              ),
              tbOverride.byName.new('P95 Latency') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.withUnit('ms')
              ),
              tbOverride.byName.new('Request Rate') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.withUnit('reqps')
              ),
              tbOverride.byName.new('Success Rate (5xx)') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.withUnit('percent')
              ),
              tbOverride.byName.new('Success Rate (4xx & 5xx)') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.withUnit('percent')
              ),
              tbOverride.byName.new('Healthy Cluster Percent') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.withUnit('percent')
              ),
            ]
          ) +
          tbStandardOptions.withLinks([
            tbPanelOptions.link.withTitle('Go To Upstream') +
            tbPanelOptions.link.withType('dashboard') +
            tbPanelOptions.link.withUrl(
              '/d/%s/envoy-upstream?&var-envoy_cluster_name=${__data.fields.Envoy Cluster Name}' % $._config.dashboardIds['envoy-upstream']
            ) +
            tbPanelOptions.link.withTargetBlank(true),
          ]),

        // Downstream
        downstreamRateByEnvoyHttpConnManagerPrefixTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Downstream Rate by Envoy HTTP Conn Manager Prefix',
            'reqps',
            queries.downstreamRateByEnvoyHttpConnManagerPrefix,
            '{{ envoy_http_conn_manager_prefix }}',
            description='Client request rate by HTTP connection manager (listener) over time. Shows top 20 busiest ingress points. Use this to identify traffic patterns, detect sudden spikes that may indicate attacks, or validate that traffic is being distributed as expected across listeners.',
            stack='normal',
          ),

        downstreamLatencyTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Downstream Latency',
            'ms',
            [
              {
                expr: queries.downstreamLatencyP50,
                legend: 'P50',
              },
              {
                expr: queries.downstreamLatencyP95,
                legend: 'P95',
              },
              {
                expr: queries.downstreamLatencyP99,
                legend: 'P99',
                exemplar: true,
              },
            ],
            description='End-to-end request latency percentiles (P50, P95, P99) as experienced by clients. Includes time from request receipt to response completion. Rising P95/P99 indicates degraded user experience - investigate upstream latency, connection issues, or resource constraints. Use exemplars to trace slow requests.',
          ),

        downstreamSuccessRate5xxTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Downstream Success Rate (Excluding 4xx errors)',
            'percent',
            [
              {
                expr: queries.downstreamSuccesRate5xx,
                legend: 'Success Rate',
              },
            ],
            description='Percentage of successful client requests (non-5xx responses). Treats 4xx as successful since they indicate client errors, not service failures. Values below 99.9% indicate problems with backends or Envoy itself. Correlate with upstream metrics and error logs to diagnose issues.',
            stack='normal',
            min=0,
            max=100
          ),

        downstreamSuccessRate4xx5xxTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Downstream Success Rate (Including 4xx errors)',
            'percent',
            [
              {
                expr: queries.downstreamSucessRate4xx5xx,
                legend: 'Success Rate',
              },
            ],
            description='Percentage of successful client requests (non-4xx/5xx responses). Stricter metric counting both client and server errors as failures. Reflects actual user experience - drops indicate authentication issues, invalid requests, or backend failures. Use to assess overall API health from client perspective.',
            stack='normal',
            min=0,
            max=100
          ),

        downstreamTable:
          mixinUtils.dashboards.tablePanel(
            'Downstream Overview [1h]',
            'short',
            [
              {
                expr: queries.downstreamRateByEnvoyHttpConnManagerPrefix1hTop40k,
                legend: 'Request Rate',
              },
              {
                expr: queries.downstreamSuccessRate5xxByEnvoyHttpConnManagerPrefix1h,
                legend: 'Success Rate (5xx)',
              },
              {
                expr: queries.downstreamSucessRate4xx5xxByEnvoyHttpConnManagerPrefix1h,
                legend: 'Success Rate (4xx & 5xx)',
              },
              {
                expr: queries.downstreamLatencyP50ByEnvoyHttpConnManagerPrefix1h,
                legend: 'P50 Latency',
              },
              {
                expr: queries.downstreamLatencyP95ByEnvoyHttpConnManagerPrefix1h,
                legend: 'P95 Latency',
              },
              {
                expr: queries.downstreamActiveCxByEnvoyHttpConnManagerPrefix1h,
                legend: 'Active Connections',
              },
              {
                expr: queries.downstreamDestroyCxByEnvoyHttpConnManagerPrefix1h,
                legend: 'Destroyed Connections',
              },
            ],
            description='An overview table showing various downstream metrics by Envoy HTTP connection manager prefix [1h].',
            sortBy={ name: 'Request Rate', desc: true },
            transformations=[
              tbQueryOptions.transformation.withId(
                'merge'
              ),
              tbQueryOptions.transformation.withId(
                'organize'
              ) +
              tbQueryOptions.transformation.withOptions(
                {
                  renameByName: {
                    job: 'Job',
                    envoy_http_conn_manager_prefix: 'Envoy HTTP Conn Manager Prefix',
                    'Value #A': 'Request Rate',
                    'Value #B': 'Success Rate (5xx)',
                    'Value #C': 'Success Rate (4xx & 5xx)',
                    'Value #D': 'P50 Latency',
                    'Value #E': 'P95 Latency',
                    'Value #F': 'Active Connections',
                    'Value #G': 'Destroyed Connections',
                  },
                  indexByName: {
                    envoy_http_conn_manager_prefix: 0,
                    'Value #A': 1,
                    'Value #B': 2,
                    'Value #C': 3,
                    'Value #D': 4,
                    'Value #E': 5,
                    'Value #F': 6,
                    'Value #G': 7,
                  },
                  excludeByName: {
                    job: true,
                    Time: true,
                  },
                }
              ),
            ],
            overrides=[
              tbOverride.byName.new('P50 Latency') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.withUnit('ms')
              ),
              tbOverride.byName.new('P95 Latency') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.withUnit('ms')
              ),
              tbOverride.byName.new('Request Rate') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.withUnit('reqps')
              ),
              tbOverride.byName.new('Success Rate (5xx)') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.withUnit('percent')
              ),
              tbOverride.byName.new('Success Rate (4xx & 5xx)') +
              tbOverride.byName.withPropertiesFromOptions(
                tbStandardOptions.withUnit('percent')
              ),
            ],
          ) +
          tbStandardOptions.withLinks([
            tbPanelOptions.link.withTitle('Go To Downstream') +
            tbPanelOptions.link.withType('dashboard') +
            tbPanelOptions.link.withUrl(
              '/d/%s/envoy-downstream?var-envoy_http_conn_manager_prefix=${__data.fields.Envoy HTTP Conn Manager Prefix}' % $._config.dashboardIds['envoy-downstream']
            ) +
            tbPanelOptions.link.withTargetBlank(true),
          ]),

        sslExpirationsByEnvoyTlsCertificateTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'SSL Expirations by Envoy TLS Certificate',
            'dateTimeAsIso',
            queries.sslExpirationsByEnvoyTlsCertificate,
            '{{ envoy_tls_certificate }}',
            description='SSL/TLS certificate expiration dates for each certificate loaded by Envoy listeners. Displays minimum expiration time to highlight the most urgent renewal needed. Monitor this panel to prevent service disruptions due to expired certificates. Set up alerts for certificates expiring within 30 days.',
            calcs=['min']
          ),
      };

      local rows =
        [
          row.new('Summary') +
          row.gridPos.withX(0) +
          row.gridPos.withY(0) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.envoyPodsCountStat,
            panels.upstreamsCountStat,
            panels.downstreamsCountStat,
            panels.upstreamActiveCxStat,
            panels.downstreamActiveCxStat,
            panels.membershipHealthyPercentStat,
          ],
          panelWidth=4,
          panelHeight=4,
          startY=1
        ) +
        grid.wrapPanels(
          [
            panels.upstreamRateByEnvoyClusterNamePieChart,
            panels.upstreamRateByCodeClassPieChart,
            panels.downstreamRateByEnvoyHttpConnManagerPrefixPieChart,
            panels.upstreamRateByPodPieChart,
          ],
          panelWidth=6,
          panelHeight=6,
          startY=5
        ) +
        [
          row.new('Upstream') +
          row.gridPos.withX(0) +
          row.gridPos.withY(11) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.upstreamRateByEnvoyClusterNameTimeSeries,
            panels.upstreamLatencyTimeSeries,
            panels.upstreamSuccessRate5xxTimeSeries,
            panels.upstreamSuccessRate4xx5xxTimeSeries,
          ],
          panelWidth=12,
          panelHeight=8,
          startY=12
        ) +
        grid.wrapPanels(
          [
            panels.upstreamTable,
          ],
          panelWidth=24,
          panelHeight=12,
          startY=28
        ) +
        [
          row.new('Downstream') +
          row.gridPos.withX(0) +
          row.gridPos.withY(40) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.downstreamRateByEnvoyHttpConnManagerPrefixTimeSeries,
            panels.downstreamLatencyTimeSeries,
            panels.downstreamSuccessRate5xxTimeSeries,
            panels.downstreamSuccessRate4xx5xxTimeSeries,
          ],
          panelWidth=12,
          panelHeight=8,
          startY=41
        ) +
        grid.wrapPanels(
          [
            panels.downstreamTable,
          ],
          panelWidth=24,
          panelHeight=12,
          startY=57
        ) +
        [
          row.new('SSL') +
          row.gridPos.withX(0) +
          row.gridPos.withY(69) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.wrapPanels(
          [
            panels.sslExpirationsByEnvoyTlsCertificateTimeSeries,
          ],
          panelWidth=24,
          panelHeight=8,
          startY=70
        );

      mixinUtils.dashboards.bypassDashboardValidation +
      dashboard.new(
        'Envoy / Overview',
      ) +
      dashboard.withDescription('A comprehensive overview dashboard for monitoring Envoy proxy deployments. Provides high-level metrics across all upstreams and downstreams including request rates, latency percentiles, success rates, active connections, and SSL certificate expirations. Use this dashboard to identify trends, spot anomalies, and drill down into specific upstream clusters or downstream connection managers. %s' % mixinUtils.dashboards.dashboardDescriptionLink('envoy-mixin', 'https://github.com/adinhodovic/envoy-mixin')) +
      dashboard.withUid($._config.dashboardIds[dashboardName]) +
      dashboard.withTags($._config.tags) +
      dashboard.withTimezone('utc') +
      dashboard.withEditable(false) +
      dashboard.time.withFrom('now-6h') +
      dashboard.time.withTo('now') +
      dashboard.withVariables(variables) +
      dashboard.withLinks(
        mixinUtils.dashboards.dashboardLinks('Envoy', $._config, dropdown=true)
      ) +
      dashboard.withPanels(
        rows
      ) +
      dashboard.withAnnotations(
        mixinUtils.dashboards.annotations($._config, defaultFilters)
      ),
  },
}
