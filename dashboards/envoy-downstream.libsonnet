local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

{
  local dashboardName = 'envoy-downstream',
  grafanaDashboards+:: {
    ['%s.json' % dashboardName]:

      local defaultVariables = util.variables($._config);

      local variables = [
        defaultVariables.datasource,
        defaultVariables.cluster,
        defaultVariables.namespace,
        defaultVariables.job,
        defaultVariables.envoyHttpConnManagerPrefixSingle,
        defaultVariables.podDownstream,
      ];

      local defaultFilters = util.filters($._config);
      local queries = {
        // Summary
        downstreamsCountJob: |||
          count(
            envoy_http_downstream_rq_total{
              %(default)s
            }
          ) by (job)
        ||| % defaultFilters,

        downstreamActiveCx: |||
          topk(20,
            sum(
              envoy_http_downstream_cx_active{
                %(default)s
              }
            ) by (envoy_http_conn_manager_prefix)
          )
        ||| % defaultFilters,

        downstreamRateByEnvoyHttpConnManagerPrefix1h: |||
          topk(20,
            sum(
              rate(
                envoy_http_downstream_rq_total{
                  %(default)s
                }[1h]
              )
            ) by (envoy_http_conn_manager_prefix)
          )
        ||| % defaultFilters,

        downstreamRateByCodeClass1h: |||
          sum(
            rate(
              envoy_http_downstream_rq_xx{
                %(default)s
              }[1h]
            )
          ) by (envoy_response_code_class)
        ||| % defaultFilters,

        // Downstream
        downstreamRate: |||
          sum(
            rate(
              envoy_http_downstream_rq_total{
                %(downstreamSingle)s
              }[$__rate_interval]
            )
          ) by (envoy_http_conn_manager_prefix)
        ||| % defaultFilters,

        downstreamLatencyP50: |||
          histogram_quantile(
            0.5,
            sum(
              rate(
                envoy_http_downstream_rq_time_bucket{
                  %(downstreamSingle)s
                }[$__rate_interval]
              )
            ) by (le)
          )
        ||| % defaultFilters,
        downstreamLatencyP95: std.strReplace(queries.downstreamLatencyP50, '0.5', '0.95'),
        downstreamLatencyP99: std.strReplace(queries.downstreamLatencyP50, '0.5', '0.99'),

        downstreamSuccessRate5xx: |||
          sum(
            rate(
              envoy_http_downstream_rq_xx{
                %(downstreamSingle)s,
                envoy_response_code_class!="5"
              }[$__rate_interval]
            )
          )
          /
          sum(
            rate(
              envoy_http_downstream_rq_xx{
                %(downstreamSingle)s
              }[$__rate_interval]
            )
          )
          * 100
        ||| % defaultFilters,
        downstreamSucessRate4xx5xx: std.strReplace(queries.downstreamSuccessRate5xx, 'envoy_response_code_class!="5"', 'envoy_response_code_class!~"4|5"'),

        downstreamRateByCodeClass: std.strReplace(queries.downstreamRateByCodeClass1h, '1h', '$__rate_interval'),

        downstreamCxActive: |||
          sum(
            envoy_http_downstream_cx_active{
              %(downstreamSingle)s
            }
          ) by (envoy_http_conn_manager_prefix)
        ||| % defaultFilters,

        downstreamCxDestroy: |||
          sum(
            increase(
              envoy_http_downstream_cx_destroy{
                %(downstreamSingle)s
              }[$__rate_interval]
            )
          ) by (job, envoy_http_conn_manager_prefix)
        ||| % defaultFilters,

        downstreamCxRxBytesTotal: |||
          sum(
            rate(
              envoy_http_downstream_cx_rx_bytes_total{
                %(downstreamSingle)s
              }[$__rate_interval]
            )
          ) by (job, envoy_http_conn_manager_prefix)
        ||| % defaultFilters,

        downstreamCxTxBytesTotal: |||
          sum(
            rate(
              envoy_http_downstream_cx_tx_bytes_total{
                %(downstreamSingle)s
              }[$__rate_interval]
            )
          ) by (job, envoy_http_conn_manager_prefix)
        ||| % defaultFilters,

        downstreamCxIdleTimeout: |||
          sum(
            increase(
              envoy_http_downstream_cx_idle_timeout{
                %(downstreamSingle)s
              }[$__rate_interval]
            )
          ) by (job, envoy_http_conn_manager_prefix)
        ||| % defaultFilters,

        downstreamRqRxReset: |||
          sum(
            rate(
              envoy_http_downstream_rq_rx_reset{
                %(downstreamSingle)s
              }[$__rate_interval]
            )
          ) by (job, envoy_http_conn_manager_prefix)
        ||| % defaultFilters,

        downstreamRqTxReset: |||
          sum(
            rate(
              envoy_http_downstream_rq_tx_reset{
                %(downstreamSingle)s
              }[$__rate_interval]
            )
          ) by (job, envoy_http_conn_manager_prefix)
        ||| % defaultFilters,

        downstreamRqTimeout: |||
          sum(
            rate(
              envoy_http_downstream_rq_timeout{
                %(downstreamSingle)s
              }[$__rate_interval]
            )
          ) by (job, envoy_http_conn_manager_prefix)
        ||| % defaultFilters,

        downstreamRateByPod: |||
          sum(
            rate(
              envoy_http_downstream_rq_total{
                %(downstreamSingle)s
              }[$__rate_interval]
            )
          ) by (pod, envoy_http_conn_manager_prefix)
        ||| % defaultFilters,

        downstreamCxActiveByPod: |||
          sum(
            envoy_http_downstream_cx_active{
              %(downstreamSingle)s
            }
          ) by (pod, envoy_http_conn_manager_prefix)
        ||| % defaultFilters,
      };

      local panels = {

        // Summary
        downstreamsCountByJobPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Downstreams Count by Job',
            'downstreams',
            queries.downstreamsCountJob,
            '{{ job }}',
            description='Distribution of downstream HTTP connection managers across different Prometheus job labels. Helps understand how client-facing listeners are organized across Envoy deployments or environments. Imbalanced distribution may indicate configuration inconsistencies.',
          ),

        downstreamActiveCxByEnvoyHttpConnManagerPrefixPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Downstream Active Connections by Envoy HTTP Conn Manager Prefix',
            'short',
            queries.downstreamActiveCx,
            '{{ envoy_http_conn_manager_prefix }}',
            description='Distribution of currently active client connections across HTTP connection managers. Shows which ingress points are handling the most concurrent connections. High connection counts relative to request rates may indicate slow clients, long-polling connections, or WebSocket traffic.',
          ),

        downstreamRateByEnvoyHttpConnManagerPrefixPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Downstream Rate by Envoy HTTP Conn Manager Prefix [1h]',
            'reqps',
            queries.downstreamRateByEnvoyHttpConnManagerPrefix1h,
            '{{ envoy_http_conn_manager_prefix }}',
            description='Request rate distribution across downstream connection managers over the past hour (top 20). Identifies which ingress points receive the most client traffic. Use this to validate traffic routing, detect unexpected traffic patterns, and identify hot spots requiring load balancing adjustments.',
          ),

        downstreamRateByCodeClassPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Downstream Rate by Code Class [1h]',
            'reqps',
            queries.downstreamRateByCodeClass1h,
            '{{ envoy_response_code_class }}xx',
            description='Breakdown of client responses by HTTP status code class over the past hour. Healthy services show 95%+ 2xx responses. High 4xx proportions indicate client errors, authentication issues, or invalid requests. Any 5xx responses indicate service failures requiring immediate investigation.',
          ),

        // Downstream
        downstreamRateTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Downstream Rate',
            'reqps',
            queries.downstreamRate,
            '{{ envoy_http_conn_manager_prefix }}',
            description='Client request rate per HTTP connection manager over time. Each line represents traffic to a specific ingress listener. Sudden spikes may indicate traffic surges, DDoS attacks, or sudden popularity. Drops suggest client-side issues or upstream routing changes. Use to monitor ingress traffic patterns.',
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
            description='End-to-end request latency as experienced by clients. P50 shows typical response time, P95/P99 reveal tail latency impacting user experience. Rising tail latency often precedes user complaints. Investigate when P95 exceeds SLOs. Correlate with upstream latency to identify bottlenecks. Exemplars enable trace-based debugging.',
          ),

        downstreamSuccessRate5xxTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Downstream Success Rate (Excluding 4xx errors)',
            'percent',
            [
              {
                expr: queries.downstreamSuccessRate5xx,
                legend: 'Success Rate',
              },
            ],
            description='Client success rate excluding 4xx errors (treating client errors as successful). Values below 99.9% indicate service-side problems. Drops correlate with backend failures or Envoy issues. Compare with upstream success rates to determine if failures originate from backends or proxy layer.',
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
            description='Overall client success rate including both 4xx and 5xx as failures. Represents actual end-user experience. Drops may indicate authentication failures, invalid client requests, API contract violations, or backend errors. Use this metric for user-facing SLOs and customer impact assessment.',
            stack='normal',
            min=0,
            max=100
          ),

        downstreamRateByCodeClassTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Downstream Rate by Code Class',
            'reqps',
            queries.downstreamRateByCodeClass,
            '{{ envoy_response_code_class }}xx',
            description='Client request rate by HTTP status code class (2xx/3xx/4xx/5xx). Normal traffic is dominated by 2xx. Spikes in 4xx may indicate authentication problems, API misuse, or client bugs. Any 5xx indicates service failures. Monitor 401/403 for security issues and 429 for rate limiting effectiveness.',
            stack='normal',
          ),

        downstreamCxTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Downstream Connections',
            'short',
            [
              {
                expr: queries.downstreamCxActive,
                legend: 'Active Connections',
              },
              {
                expr: queries.downstreamCxDestroy,
                legend: 'Destroyed Connections',
              },
              {
                expr: queries.downstreamCxIdleTimeout,
                legend: 'Idle Timeout',
              },
            ],
            description='Client connection lifecycle metrics. Active shows current open connections. Destroyed tracks normal connection teardown. High idle timeouts may indicate misconfigured clients, slow clients, or aggressive timeout settings. Correlate with request rates to identify connection efficiency issues.',
          ),

        downstreamCxBytesTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Downstream Connection Bytes',
            'Bps',
            [
              {
                expr: queries.downstreamCxRxBytesTotal,
                legend: 'Received',
              },
              {
                expr: queries.downstreamCxTxBytesTotal,
                legend: 'Transmitted',
              },
            ],
            description='Bandwidth usage for client traffic. Received shows data from clients (request bodies, uploads). Transmitted shows data to clients (response bodies, downloads). Use to identify bandwidth-heavy endpoints, detect large file transfers, and plan capacity. Sudden spikes may indicate data exfiltration or abuse.',
          ),

        downstreamRqResetTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Downstream Request Resets',
            'reqps',
            [
              {
                expr: queries.downstreamRqRxReset,
                legend: 'RX Reset',
              },
              {
                expr: queries.downstreamRqTxReset,
                legend: 'TX Reset',
              },
              {
                expr: queries.downstreamRqTimeout,
                legend: 'Timeout',
              },
            ],
            description='Abnormal request termination patterns. RX Reset = client aborted request (client disconnect, timeout). TX Reset = Envoy terminated response (upstream failure, policy violation). Timeouts = request exceeded configured deadline. High rates indicate client issues, network problems, or slow backends.',
            stack='normal',
          ),

        downstreamRateByPodTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Downstream Rate by Pod',
            'reqps',
            queries.downstreamRateByPod,
            '{{ pod }}',
            description='Client traffic distribution across Envoy proxy pods for this connection manager. Should show even distribution if load balancing works correctly. Imbalanced traffic may indicate L4 load balancer issues, DNS problems, or client-side connection affinity. Use to verify horizontal scaling effectiveness.',
            stack='normal',
          ),

        downstreamCxActiveByPodTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Downstream Active Connections by Pod',
            'short',
            queries.downstreamCxActiveByPod,
            '{{ pod }}',
            description='Active client connections per Envoy pod for this connection manager. Should correlate with request rates and show balanced distribution. High connections with low requests indicate long-lived connections (WebSockets, streaming). Uneven distribution suggests load balancer or DNS issues requiring investigation.',
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
            panels.downstreamsCountByJobPieChart,
            panels.downstreamRateByEnvoyHttpConnManagerPrefixPieChart,
            panels.downstreamRateByCodeClassPieChart,
            panels.downstreamActiveCxByEnvoyHttpConnManagerPrefixPieChart,
          ],
          panelWidth=6,
          panelHeight=6,
          startY=5
        ) +
        [
          row.new('$envoy_http_conn_manager_prefix') +
          row.gridPos.withX(0) +
          row.gridPos.withY(7) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1) +
          row.withRepeat('envoy_http_conn_manager_prefix'),
        ] +
        grid.wrapPanels(
          [
            panels.downstreamRateTimeSeries,
            panels.downstreamLatencyTimeSeries,
            panels.downstreamSuccessRate5xxTimeSeries,
            panels.downstreamSuccessRate4xx5xxTimeSeries,
            panels.downstreamRateByCodeClassTimeSeries,
            panels.downstreamCxTimeSeries,
            panels.downstreamCxBytesTimeSeries,
            panels.downstreamRqResetTimeSeries,
            panels.downstreamRateByPodTimeSeries,
            panels.downstreamCxActiveByPodTimeSeries,
          ],
          panelWidth=12,
          panelHeight=8,
          startY=8
        );


      mixinUtils.dashboards.bypassDashboardValidation +
      dashboard.new(
        'Envoy / Downstream',
      ) +
      dashboard.withDescription('Detailed downstream connection monitoring for Envoy proxy. Tracks client-facing metrics including request rates, latency percentiles (P50/P95/P99), success rates, active connections, connection lifecycle events, bandwidth usage, and request reset patterns for each HTTP connection manager. Use this dashboard to analyze client behavior, diagnose connection issues, monitor ingress traffic patterns, and identify potential DDoS or abuse scenarios. Supports multi-prefix selection for comparative analysis. %s' % mixinUtils.dashboards.dashboardDescriptionLink('envoy-mixin', 'https://github.com/adinhodovic/envoy-mixin')) +
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
