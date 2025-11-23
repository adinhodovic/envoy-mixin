local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local tablePanel = g.panel.table;
local pieChartPanel = g.panel.pieChart;

// Pie Chart
local pcStandardOptions = pieChartPanel.standardOptions;
local pcOverride = pcStandardOptions.override;

// Table
local tbStandardOptions = tablePanel.standardOptions;
local tbQueryOptions = tablePanel.queryOptions;
local tbPanelOptions = tablePanel.panelOptions;
local tbOverride = tbStandardOptions.override;

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

        upstreamRateByCodeClass: std.strReplace(queries.upstreamRateByCodeClass1h, '1h', '$__rate_interval'),

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
            description='The distribution of upstreams by job.',
          ),

        upstreamActiveCxByEnvoyClusterNamePieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Upstream Active Connections by Envoy Cluster Name',
            'connections',
            queries.upstreamActiveCx,
            '{{ envoy_cluster_name }}',
            description='The distribution of active upstream connections by Envoy cluster name.',
          ),

        upstreamRateByEnvoyClusterNamePieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Upstream Rate by Envoy Cluster Name [1h]',
            'reqps',
            queries.upstreamRateByEnvoyClusterName1h,
            '{{ envoy_cluster_name }}',
            description='The distribution of upstream request rates by Envoy cluster name.',
          ),

        upstreamRateByCodeClassPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Upstream Rate by Code Class [1h]',
            'reqps',
            queries.upstreamRateByCodeClass1h,
            '{{ envoy_response_code_class }}xx',
            description='The distribution of upstream request rates by response code class.',
          ),

        // Upstream
        upstreamRateTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Upstream Rate',
            'reqps',
            queries.upstreamRate,
            '{{ envoy_cluster_name }}',
            description='The upstream request rate by Envoy cluster name over time.',
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
            description='The upstream latency percentiles over time.',
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
            description='The upstream success rate over time, counting 5xx response codes as errors.',
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
            description='The upstream success rate over time, counting 4xx and 5xx response codes as errors.',
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
            description='The upstream request rate by response code class over time.',
            stack='normal',
          ),

        upstreamRateByCodeTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Upstream Rate by Code',
            'reqps',
            queries.upstreamRateByCode,
            '{{ envoy_response_code }}',
            description='The upstream request rate by response code over time.',
            stack='normal',
          ),

        upstreamHealthyPercentTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Upstream Healthy Percent',
            'percent',
            queries.upstreamHealthyPercentByEnvoyClusterName,
            '{{ envoy_cluster_name }}',
            description='The percentage of healthy upstream members by Envoy cluster name over time.',
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
            description='The upstream connections over time.',
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
            description='The upstream circuit breakers over time.',
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
            description='The upstream retry rates over time.',
            stack='normal',
          ),

        upstreamRateByPodTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Upstream Rate by Pod',
            'reqps',
            queries.upstreamRateByPod,
            '{{ pod }}',
            description='The upstream request rate by pod over time.',
            stack='normal',
          ),

        upstreamCxActiveByPodTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Upstream Active Connections by Pod',
            'connections',
            queries.upstreamCxActiveByPod,
            '{{ pod }}',
            description='The upstream active connections by pod over time.',
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
      dashboard.withDescription('A dashboard that monitors Envoy with a focus on giving an upstreams. %s' % mixinUtils.dashboards.dashboardDescriptionLink('envoy-mixin', 'https://github.com/adinhodovic/envoy-mixin')) +
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
