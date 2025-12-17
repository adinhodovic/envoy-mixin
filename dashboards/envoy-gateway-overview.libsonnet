local mixinUtils = import 'github.com/adinhodovic/mixin-utils/utils.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local util = import 'util.libsonnet';

local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

{
  local dashboardName = 'envoy-gateway-overview',
  grafanaDashboards+:: (
    if !$._config.envoyGateway.enabled then {}
    else {
      ['%s.json' % dashboardName]:

        local defaultVariables = util.variables($._config);

        local variables = [
          defaultVariables.datasource,
          defaultVariables.envoyGatewayCluster,
          defaultVariables.envoyGatewayNamespace,
          defaultVariables.envoyGatewayJob,
        ];

        local defaultFilters = util.filters($._config);
        local queries = {
          // Resource Apply
          resourceApplyTotalByStatusKind: |||
            sum(
              rate(
                resource_apply_total{
                  %(envoyGateway)s
                }[$__rate_interval]
              )
            ) by (status, kind)
          ||| % defaultFilters,

          resourceApplyDurationP50: |||
            histogram_quantile(
              0.5,
              sum(
                rate(
                  resource_apply_duration_seconds_bucket{
                    %(envoyGateway)s
                  }[$__rate_interval]
                )
              ) by (le)
            )
          ||| % defaultFilters,
          resourceApplyDurationP95: std.strReplace(queries.resourceApplyDurationP50, '0.5', '0.95'),

          // Resource Delete
          resourceDeleteTotalByStatusKind: |||
            sum(
              rate(
                resource_delete_total{
                  %(envoyGateway)s
                }[$__rate_interval]
              )
            ) by (status, kind)
          ||| % defaultFilters,

          resourceDeleteDurationP50: |||
            histogram_quantile(
              0.5,
              sum(
                rate(
                  resource_delete_duration_seconds_bucket{
                    %(envoyGateway)s
                  }[$__rate_interval]
                )
              ) by (le)
            )
          ||| % defaultFilters,
          resourceDeleteDurationP95: std.strReplace(queries.resourceDeleteDurationP50, '0.5', '0.95'),

          // Status Update
          statusUpdateTotalByKindStatus: |||
            sum(
              rate(
                status_update_total{
                  %(envoyGateway)s
                }[$__rate_interval]
              )
            ) by (kind, status)
          ||| % defaultFilters,

          statusUpdateDurationP50: |||
            histogram_quantile(
              0.5,
              sum(
                rate(
                  status_update_duration_seconds_bucket{
                    %(envoyGateway)s
                  }[$__rate_interval]
                )
              ) by (le)
            )
          ||| % defaultFilters,
          statusUpdateDurationP95: std.strReplace(queries.statusUpdateDurationP50, '0.5', '0.95'),

          // XDS Snapshot Update
          xdsSnapshotUpdateTotalByStatusNodeID: |||
            sum(
              rate(
                xds_snapshot_update_total{
                  %(envoyGateway)s
                }[$__rate_interval]
              )
            ) by (status, nodeID)
          ||| % defaultFilters,
        };

        local panels = {
          // Resource Apply
          resourceApplyTotalTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Resource Apply Rate by Status/Kind',
              'ops',
              queries.resourceApplyTotalByStatusKind,
              '{{ status }}/{{ kind }}',
              description='Rate of Kubernetes resource apply operations by status (success/failure) and resource kind (Gateway, HTTPRoute, Service, etc.). Tracks how frequently the Envoy Gateway controller processes Gateway API resources. High failure rates indicate configuration issues, RBAC problems, or API validation errors requiring investigation.',
              stack='normal',
            ),

          resourceApplyDurationTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Resource Apply Duration',
              's',
              [
                {
                  expr: queries.resourceApplyDurationP50,
                  legend: 'P50',
                },
                {
                  expr: queries.resourceApplyDurationP95,
                  legend: 'P95',
                },
              ],
              description='Time taken to apply Kubernetes resources to the cluster (P50 and P95 percentiles). Measures controller performance when reconciling Gateway API objects. Rising latency may indicate API server overload, large resource counts, or controller performance issues. P95 spikes often precede user-visible configuration delays.',
            ),

          // Resource Delete
          resourceDeleteTotalTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Resource Delete Rate by Status/Kind',
              'ops',
              queries.resourceDeleteTotalByStatusKind,
              '{{ status }}/{{ kind }}',
              description='Rate of Kubernetes resource deletion operations by status and kind. Tracks cleanup of Gateway API resources when they are removed. High failure rates may indicate finalizer issues, orphaned resources, or permission problems preventing proper cleanup. Monitor for resource leaks.',
              stack='normal',
            ),

          resourceDeleteDurationTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Resource Delete Duration',
              's',
              [
                {
                  expr: queries.resourceDeleteDurationP50,
                  legend: 'P50',
                },
                {
                  expr: queries.resourceDeleteDurationP95,
                  legend: 'P95',
                },
              ],
              description='Time taken to delete Kubernetes resources from the cluster (P50 and P95 percentiles). Long deletion times may indicate stuck finalizers, cascading deletions, or API server performance issues. Prolonged P95 delays can prevent timely resource cleanup and cause operational issues.',
            ),

          // Status Update
          statusUpdateTotalTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Status Update Rate by Kind/Status',
              'ops',
              queries.statusUpdateTotalByKindStatus,
              '{{ kind }}/{{ status }}',
              description='Rate of status updates to Gateway API resources by kind and status. Controller writes status conditions (Accepted, Programmed, Ready) to inform users of resource state. High failure rates indicate API server connectivity issues or conflicts with other controllers. Essential for user feedback on configuration validity.',
              stack='normal',
            ),

          statusUpdateDurationTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Status Update Duration',
              's',
              [
                {
                  expr: queries.statusUpdateDurationP50,
                  legend: 'P50',
                },
                {
                  expr: queries.statusUpdateDurationP95,
                  legend: 'P95',
                },
              ],
              description='Time taken to update resource status conditions (P50 and P95 percentiles). Status updates provide feedback to users about resource health. Rising latency delays user visibility into configuration problems. P95 spikes may indicate API server throttling or status conflicts with other controllers.',
            ),

          // XDS Snapshot Update
          xdsSnapshotUpdateTotalTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'XDS Snapshot Update Rate by Status/NodeID',
              'ops',
              queries.xdsSnapshotUpdateTotalByStatusNodeID,
              '{{ status }}/{{ nodeID }}',
              description='Rate of xDS (Discovery Service) configuration snapshots pushed to Envoy data plane proxies by status and node ID. Each update delivers routing, cluster, and listener configuration to proxies. Failures indicate proxy connectivity issues or invalid configurations. High update rates may suggest configuration churn requiring optimization.',
              stack='normal',
            ),
        };

        local rows =
          [
            row.new('Envoy XDS') +
            row.gridPos.withX(0) +
            row.gridPos.withY(0) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
          ] +
          grid.wrapPanels(
            [
              panels.xdsSnapshotUpdateTotalTimeSeries,
            ],
            panelWidth=24,
            panelHeight=8,
            startY=1
          ) +
          [
            row.new('Kubernetes') +
            row.gridPos.withX(0) +
            row.gridPos.withY(9) +
            row.gridPos.withW(24) +
            row.gridPos.withH(1),
          ] +
          grid.wrapPanels(
            [
              panels.resourceApplyTotalTimeSeries,
              panels.resourceApplyDurationTimeSeries,
              panels.resourceDeleteTotalTimeSeries,
              panels.resourceDeleteDurationTimeSeries,
              panels.statusUpdateTotalTimeSeries,
              panels.statusUpdateDurationTimeSeries,
            ],
            panelWidth=12,
            panelHeight=8,
            startY=10
          );

        mixinUtils.dashboards.bypassDashboardValidation +
        dashboard.new(
          'Envoy Gateway / Overview',
        ) +
        dashboard.withDescription('Envoy Gateway control plane monitoring dashboard. Tracks XDS (xDS Discovery Service) snapshot updates to data plane proxies, Kubernetes resource reconciliation (Gateway, HTTPRoute, etc.), resource apply/delete operations with duration metrics, and status update patterns. Use this dashboard to monitor the health and performance of the Envoy Gateway controller, troubleshoot configuration propagation delays, and identify resource management bottlenecks in your Gateway API implementation. %s' % mixinUtils.dashboards.dashboardDescriptionLink('envoy-mixin', 'https://github.com/adinhodovic/envoy-mixin')) +
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
    }
  ),
}
