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
            description='The distribution of downstreams by job.',
          ),

        downstreamActiveCxByEnvoyHttpConnManagerPrefixPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Downstream Active Connections by Envoy HTTP Conn Manager Prefix',
            'short',
            queries.downstreamActiveCx,
            '{{ envoy_http_conn_manager_prefix }}',
            description='The distribution of active downstream connections by Envoy HTTP connection manager prefix.',
          ),

        downstreamRateByEnvoyHttpConnManagerPrefixPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Downstream Rate by Envoy HTTP Conn Manager Prefix [1h]',
            'reqps',
            queries.downstreamRateByEnvoyHttpConnManagerPrefix1h,
            '{{ envoy_http_conn_manager_prefix }}',
            description='The distribution of downstream request rates by Envoy HTTP connection manager prefix.',
          ),

        downstreamRateByCodeClassPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Downstream Rate by Code Class [1h]',
            'reqps',
            queries.downstreamRateByCodeClass1h,
            '{{ envoy_response_code_class }}xx',
            description='The distribution of downstream request rates by response code class.',
          ),

        // Downstream
        downstreamRateTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Downstream Rate',
            'reqps',
            queries.downstreamRate,
            '{{ envoy_http_conn_manager_prefix }}',
            description='The downstream request rate by Envoy HTTP connection manager prefix over time.',
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
            description='The downstream latency percentiles over time.',
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
            description='The downstream success rate over time, counting 5xx response codes as errors.',
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
            description='The downstream success rate over time, counting 4xx and 5xx response codes as errors.',
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
            description='The downstream request rate by response code class over time.',
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
            description='The downstream connections over time.',
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
            description='The downstream connection bytes received and transmitted over time.',
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
            description='The downstream request resets and timeouts over time.',
            stack='normal',
          ),

        downstreamRateByPodTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Downstream Rate by Pod',
            'reqps',
            queries.downstreamRateByPod,
            '{{ pod }}',
            description='The downstream request rate by pod over time.',
            stack='normal',
          ),

        downstreamCxActiveByPodTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Downstream Active Connections by Pod',
            'short',
            queries.downstreamCxActiveByPod,
            '{{ pod }}',
            description='The downstream active connections by pod over time.',
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
      dashboard.withDescription('A dashboard that monitors Envoy with a focus on giving a downstreams overview. %s' % mixinUtils.dashboards.dashboardDescriptionLink('envoy-mixin', 'https://github.com/adinhodovic/envoy-mixin')) +
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
