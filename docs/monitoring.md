[**<---**](README.md)
# Monitoring

[**OpenObserve**](https://openobserve.ai/) is the standard monitoring solution in this project. The UI gives you logs, metrics, and traces; an OpenTelemetry Collector on the server sends host and Docker container metrics into OpenObserve automatically.

Open it at **https://observe.&lt;base_domain&gt;** (e.g. [https://observe.rednaw.nl](https://observe.rednaw.nl)). Log in with `openobserve_username@observe.local` and the password; both are in the secrets file (`secrets/infrastructure-secrets.yml`).

**Host Metrics** and **Docker Container Metrics** dashboards are imported from the repo when you run the server playbook (`ansible/roles/server/files/openobserve-host-metrics.json`, `openobserve-docker-metrics.json`). You can add or change dashboards in the UI, or edit those files and re-run the playbook.

For setup (secrets, deploy), see [Onboarding](onboarding.md) and [Secrets](secrets.md).
