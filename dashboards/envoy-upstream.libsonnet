local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

{
  local dashboardName = 'envoy-upstream',
  grafanaDashboards+:: {
    ['%s.json' % dashboardName]:

      local defaultVariables = util.variables($._config);

      local variables = [
        defaultVariables.datasource,
        defaultVariables.cluster,
        defaultVariables.namespace,
        defaultVariables.job,
        defaultVariables.envoyClusterNameSingle,
        defaultVariables.podUpstream,
      ];

      local defaultFilters = util.filters($._config);
      local queries = {
        // Summary
        upstreamsCountJob: |||
          count(
            envoy_cluster_upstream_rq_total{
              %(default)s
            }
          ) by (job)
        ||| % defaultFilters,

        upstreamActiveCx: |||
          topk(20,
            sum(
              envoy_cluster_upstream_cx_active{
                %(default)s
              }
            ) by (envoy_cluster_name)
          )
        ||| % defaultFilters,

        upstreamRateByEnvoyClusterName1h: |||
          topk(20,
            sum(
              rate(
                envoy_cluster_upstream_rq_total{
                  %(default)s
                }[1h]
              )
            ) by (envoy_cluster_name)
          )
        ||| % defaultFilters,

        upstreamRateByCodeClass1h: |||
          sum(
            rate(
              envoy_cluster_upstream_rq_xx{
                %(default)s
              }[1h]
            )
          ) by (envoy_response_code_class)
        ||| % defaultFilters,

        // Upstream
        upstreamRate: |||
          sum(
            rate(
              envoy_cluster_upstream_rq_total{
                %(upstreamSingle)s
              }[$__rate_interval]
            )
          ) by (envoy_cluster_name)
        ||| % defaultFilters,

        upstreamLatencyP50: |||
          histogram_quantile(
            0.5,
            sum(
              rate(
                envoy_cluster_upstream_rq_time_bucket{
                  %(upstreamSingle)s
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
                %(upstreamSingle)s,
                envoy_response_code_class!="5"
              }[$__rate_interval]
            )
          )
          /
          sum(
            rate(
              envoy_cluster_upstream_rq_xx{
                %(upstreamSingle)s
              }[$__rate_interval]
            )
          )
          * 100
        ||| % defaultFilters,
        upstreamSucessRate4xx5xx: std.strReplace(queries.upstreamSuccessRate5xx, 'envoy_response_code_class!="5"', 'envoy_response_code_class!~"4|5"'),

        upstreamRateByCodeClass: |||
          sum(
            rate(
              envoy_cluster_upstream_rq_xx{
                %(upstreamSingle)s
              }[$__rate_interval]
            )
          ) by (envoy_response_code_class)
        ||| % defaultFilters,

        upstreamRateByCode: |||
          sum(
            rate(
              envoy_cluster_upstream_rq{
                %(upstreamSingle)s
              }[$__rate_interval]
            )
          ) by (envoy_response_code)
        ||| % defaultFilters,

        upstreamHealthyPercentByEnvoyClusterName: |||
          sum(
            envoy_cluster_membership_healthy{
              %(upstreamSingle)s
            }
          ) by (job, envoy_cluster_name)
          /
          sum(
            envoy_cluster_membership_total{
              %(upstreamSingle)s
            }
          ) by (job, envoy_cluster_name)
          * 100
        ||| % defaultFilters,

        upstreamCxActive: |||
          sum(
            envoy_cluster_upstream_cx_active{
              %(upstreamSingle)s
            }
          ) by (envoy_cluster_name)
        ||| % defaultFilters,

        upstreamCxOverflow: |||
          sum(
            increase(
              envoy_cluster_upstream_cx_overflow{
                %(upstreamSingle)s
              }[$__rate_interval]
            )
          ) by (job, envoy_cluster_name)
        ||| % defaultFilters,

        upstreamDestroyCxByEnvoyClusterName: |||
          sum(
            increase(
              envoy_cluster_upstream_cx_destroy{
                %(upstreamSingle)s
              }[$__rate_interval]
            )
          ) by (job, envoy_cluster_name)
        ||| % defaultFilters,

        upstreamConnectFailCxByEnvoyClusterName: |||
          sum(
            increase(
              envoy_cluster_upstream_cx_connect_fail{
                %(upstreamSingle)s
              }[$__rate_interval]
            )
          ) by (job, envoy_cluster_name)
        ||| % defaultFilters,

        upstreamCircuitBreakersOpenCxByEnvoyClusterName: |||
          sum(
            envoy_cluster_circuit_breakers_default_cx_open{
              %(upstreamSingle)s
            }
          ) by (job, envoy_cluster_name)
        ||| % defaultFilters,

        upstreamCircuitBreakersOpenPoolCxByEnvoyClusterName: |||
          sum(
            envoy_cluster_circuit_breakers_default_cx_pool_open{
              %(upstreamSingle)s
            }
          ) by (job, envoy_cluster_name)
        ||| % defaultFilters,

        upstreamCircuitBreakersOpenRqByEnvoyClusterName: |||
          sum(
            envoy_cluster_circuit_breakers_default_rq_open{
              %(upstreamSingle)s
            }
          ) by (job, envoy_cluster_name)
        ||| % defaultFilters,

        upstreamTimeOutRateByEnvoyClusterName: |||
          sum(
            rate(
              envoy_cluster_upstream_rq_timeout{
                %(upstreamSingle)s
              }[$__rate_interval]
            )
          ) by (job, envoy_cluster_name)
        ||| % defaultFilters,

        upstreamRetryRateByEnvoyClusterName: |||
          sum(
            rate(
              envoy_cluster_upstream_rq_retry{
                %(upstreamSingle)s
              }[$__rate_interval]
            )
          ) by (job, envoy_cluster_name)
        ||| % defaultFilters,

        upstreamRetryOverflowRateByEnvoyClusterName: |||
          sum(
            rate(
              envoy_cluster_upstream_rq_retry_overflow{
                %(upstreamSingle)s
              }[$__rate_interval]
            )
          ) by (job, envoy_cluster_name)
        ||| % defaultFilters,

        upstreamRateByPod: |||
          sum(
            rate(
              envoy_cluster_upstream_rq_total{
                %(upstreamSingle)s
              }[$__rate_interval]
            )
          ) by (pod, envoy_cluster_name)
        ||| % defaultFilters,

        upstreamCxActiveByPod: |||
          sum(
            envoy_cluster_upstream_cx_active{
              %(upstreamSingle)s
            }
          ) by (pod, envoy_cluster_name)
        ||| % defaultFilters,
      };

      local panels = {

        // Summary
        upstreamsCountByJobPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Upstreams Count by Job',
            'upstreams',
            queries.upstreamsCountJob,
            '{{ job }}',
            description='Distribution of upstream clusters across different Prometheus job labels. Useful for understanding how backend services are organized across different Envoy deployments or environments. Imbalanced distribution may indicate configuration inconsistencies.',
          ),

        upstreamActiveCxByEnvoyClusterNamePieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Upstream Active Connections by Envoy Cluster Name',
            'short',
            queries.upstreamActiveCx,
            '{{ envoy_cluster_name }}',
            description='Distribution of currently active TCP connections to upstream services. Shows which backend clusters are consuming the most connections. Disproportionately high connection counts may indicate connection pooling issues, slow backends, or HTTP/1.1 connection inefficiency. Compare with request rates to assess connection reuse.',
          ),

        upstreamRateByEnvoyClusterNamePieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Upstream Rate by Envoy Cluster Name [1h]',
            'reqps',
            queries.upstreamRateByEnvoyClusterName1h,
            '{{ envoy_cluster_name }}',
            description='Request rate distribution across upstream clusters over the past hour (top 20). Identifies which backend services receive the most traffic. Use this to validate load distribution, detect traffic shifts after deployments, and identify hot services that may need scaling.',
          ),

        upstreamRateByCodeClassPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Upstream Rate by Code Class [1h]',
            'reqps',
            queries.upstreamRateByCodeClass1h,
            '{{ envoy_response_code_class }}xx',
            description='Breakdown of upstream responses by HTTP status code class over the past hour. Healthy services typically show 95%+ 2xx responses. High 4xx proportions suggest API contract issues or client misconfigurations. Any 5xx responses indicate backend failures requiring immediate investigation.',
          ),

        // Upstream
        upstreamRateTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Upstream Rate',
            'reqps',
            queries.upstreamRate,
            '{{ envoy_cluster_name }}',
            description='Request rate per upstream cluster over time. Each line represents traffic to a specific backend service. Sudden drops may indicate circuit breaker activation, upstream failures, or routing changes. Gradual increases suggest growing load. Use this to identify which clusters need scaling or optimization.',
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
            description='Backend service response time percentiles. P50 represents typical latency, while P95/P99 show tail latency affecting a subset of requests. Rising P99 often precedes visible performance degradation. Investigate backends when P95 exceeds SLO targets. Exemplars link to distributed traces for root cause analysis.',
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
            description='Backend success rate treating 4xx as successful (client errors, not backend failures). Drops below 99.9% indicate backend health issues. Correlate with circuit breaker metrics, health check status, and backend logs. Sustained low rates may trigger automatic circuit breaking.',
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
            description='Overall success rate counting both 4xx and 5xx as failures. Reflects end-user experience including authentication, authorization, and validation errors. Lower rates may indicate API contract mismatches, breaking changes, or integration issues between services.',
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
            description='Request rate breakdown by HTTP status code class (2xx/3xx/4xx/5xx). Normal traffic shows dominant 2xx responses. Sudden 4xx spikes suggest client-side issues or API changes. Any 5xx indicates backend failures. Monitor 5xx rate to detect cascading failures early.',
            stack='normal',
          ),

        upstreamRateByCodeTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Upstream Rate by Code',
            'reqps',
            queries.upstreamRateByCode,
            '{{ envoy_response_code }}',
            description='Detailed request rate by specific HTTP status code (200, 404, 500, etc.). Use this to identify specific error patterns. For example, 503 may indicate overload, 502 suggests gateway issues, and 429 shows rate limiting activation. Helps pinpoint exact failure modes.',
            stack='normal',
          ),

        upstreamHealthyPercentTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Upstream Healthy Percent',
            'percent',
            queries.upstreamHealthyPercentByEnvoyClusterName,
            '{{ envoy_cluster_name }}',
            description='Percentage of healthy endpoints per cluster based on active health checks. 100% indicates all endpoints passing health checks. Drops suggest failing instances - check pod logs, resource usage, and health check configurations. Envoy removes unhealthy endpoints from load balancing rotation.',
            stack='normal',
            min=0,
            max=100
          ),

        upstreamCxTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Upstream Connections',
            'short',
            [
              {
                expr: queries.upstreamCxActive,
                legend: 'Active Connections',
              },
              {
                expr: queries.upstreamCxOverflow,
                legend: 'Overflow Connections',
              },
              {
                expr: queries.upstreamDestroyCxByEnvoyClusterName,
                legend: 'Destroyed Connections',
              },
              {
                expr: queries.upstreamConnectFailCxByEnvoyClusterName,
                legend: 'Connect Failures',
              },
            ],
            description='Connection lifecycle metrics. Active shows current open connections. Overflow indicates circuit breaker limits exceeded - increase limits or scale backends. Destroyed tracks normal connection teardown. Connect failures suggest network issues, DNS problems, or unreachable backends.',
          ),

        upstreamCircuitBreakersTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Upstream Circuit Breakers',
            'short',
            [
              {
                expr: queries.upstreamCircuitBreakersOpenCxByEnvoyClusterName,
                legend: 'Open Connections',
              },
              {
                expr: queries.upstreamCircuitBreakersOpenPoolCxByEnvoyClusterName,
                legend: 'Open Pool Connections',
              },
              {
                expr: queries.upstreamCircuitBreakersOpenRqByEnvoyClusterName,
                legend: 'Open Requests',
              },
            ],
            description='Circuit breaker activation counts. Non-zero values indicate protection mechanisms triggered to prevent cascade failures. Open Connections = max concurrent connections reached. Open Requests = max pending requests exceeded. Persistent activation suggests undersized limits or backend overload requiring scaling.',
            stack='normal',
          ),

        upstreamRetryRateByTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Upstream Retry Rate',
            'reqps',
            [
              {
                expr: queries.upstreamRetryRateByEnvoyClusterName,
                legend: 'Retry Rate',
              },
              {
                expr: queries.upstreamRetryOverflowRateByEnvoyClusterName,
                legend: 'Retry Overflow Rate',
              },
              {
                expr: queries.upstreamTimeOutRateByEnvoyClusterName,
                legend: 'Timeout Rate',
              },
            ],
            description='Retry and timeout patterns. Retry Rate shows automatic retry attempts for failed requests. Retry Overflow means retry budget exhausted - may indicate persistent failures or aggressive retry policies. Timeout Rate tracks requests exceeding configured deadlines - investigate slow backends or network latency.',
            stack='normal',
          ),

        upstreamRateByPodTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Upstream Rate by Pod',
            'reqps',
            queries.upstreamRateByPod,
            '{{ pod }}',
            description='Request distribution across Envoy proxy pods for this upstream cluster. Ideally shows even distribution. Imbalanced traffic may indicate pod scheduling issues, uneven client distribution, or connection affinity problems. Use to verify horizontal scaling effectiveness.',
            stack='normal',
          ),

        upstreamCxActiveByPodTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Upstream Active Connections by Pod',
            'short',
            queries.upstreamCxActiveByPod,
            '{{ pod }}',
            description='Active connections per Envoy pod to this upstream cluster. Should correlate with request rates. High connections with low requests suggest connection pooling inefficiency or slow-draining connections. Uneven distribution may indicate pod-level issues requiring investigation.',
            stack='normal',
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
            panels.upstreamsCountByJobPieChart,
            panels.upstreamRateByEnvoyClusterNamePieChart,
            panels.upstreamRateByCodeClassPieChart,
            panels.upstreamActiveCxByEnvoyClusterNamePieChart,
          ],
          panelWidth=6,
          panelHeight=6,
          startY=5
        ) +
        [
          row.new('$envoy_cluster_name') +
          row.gridPos.withX(0) +
          row.gridPos.withY(7) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1) +
          row.withRepeat('envoy_cluster_name'),
        ] +
        grid.wrapPanels(
          [
            panels.upstreamRateTimeSeries,
            panels.upstreamLatencyTimeSeries,
            panels.upstreamSuccessRate5xxTimeSeries,
            panels.upstreamSuccessRate4xx5xxTimeSeries,
            panels.upstreamRateByCodeClassTimeSeries,
            panels.upstreamRateByCodeTimeSeries,
            panels.upstreamHealthyPercentTimeSeries,
            panels.upstreamCxTimeSeries,
            panels.upstreamCircuitBreakersTimeSeries,
            panels.upstreamRetryRateByTimeSeries,
            panels.upstreamRateByPodTimeSeries,
            panels.upstreamCxActiveByPodTimeSeries,
          ],
          panelWidth=12,
          panelHeight=8,
          startY=8
        );


      mixinUtils.dashboards.bypassDashboardValidation +
      dashboard.new(
        'Envoy / Upstream',
      ) +
      dashboard.withDescription('Detailed upstream cluster monitoring for Envoy proxy. Tracks request rates, latency distributions (P50/P95/P99), success rates, connection health, circuit breaker status, retry behavior, and timeout patterns for each upstream cluster. Use this dashboard to troubleshoot backend service issues, identify performance bottlenecks, and monitor cluster health across all Envoy pods. Supports multi-cluster selection for comparative analysis. %s' % mixinUtils.dashboards.dashboardDescriptionLink('envoy-mixin', 'https://github.com/adinhodovic/envoy-mixin')) +
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
