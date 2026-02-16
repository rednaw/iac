# Traefik Migration Investigation

**Status:** Investigation Phase - No code changes yet

This directory contains documentation investigating the replacement of Nginx + Certbot with Traefik as the reverse proxy and SSL termination layer.

## Project Context

- **Early stage**: Test apps only (tientje-ketama, hello-world)
- **Solo project**: No team coordination needed
- **No production users**: Low risk for changes
- **Greenfield & Automated**: Everything managed through infrastructure-as-code
- **Future plans**: Multi-server architecture, multiple apps, other developers

This context makes migration straightforward - no backups or rollback plans needed. Everything can be rebuilt from infrastructure-as-code if needed.

**Multi-domain:** The implementation plan uses a single `base_domain` variable (default `rednaw.nl`) and derives all hostnames from it, so another developer can use a different top-level domain later without forking the playbooks.

## Documents

- **[Decision Summary](decision-summary.md)** - ⭐ **Start here** - Executive summary and recommendation
- **[Key Decisions](key-decisions.md)** - ⭐ **Answers to key questions** - Explicit decisions on all implementation choices
- **[Implementation Plan](implementation-plan.md)** - ⭐ **Actionable steps** - Detailed implementation plan with open decisions and checklist
- **[Overview & Comparison](overview.md)** - High-level comparison of Nginx/Certbot vs Traefik
- **[Current Architecture](current-architecture.md)** - Detailed analysis of the existing Nginx/Certbot setup
- **[Traefik Architecture](traefik-architecture.md)** - Proposed Traefik-based architecture
- **[Configuration Examples](configuration-examples.md)** - Traefik configuration examples for each service
- **[Migration Guide](migration-guide.md)** - Step-by-step migration plan
- **[Considerations & Trade-offs](considerations.md)** - Benefits, drawbacks, and decision factors

## Quick Summary

### Current Setup (Nginx + Certbot)
- **Nginx**: Reverse proxy with manual configuration files
- **Certbot**: Let's Encrypt certificate management via webroot challenge
- **Configuration**: Jinja2 templates in Ansible, separate files per domain
- **SSL**: Manual certificate paths, SAN certificates for multiple domains

### Proposed Setup (Traefik)
- **Traefik**: Reverse proxy with automatic service discovery
- **ACME**: Built-in Let's Encrypt integration (HTTP-01 or DNS-01 challenge)
- **Configuration**: Docker labels or file-based config
- **SSL**: Automatic certificate provisioning and renewal

## Key Questions to Answer

✅ **All answered** - See [Key Decisions](key-decisions.md) for detailed answers:

1. **Service Discovery**: Hybrid approach (Docker labels for apps, file provider for routing)
2. **Certificate Management**: HTTP-01 challenge (simpler, sufficient)
3. **Basic Auth**: Traefik middleware (consistent, centralized)
4. **Fail2ban Integration**: Update to monitor Traefik logs (common log format)
5. **Deployment Impact**: Add Traefik labels to docker-compose files (minimal changes)

## Quick Recommendation

Given the project context (early stage, solo project, future multi-server plans, multiple apps):
- **Recommendation**: Migrate to Traefik now (or before adding next app)
- **Rationale**: Early stage = low migration cost, future plans favor Traefik
- **See**: [Decision Summary](decision-summary.md) for detailed analysis

## Next Steps

1. Read [Decision Summary](decision-summary.md) for recommendation
2. Review [Key Decisions](key-decisions.md) for answers to implementation questions
3. **Resolve open decisions** in [Implementation Plan](implementation-plan.md#open-decisions-resolve-before-starting)
4. **Execute** [Implementation Plan](implementation-plan.md) step by step (use the checklist)
5. Reference [Configuration Examples](configuration-examples.md) and [Migration Guide](migration-guide.md) as needed
