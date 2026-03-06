[**<---**](README.md)

# Monitoring

OpenObserve shows logs, metrics, and traces. An OpenTelemetry Collector on the server sends host and Docker container metrics automatically.

```mermaid
flowchart LR
    subgraph SERVER["Server"]
        H(Host metrics & logs)
        D(Docker container metrics)
    end

    subgraph APPS["Apps"]
        A(App logs & traces)
    end

    subgraph OPENOBSERVE["OpenObserve"]
        O(Dashboards<br/>logs / metrics / traces)
    end

    H --> O
    D --> O
    A --> O
```

## Access

OpenObserve is not exposed publicly (no DNS). Use an SSH tunnel to the server, then open **http://localhost:5081** in your browser. See [Remote-SSH](remote-ssh.md) for setting up SSH and port forwarding. Log in with `openobserve_username@observe.local` and the password from `app/.iac/iac.yml` (decrypt in VS Code).

## Dashboards

Three dashboards are pre-installed: **Host Metrics**, **Docker Container Metrics**, and **Traefik Metrics**. Ansible manages them — it creates each dashboard on first run and updates it when the source JSON changes. To add or modify a dashboard, edit the file in `ansible/roles/server/files/` and re-run the playbook, or make changes directly in the OpenObserve UI.

## Logs

Logs are sent from the server by the OTEL Collector into the **default** org. In OpenObserve, open **Logs** and choose a stream:

| Stream | Contents |
|--------|----------|
| `traefik-access` | HTTP access log from Traefik (method, path, status, duration) |
| `docker-containers` | stdout/stderr from all Docker containers on the server |
| `syslog` | System-level events from the host OS |
| `auth` | SSH authentication events (logins, failures) |
| `fail2ban` | IPs banned or unbanned by fail2ban |

Logs are sent to separate streams by using a different OTLP endpoint path per source (`/api/default/<stream_name>`). If you only see a single "default" stream, ensure the server playbook has been applied and the OTEL collector has been restarted so it uses the per-stream endpoints.

### Fail2ban logs not showing

1. **Confirm fail2ban is writing** (on the server):  
   `sudo tail -20 /var/log/fail2ban.log`  
   You should see lines like `Ban 1.2.3.4` / `Unban 1.2.3.4`. If the file is empty or missing, fix fail2ban first.

2. **Confirm the collector can see the file** (on the server):  
   `docker exec otel-collector cat /var/log/fail2ban.log | tail -20`  
   If this is empty but the host file has content, the log volume mount is wrong — re-run the server playbook so the collector uses the updated `/var/log` mount.

3. **Check the stream name in OpenObserve:**  
   Open **Logs**, then the stream dropdown (or "Add stream"). The fail2ban pipeline sets `service.name` to **`fail2ban`**, so the stream is usually named **fail2ban**. If you have multiple orgs, ensure you're in **default**.

4. **Stream only appears after data is sent:**  
   OpenObserve may not list a stream until at least one log line has been ingested. Trigger a ban (or run `sudo fail2ban-client set traefik-badbots banip 127.0.0.1` then unban) and wait a minute, then refresh the stream list.

5. **Collector errors:**  
   `docker logs otel-collector 2>&1 | grep -i fail2ban`  
   Look for file-not-found or permission errors.

## Related

For setup (secrets, deploy), see [Onboarding](onboarding.md) and [Secrets](secrets.md).
