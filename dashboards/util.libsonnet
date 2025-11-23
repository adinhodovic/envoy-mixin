local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local dashboard = g.dashboard;

local variable = dashboard.variable;
local datasource = variable.datasource;
local query = variable.query;

{
  filters(config):: {
    local this = self,
    cluster: '%(clusterLabel)s="$cluster"' % config,
    namespace: 'namespace=~"$namespace"',
    job: 'job=~"$job"',
    envoyClusterName: 'envoy_cluster_name=~"$envoy_cluster_name"',
    // Literal match for single selection
    envoyClusterNameSingle: 'envoy_cluster_name="$envoy_cluster_name"',
    envoyHttpConnManagerPrefix: 'envoy_http_conn_manager_prefix=~"$envoy_http_conn_manager_prefix"',
    // Literal match for single selection
    envoyHttpConnManagerPrefixSingle: 'envoy_http_conn_manager_prefix="$envoy_http_conn_manager_prefix"',
    pod: 'pod=~"$pod"',

    base: |||
      %(cluster)s,
      %(namespace)s,
      %(job)s,
      %(pod)s
    ||| % this,

    default: |||
      %(base)s
    ||| % this,

    upstream: |||
      %(default)s,
      %(envoyClusterName)s
    ||| % this,

    upstreamSingle: |||
      %(default)s,
      %(envoyClusterNameSingle)s
    ||| % this,

    downstream: |||
      %(default)s,
      %(envoyHttpConnManagerPrefix)s
    ||| % this,

    downstreamSingle: |||
      %(default)s,
      %(envoyHttpConnManagerPrefixSingle)s
    ||| % this,

    envoyGateway: |||
      %(cluster)s,
      %(namespace)s,
      %(job)s
    ||| % this,
  },

  variables(config):: {
    local this = self,

    local defaultFilters = $.filters(config),

    datasource:
      datasource.new(
        'datasource',
        'prometheus',
      ) +
      datasource.generalOptions.withLabel('Data source') +
      {
        current: {
          selected: true,
          text: config.datasourceName,
          value: config.datasourceName,
        },
      },

    cluster:
      query.new(
        config.clusterLabel,
        'label_values(envoy_cluster_upstream_rq_xx{}, cluster)',
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Cluster') +
      query.refresh.onLoad() +
      query.refresh.onTime() +
      (
        if config.showMultiCluster
        then query.generalOptions.showOnDashboard.withLabelAndValue()
        else query.generalOptions.showOnDashboard.withNothing()
      ),

    namespace:
      query.new(
        'namespace',
        'label_values(envoy_cluster_upstream_rq_xx{%(cluster)s}, namespace)' % defaultFilters
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Namespace') +
      query.selectionOptions.withMulti(false) +
      query.selectionOptions.withIncludeAll(false) +
      query.refresh.onLoad() +
      query.refresh.onTime(),


    job:
      query.new(
        'job',
        'label_values(envoy_cluster_upstream_rq_xx{%(cluster)s, %(namespace)s}, job)' % defaultFilters
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Job') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    envoyClusterName:
      query.new(
        'envoy_cluster_name',
        'label_values(envoy_cluster_upstream_rq_xx{%(cluster)s, %(namespace)s, %(job)s}, envoy_cluster_name)' % defaultFilters
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Envoy Cluster Name') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    envoyClusterNameSingle:
      this.envoyClusterName +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(false),

    envoyHttpConnManagerPrefix:
      query.new(
        'envoy_http_conn_manager_prefix',
        'label_values(envoy_http_downstream_rq_xx{%(cluster)s, %(namespace)s, %(job)s}, envoy_http_conn_manager_prefix)' % defaultFilters
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Envoy HTTP Conn Manager Prefix') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    envoyHttpConnManagerPrefixSingle:
      this.envoyHttpConnManagerPrefix +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(false),

    pod:
      query.new(
        'pod',
        'label_values(envoy_listener_http_downstream_rq_xx{%(cluster)s, %(namespace)s, %(job)s}, pod)' % defaultFilters
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Pod') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    podUpstream:
      this.pod +
      query.new(
        'pod',
        'label_values(envoy_cluster_upstream_rq_xx{%(cluster)s, %(namespace)s, %(job)s, %(envoyClusterName)s}, pod)' % defaultFilters,
      ),

    podDownstream:
      this.pod +
      query.new(
        'pod',
        'label_values(envoy_listener_http_downstream_rq_xx{%(cluster)s, %(namespace)s, %(job)s, %(envoyHttpConnManagerPrefix)s}, pod)' % defaultFilters,
      ),

    // Envoy Gateway
    envoyGatewayCluster:
      query.new(
        'cluster',
        'label_values(xds_snapshot_update_total{}, cluster)' % defaultFilters
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Cluster') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    envoyGatewayNamespace:
      query.new(
        'namespace',
        'label_values(xds_snapshot_update_total{%(cluster)s}, namespace)' % defaultFilters
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Namespace') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    envoyGatewayJob:
      query.new(
        'job',
        'label_values(xds_snapshot_update_total{%(cluster)s, %(namespace)s}, job)' % defaultFilters
      ) +
      query.withDatasourceFromVariable(this.datasource) +
      query.withSort() +
      query.generalOptions.withLabel('Job') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),
  },
}
