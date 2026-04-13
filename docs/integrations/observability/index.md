# Observability and Monitoring

Voile supports optional monitoring and observability integrations that can be enabled when you have a compatible backend available.

## What is supported today

- OpenObserve: metrics push and optional OpenTelemetry trace export.

## How it works

By default, Voile runs without external observability backends. When the corresponding environment variables are configured, Voile will:

- push PromEx metrics to the OpenObserve ingestion endpoint
- export traces using the OpenTelemetry exporter when `VOILE_OTEL_EXPORTER_ENDPOINT` is configured

## Why it is optional

OpenObserve is an external service. Voile does not bundle or run an OpenObserve instance, so you must provide your own OpenObserve deployment or hosted endpoint.

## Future tools

We plan to support additional monitoring and observability systems in the future, including:

- Prometheus / Grafana
- Loki
- Datadog
- New Relic
- Other OpenTelemetry-compatible backends

## Getting started

1. Create or provision an OpenObserve instance.
2. Configure Voile using the settings in the OpenObserve integration guide.
3. Restart Voile and verify metrics/traces are arriving in OpenObserve.

## See also

- [OpenObserve integration](openobserve.md)
