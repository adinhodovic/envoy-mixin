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
              description='The rate of resource apply operations by status and kind.',
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
              description='The duration of resource apply operations (P50 and P95).',
            ),

          // Resource Delete
          resourceDeleteTotalTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Resource Delete Rate by Status/Kind',
              'ops',
              queries.resourceDeleteTotalByStatusKind,
              '{{ status }}/{{ kind }}',
              description='The rate of resource delete operations by status and kind.',
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
              description='The duration of resource delete operations (P50 and P95).',
            ),

          // Status Update
          statusUpdateTotalTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'Status Update Rate by Kind/Status',
              'ops',
              queries.statusUpdateTotalByKindStatus,
              '{{ kind }}/{{ status }}',
              description='The rate of status update operations by kind and status.',
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
              description='The duration of status update operations (P50 and P95).',
            ),

          // XDS Snapshot Update
          xdsSnapshotUpdateTotalTimeSeries:
            mixinUtils.dashboards.timeSeriesPanel(
              'XDS Snapshot Update Rate by Status/NodeID',
              'ops',
              queries.xdsSnapshotUpdateTotalByStatusNodeID,
              '{{ status }}/{{ nodeID }}',
              description='The rate of XDS snapshot updates by status and node ID.',
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
        dashboard.withDescription('A dashboard that monitors Envoy Gateway with a focus on resource management and XDS updates. %s' % mixinUtils.dashboards.dashboardDescriptionLink('envoy-mixin', 'https://github.com/adinhodovic/envoy-mixin')) +
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
