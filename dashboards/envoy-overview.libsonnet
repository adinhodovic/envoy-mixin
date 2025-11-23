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
            description='The total number of Envoy pods being monitored.',
          ),

        upstreamsCountStat:
          mixinUtils.dashboards.statPanel(
            'Upstreams',
            'short',
            queries.upstreamsCount,
            description='The total number of upstreams being monitored.',
          ),

        downstreamsCountStat:
          mixinUtils.dashboards.statPanel(
            'Downstreams',
            'short',
            queries.downstreamsCount,
            description='The total number of downstreams being monitored.',
          ),

        upstreamActiveCxStat:
          mixinUtils.dashboards.statPanel(
            'Upstream Active Connections',
            'short',
            queries.upstreamActiveCx,
            description='The total number of active upstream connections across all Envoy clusters being monitored.',
          ),

        downstreamActiveCxStat:
          mixinUtils.dashboards.statPanel(
            'Downstream Active Connections',
            'short',
            queries.downstreamActiveCx,
            description='The total number of active downstream connections across all Envoy clusters being monitored.',
          ),

        membershipHealthyPercentStat:
          mixinUtils.dashboards.statPanel(
            'Membership Healthy Percent',
            'percent',
            queries.membershipHealthyPercent,
            description='The percentage of healthy members in the Envoy clusters being monitored.',
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

        downstreamRateByEnvoyHttpConnManagerPrefixPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Downstream Rate by Envoy HTTP Conn Manager Prefix [1h]',
            'reqps',
            queries.downstreamRateByEnvoyHttpConnManagerPrefix1h,
            '{{ envoy_http_conn_manager_prefix }}',
            description='The distribution of downstream request rates by Envoy HTTP connection manager prefix.',
          ),

        upstreamRateByPodPieChart:
          mixinUtils.dashboards.pieChartPanel(
            'Upstream Rate by Pod [1h]',
            'reqps',
            queries.upstreamRateByPod1h,
            '{{ pod }}',
            description='The distribution of upstream request rates by pod.',
          ),

        // Upstream
        upstreamRateByEnvoyClusterNameTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Upstream Rate',
            'reqps',
            queries.upstreamRate,
            'Upstream',
            description='The upstream request rate over time.',
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

        upstreamCxActiveTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'Upstream Active Connections',
            'connections',
            queries.upstreamCxActive,
            '{{ envoy_cluster_name }}',
            description='The number of active upstream connections by Envoy cluster name over time.',
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
            tbPanelOptions.link.withTitle('Go To Application') +
            tbPanelOptions.link.withType('dashboard') +
            tbPanelOptions.link.withUrl(
              '/d/%s/envoy-application-overview?&var-project=${__data.fields.Project}&var-application=${__data.fields.Application}' % $._config.dashboardIds['envoy-overview']
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
                expr: queries.downstreamSuccesRate5xx,
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
            tbPanelOptions.link.withTitle('Go To Application') +
            tbPanelOptions.link.withType('dashboard') +
            tbPanelOptions.link.withUrl(
              '/d/%s/envoy-application-overview?&var-project=${__data.fields.Project}&var-application=${__data.fields.Application}' % $._config.dashboardIds['envoy-overview']
            ) +
            tbPanelOptions.link.withTargetBlank(true),
          ]),

        sslExpirationsByEnvoyTlsCertificateTimeSeries:
          mixinUtils.dashboards.timeSeriesPanel(
            'SSL Expirations by Envoy TLS Certificate',
            'dateTimeAsIso',
            queries.sslExpirationsByEnvoyTlsCertificate,
            '{{ envoy_tls_certificate }}',
            description='The SSL certificate expiration times by Envoy TLS certificate over time.',
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
      dashboard.withDescription('A dashboard that monitors Envoy with a focus on giving an overview. %s' % mixinUtils.dashboards.dashboardDescriptionLink('envoy-mixin', 'https://github.com/adinhodovic/envoy-mixin')) +
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
