# OpenObserve Integration

Voile can send observability data to OpenObserve using two optional mechanisms:

- metrics push via PromEx
- trace export via OpenTelemetry

This integration is optional and requires an external OpenObserve instance.

## Environment variables

Set these variables in your runtime environment or `.env` file.

```bash
VOILE_OTEL_EXPORTER_ENDPOINT="https://<your-openobserve-host>/openobserve/api/<tenant_id>"
VOILE_OPENOBSERVE_AUTH="<username>:<password>"
VOILE_OPENOBSERVE_ORG="<tenant_id>"
VOILE_OPENOBSERVE_METRICS_URL="https://<your-openobserve-host>/openobserve/api/<tenant_id>/prometheus/api/v1/write"
```

> Use the same tenant identifier in `VOILE_OPENOBSERVE_ORG` and the OpenObserve API URL path when applicable.

### Notes

- `VOILE_OPENOBSERVE_METRICS_URL` enables PromEx metrics push.
- `VOILE_OPENOBSERVE_AUTH` is used as raw Basic auth credentials and will be Base64 encoded by Voile.
- `VOILE_OPENOBSERVE_ORG` defaults to `default` if not provided.
- `VOILE_OTEL_EXPORTER_ENDPOINT` enables trace export through OpenTelemetry.

## Metrics

When `VOILE_OPENOBSERVE_METRICS_URL` is present, Voile configures `Voile.PromEx` to push metrics to OpenObserve.

If the variable is not set, Voile continues to run normally but will not push metrics.

## Traces

When `VOILE_OTEL_EXPORTER_ENDPOINT` is present, Voile configures the OpenTelemetry exporter with the given endpoint.

If the variable is not set, traces are not exported and the OpenTelemetry traces exporter is disabled.

## Example setup

```bash
VOILE_OPENOBSERVE_METRICS_URL="https://openobserve.example.com/api/v1/push/metrics"
VOILE_OPENOBSERVE_AUTH="openobserve-token"
VOILE_OPENOBSERVE_ORG="default"
VOILE_OTEL_EXPORTER_ENDPOINT="https://openobserve.example.com/api/v1/otlp/v1/traces"
```

## Troubleshooting

- Confirm the OpenObserve endpoint URLs are reachable from your Voile deployment.
- Verify `VOILE_OPENOBSERVE_AUTH` contains the correct credentials.
- Check OpenObserve logs or UI for rejected requests.
- If metrics are not visible, confirm `VOILE_OPENOBSERVE_METRICS_URL` is configured.
- If traces are not visible, confirm `VOILE_OTEL_EXPORTER_ENDPOINT` is configured.

## Future support

This guide covers OpenObserve, but Voile aims to support additional observability tools in the future. If you need a different backend, please open an issue or contribute a plugin.
