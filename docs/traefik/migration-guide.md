# Migration Guide: Nginx/Certbot → Traefik

[**<---**](README.md)

This guide provides a step-by-step plan for migrating from Nginx + Certbot to Traefik.

## Project Context

**Current State**:
- Early-stage project with test apps only (tientje-ketama, hello-world)
- No production users
- Solo project (no team coordination needed)
- Single server setup

**Why Migrate Now**:
- Low risk (no production users)
- Easier migration (fewer services)
- Establishes foundation for future growth
- Better fit for multi-server plans
- Simplifies adding apps by other developers

## Prerequisites

- [ ] Review all documentation in `docs/traefik/`
- [ ] Understand current Nginx configuration
- [ ] Have access to dev environment for testing
- [ ] Understand Docker networking
- [ ] Read [Decision Summary](decision-summary.md) for context

**Note**: Since everything is automated and greenfield, there's no need for backups or rollback plans. Infrastructure-as-code means you can always rebuild from scratch if needed.

## Migration Strategy

**Note**: Since this is an early-stage project with test apps only, the migration can be more straightforward. There's no production traffic to worry about, making this a good time to establish the architecture.

### Phase 1: Preparation
1. Review Traefik documentation
2. Create Traefik configuration files
3. Prepare Ansible role for Traefik

### Phase 2: Setup & Test (Dev Environment)
1. Install Traefik in dev environment
2. Configure Traefik with all routes
3. Test certificate provisioning
4. Verify all services work through Traefik

### Phase 3: Production Migration
1. Install Traefik in production
2. Migrate all services at once (or one by one)
3. Test thoroughly
4. Switch from Nginx to Traefik

### Phase 4: Cleanup
1. Remove Nginx and Certbot
2. Clean up old configuration files
3. Update Ansible playbooks
4. Update documentation
5. Update fail2ban configuration

## Detailed Steps

### Phase 1: Preparation

#### 1.1 Document Current Setup

- [ ] List all domains and their backends
- [ ] Document SSL certificate details
- [ ] Note any custom Nginx configurations
- [ ] Document fail2ban rules
- [ ] List all middleware/headers in use

#### 1.2 Create Traefik Configuration

Create configuration files based on [Configuration Examples](configuration-examples.md):

- [ ] `traefik.yml` (static config)
- [ ] `dynamic/redirects.yml`
- [ ] `dynamic/middlewares.yml`
- [ ] `dynamic/tls.yml`

#### 1.3 Create Ansible Role

Create `ansible/roles/server/tasks/traefik.yml`:

- [ ] Install Traefik (Docker or binary)
- [ ] Create directories
- [ ] Copy configuration files
- [ ] Create Docker network
- [ ] Start Traefik container/service

### Phase 2: Parallel Setup

#### 2.1 Install Traefik (Dev Environment)

```bash
# Run Ansible playbook for dev
task ansible:run -- dev

# Or manually:
# 1. Create Traefik network
docker network create traefik

# 2. Start Traefik container
docker run -d \
  --name traefik \
  --network traefik \
  -p 8080:8080 \
  -p 80:80 \
  -p 443:443 \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v /etc/traefik:/etc/traefik:ro \
  traefik:v3.0 \
  --configfile=/etc/traefik/traefik.yml
```

#### 2.2 Configure Traefik

