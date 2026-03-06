[**<---**](README.md)

# Onboarding

Pick your path:

## New project

You have an app and want to deploy it on your own Hetzner server. You will create the infrastructure from scratch, then deploy.

| Step | What you do | Time |
|------|-------------|------|
| 1. **[New project](new-project.md)** | Create SOPS keys, secrets file, external accounts (Hetzner, Terraform Cloud), provision the server with Terraform + Ansible, set up DNS. | ~60 min |
| 2. **[Launch devcontainer](launch-devcontainer.md)** | Open the IaC workspace in the devcontainer. It decrypts secrets and configures all credentials automatically. | ~5 min |
| 3. **[Application deployment](application-deployment.md)** | Set up your app mount, write the deploy override and Traefik labels, run your first deploy. | ~30 min |
| 4. **[App secrets](secrets.md#creating-app-secrets)** | Create `.iac/.env` with app runtime secrets (database URL, API keys). | ~10 min |

When done: your app is live at `https://<your-domain>` with TLS, a private registry, and monitoring.

**Reference implementation:** [tientje-ketama](https://github.com/rednaw/tientje-ketama) is a working app that uses this platform. Use its `.iac/` directory as a reference for file structure and Traefik labels.

---

## Join an existing project

The infrastructure exists. You need access, then you can operate and deploy.

| Step | What you do | Time |
|------|-------------|------|
| 1. **[Joining](joining.md)** | Get your SOPS key added to the keyring, add your SSH key and IP to the firewall. | ~20 min (includes waiting for teammate) |
| 2. **[Launch devcontainer](launch-devcontainer.md)** | Open the IaC workspace in the devcontainer. It decrypts secrets and configures all credentials automatically. | ~5 min |

When done: you can deploy, inspect, and operate. Run `task app:versions -- dev` to see available versions.

---

## Explore

After onboarding, use the [Reference](README.md#reference) for operations, troubleshooting, and details.
