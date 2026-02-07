# Monitoring

[**OpenObserve**](https://openobserve.ai/) is the standard monitoring solution in this project. The UI gives you logs, metrics, and traces; an OpenTelemetry Collector on the server sends host and Docker container metrics into OpenObserve automatically.

Open it at [https://monitoring.rednaw.nl](https://monitoring.rednaw.nl). Log in with `openobserve_username@monitoring.local` and the password; both are in the secrets file (`secrets/infrastructure-secrets.yml`).

One dashboard, **Host Metrics**, is pre-installed from the repo (`ansible/roles/server/files/openobserve-host-metrics.json`) when you run the server playbook. You can add or change dashboards in the UI, or manage this one by editing that file and re-running the playbook.

For setup (secrets, deploy), see [Getting started](INSTALL.md) and [Secrets](secrets.md).