- [ ] Copy static configuration
- [ ] Copy dynamic configuration files
- [ ] Set up htpasswd for registry
- [ ] Configure ACME (Let's Encrypt)

#### 2.3 Test Traefik Independently

```bash
# Check Traefik is running
docker ps | grep traefik

# Check logs
docker logs traefik

# Access dashboard (if enabled)
curl http://localhost:8080/api/rawdata

# Test HTTP endpoint
curl -I http://localhost:80
```

#### 2.4 Test Certificate Provisioning

- [ ] Create test container with labels
- [ ] Verify Traefik detects container
- [ ] Check certificate is requested
- [ ] Verify certificate is obtained
- [ ] Test HTTPS connection

### Phase 3: Gradual Migration

#### 3.1 Migrate Application Service

Since you're working with test apps, you can migrate directly. However, if you want to be cautious:

**Option A: Direct Migration (Recommended for Test Apps)**
- Migrate directly since there are no production users
- Test thoroughly before considering it done

**Option B: Parallel Testing (If Cautious)**
- Run Traefik on different ports (8080/8443) initially
- Test everything works
- Switch to standard ports when confident

**Steps**:

```yaml
# Add labels to application container
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.app.rule=Host(`dev.rednaw.nl`)"
  - "traefik.http.routers.app.entrypoints=websecure"
  - "traefik.http.routers.app.tls.certresolver=letsencrypt"
  - "traefik.http.services.app.loadbalancer.server.port=3000"
```

- [ ] Add labels to app container
- [ ] Restart container
- [ ] Verify route appears in Traefik dashboard
- [ ] Test HTTP → HTTPS redirect
- [ ] Test application functionality
- [ ] Verify SSL certificate
- [ ] Check logs for errors

#### 3.2 Migrate Registry Service

- [ ] Add Traefik labels to registry container
- [ ] Configure basic auth middleware
- [ ] Test authentication
- [ ] Test image push/pull
- [ ] Verify large file uploads work
- [ ] Test `/v2/` endpoint

#### 3.3 Migrate OpenObserve Service

- [ ] Add Traefik labels to OpenObserve container
- [ ] Configure WebSocket support
- [ ] Test monitoring interface
- [ ] Verify WebSocket connections work

#### 3.4 Migrate Redirect Rules

- [ ] Create redirect middleware
- [ ] Configure file provider for redirects
- [ ] Test www.rednaw.nl redirect
- [ ] Test apex domain redirect

### Phase 4: Cutover

#### 4.1 Final Verification

Before switching:

- [ ] All services tested through Traefik
- [ ] SSL certificates valid
- [ ] All routes working
- [ ] Authentication working
- [ ] Monitoring shows no errors

#### 4.2 Switch Routing

Since this is a test environment with no production users, you can switch directly:

```bash
# Stop Nginx
sudo systemctl stop nginx
sudo systemctl disable nginx

# Traefik should already be running on 80/443
# Verify it's listening
sudo netstat -tlnp | grep -E ':(80|443)'
# or
docker ps | grep traefik
```

**Note**: If you ran Traefik on different ports for testing, update Traefik configuration to use 80/443 and restart it before stopping Nginx.

#### 4.3 Verify Services

```bash
# Test each domain
curl -I https://dev.rednaw.nl
curl -I https://registry.rednaw.nl/v2/
curl -I https://monitoring.rednaw.nl
curl -I https://www.rednaw.nl  # Should redirect

# Test authentication
curl -u user:pass https://registry.rednaw.nl/v2/

# Check Traefik dashboard
curl http://localhost:8080/api/rawdata
```

#### 4.4 Monitor

- [ ] Check Traefik logs: `docker logs -f traefik`
- [ ] Check application logs
- [ ] Monitor SSL certificate renewal
- [ ] Watch for errors in dashboard
- [ ] Check fail2ban (if configured)

### Phase 5: Cleanup

#### 5.1 Remove Nginx

```bash
# Stop and disable Nginx
sudo systemctl stop nginx
sudo systemctl disable nginx

# Remove Nginx packages
sudo apt remove nginx nginx-common
sudo apt autoremove
```

#### 5.2 Remove Certbot

```bash
# Stop certbot timer
sudo systemctl stop certbot.timer
sudo systemctl disable certbot.timer

# Remove Certbot packages
sudo apt remove certbot python3-certbot-nginx
```

#### 5.3 Clean Up Configuration

```bash
# Remove Nginx configs
sudo rm -rf /etc/nginx
sudo rm -rf /var/www/html  # If not needed

# Remove Let's Encrypt (Traefik manages certificates)
sudo rm -rf /etc/letsencrypt
```

#### 5.4 Update Fail2ban

Update fail2ban configuration to monitor Traefik logs:

```ini
# /etc/fail2ban/jail.local
[traefik-auth]
enabled = true
port = http,https
logpath = /var/log/traefik/access.log
maxretry = 3
```

Update filter for Traefik log format (JSON or common log format).

#### 5.5 Update Ansible

- [ ] Remove Nginx tasks from Ansible
- [ ] Remove Certbot tasks
- [ ] Add Traefik tasks
- [ ] Update templates
- [ ] Test Ansible playbook on clean server

#### 5.6 Update Documentation

- [ ] Update architecture diagrams
- [ ] Update deployment guides
- [ ] Update troubleshooting docs
- [ ] Document Traefik-specific procedures

## If Something Goes Wrong

Since everything is automated and greenfield:

1. **Fix the issue**: Update Ansible/Traefik configuration
2. **Re-run Ansible**: `task ansible:run -- <workspace>`
3. **Or rebuild**: Destroy and recreate infrastructure if needed (`task terraform:destroy` then `task terraform:apply`)

No rollback needed - just fix and redeploy. Infrastructure-as-code means you can always rebuild from scratch.

## Testing Checklist

### Pre-Migration

- [ ] Current setup documented
- [ ] Traefik configuration tested
- [ ] Ansible role created and tested

### During Migration

- [ ] Traefik starts successfully
- [ ] Docker network created
- [ ] Containers can reach Traefik
- [ ] Routes appear in dashboard
- [ ] SSL certificates obtained
- [ ] HTTP → HTTPS redirect works

### Per Service

**Application**:
- [ ] HTTP redirects to HTTPS
- [ ] HTTPS serves application
- [ ] All routes work
- [ ] Headers are correct
- [ ] Health checks work

**Registry**:
- [ ] Basic auth works
- [ ] Image push works
- [ ] Image pull works
- [ ] Large files upload
- [ ] `/v2/` endpoint accessible

**OpenObserve**:
- [ ] HTTPS works
- [ ] WebSocket connections work
- [ ] Dashboard loads
- [ ] All features functional

**Redirects**:
- [ ] www.rednaw.nl redirects
- [ ] apex domain redirects
- [ ] Redirects are permanent (301)
- [ ] SSL certificates work

### Post-Migration

- [ ] All services accessible
- [ ] SSL certificates valid
- [ ] No errors in logs
- [ ] Fail2ban working
- [ ] Monitoring working
- [ ] Documentation updated

## Common Issues & Solutions

### Issue: Traefik can't access Docker socket

**Solution**:
```bash
# Check permissions
ls -l /var/run/docker.sock

# Add user to docker group (if needed)
sudo usermod -aG docker traefik-user
```

### Issue: Certificates not obtained

**Solution**:
- Check ACME configuration
- Verify port 80 is accessible
- Check DNS resolution
- Review Traefik logs
- Check Let's Encrypt rate limits

### Issue: Routes not appearing

**Solution**:
- Verify `traefik.enable=true` label
- Check container is on Traefik network
- Verify label syntax
- Check Traefik logs
- Restart container

### Issue: Basic auth not working

**Solution**:
- Verify htpasswd file path
- Check file permissions
- Verify middleware is applied
- Test with curl: `curl -u user:pass https://registry.rednaw.nl/v2/`

### Issue: WebSocket not working

**Solution**:
- Add WebSocket headers middleware
- Verify `Upgrade` and `Connection` headers
- Check backend supports WebSocket
- Review Traefik logs

## Timeline Estimate

Given the early-stage context (test apps, no production users):

- **Phase 1 (Preparation)**: 2-3 hours
- **Phase 2 (Setup & Test)**: 2-4 hours
- **Phase 3 (Production Migration)**: 2-3 hours
- **Phase 4 (Cleanup)**: 1-2 hours

**Total**: 7-12 hours (can be done in 1-2 days)

**Note**: Since there are no production users, you can move faster and don't need extensive testing periods between phases.

## Benefits After Migration

Once migrated, adding new apps becomes much simpler:
- **New app by other developer**: Just add Traefik labels to their docker-compose.yml
- **No Ansible changes**: Labels handle routing automatically
- **Automatic SSL**: Certificates provision automatically
- **Multi-server ready**: Traefik scales better when you add more servers
- **Fully automated**: Everything managed through infrastructure-as-code

## Next Steps

1. Review [Decision Summary](decision-summary.md) for context
2. Review this guide
3. Set up Traefik in dev environment
4. Test with existing apps (tientje-ketama, hello-world)
5. Migrate production when confident
6. Document Traefik usage for future developers
