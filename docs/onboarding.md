[**<---**](README.md)

# Onboarding

## New project

You have an app and want it to run on this platform. You need **your own server in your own Hetzner account**. Follow these steps:

1. **[New project](new-project.md)** — Create your server and platform (prerequisites, SOPS, secrets file, Terraform Cloud, Terraform, Ansible). When done you have a server, Traefik, registry, and the rest.

2. **[Launch the IaC devcontainer](launch-devcontainer.md)** — Open the workspace and start the devcontainer. It decrypts secrets and configures registry, Terraform Cloud, and hcloud.

3. **[Application deployment](application-deployment.md)** — Set up your app:
   - Run `setup-app-path.sh` to configure the app mount.
   - Fill in `app/.iac/iac.yml`, write your `docker-compose.yml` with Traefik labels.
   - Run your first deploy with `task app:deploy`.

4. **[Secrets](secrets.md)** — [App secrets](secrets.md#creating-new-app-secrets) (`.env`, `.sops.yaml`).


## Join an existing project

The project already exists. Get access, then operate:

1. **[Joining](joining.md)** — Get added to the SOPS keyring, add your SSH key and IP to secrets.

2. **[Launch the IaC devcontainer](launch-devcontainer.md)** — Open the workspace and start the devcontainer. It decrypts secrets and configures registry, Terraform Cloud, and hcloud.


## Explore
After that you're in. Use the [Reference](README.md#reference) for operations, troubleshooting, and details.
