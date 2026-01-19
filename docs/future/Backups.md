# Backup Strategy

**Status**: Design Document (To be implemented when application is deployed)  
**Principle**: Everything is software-defined - backups should be too

---

## Executive Summary

This backup strategy follows a **Docker-native approach** that aligns with our software-defined infrastructure principle. Since everything runs in Docker Compose with named volumes, we use application-native backup tools (pg_dump, OpenSearch snapshots) rather than infrastructure-level snapshots.

**Key Principle**: Infrastructure is reproducible from code (Terraform + Ansible + Docker Compose). Only application data needs backup.

---

## Current Phase: Infrastructure Only (No Backups Needed)

**Status**: ✅ Correct - No backups required

**Why**:
- All infrastructure defined in Terraform (reproducible)
- All configuration in Ansible (reproducible)
- All application code in Git (already backed up)
- No databases or persistent data yet
- `terraform destroy` + `terraform apply` + `ansible:run` = full recovery

**Action**: None required at this stage

---

## Future Phase: Application Deployment (Backups Required)

**When**: When Docker Compose is deployed with databases

### What Needs Backup

#### Critical (Required):
1. **PostgreSQL Database** (`postgres_data` volume)
   - User data, application state
   - Cannot be recreated from code
   - Requires regular backups

2. **OpenSearch Indices** (`opensearch_data` volume)
   - Search indices, product data
   - Can be rebuilt but slow
   - Requires regular backups

#### Optional (Nice to Have):
3. **Redis Data** (`redis_data` volume)
   - Currently configured as ephemeral (`--save "" --appendonly no`)
   - Only backup if persistence is enabled later

4. **Monitoring Data** (`prometheus_data`, `grafana_data`, `loki_data` volumes)
   - Metrics and logs
   - Can be lost without impact (historical data only)

### What Doesn't Need Backup

- **Infrastructure**: Reproducible via Terraform
- **Configuration**: Reproducible via Ansible
- **Application Code**: Already in Git
- **Container Images**: Rebuildable from Dockerfiles

---

## Recommended Backup Strategy

### Approach: Application-Native Backups (Docker-Native)

**Why**: Software-defined, efficient, standard practice, fine-grained recovery

#### PostgreSQL Backups

**Method**: `pg_dump` (PostgreSQL's native backup tool)

```bash
# Manual backup
docker-compose exec -T postgres pg_dump -U $POSTGRES_USER $POSTGRES_DB \
  | gzip > backups/postgres_$(date +%Y%m%d_%H%M%S).sql.gz

# Automated backup (future Taskfile task)
task backup:postgres
```

**Benefits**:
- Application-aware (consistent dumps)
- Selective restore (specific tables/databases)
- Standard PostgreSQL tool
- Efficient (only data, not entire volume)

#### OpenSearch Backups

**Method**: OpenSearch Snapshot API (OpenSearch's native backup tool)

```bash
# Configure snapshot repository (one-time setup)
curl -X PUT "http://localhost:9200/_snapshot/backup_repo" \
  -H 'Content-Type: application/json' \
  -d '{ "type": "fs", "settings": { "location": "/backup/opensearch" } }'

# Create snapshot
curl -X PUT "http://localhost:9200/_snapshot/backup_repo/snapshot_$(date +%Y%m%d)?wait_for_completion=true"

# Automated backup (future Taskfile task)
task backup:opensearch
```

**Benefits**:
- Application-aware (consistent snapshots)
- Incremental snapshots (efficient)
- Standard OpenSearch tool
- Selective restore (specific indices)

#### Redis Backups (If Persistence Enabled)

**Method**: Redis `BGSAVE` or dump file copy

```bash
# If persistence is enabled later
docker-compose exec redis redis-cli BGSAVE

# Or copy dump file
docker run --rm \
  -v giftfinder_redis_data:/data:ro \
  -v $(pwd)/backups:/backup \
  alpine \
  cp /data/dump.rdb /backup/redis_$(date +%Y%m%d).rdb
```

**Note**: Currently Redis is ephemeral (`--save "" --appendonly no`), so no backup needed unless persistence is enabled.

---

## Backup Storage Strategy

### Option 1: Hetzner Storage Box (Recommended)

**Why**: 
- External from server (safer)
- Mount as volume in backup container (Docker-native)
- Integrated with Hetzner ecosystem
- Automated backups can write directly

**Implementation** (future):
- Mount Storage Box as volume in backup container
- Store backups in Storage Box volume
- Automatic off-server backup

### Option 2: External Storage (S3, etc.)

**Why**:
- Off-site backup (maximum safety)
- Cloud storage (scalable)
- Multiple regions (disaster recovery)

**Implementation** (future):
- Backup container uploads to S3
- Automated via Taskfile/Ansible
- Encrypted backups

### Option 3: Local + External (Hybrid)

**Why**:
- Local for fast restore
- External for disaster recovery

**Implementation** (future):
- Keep recent backups locally (fast restore)
- Archive old backups externally (disaster recovery)

---

## Backup Frequency & Retention

### Development Environment

- **Frequency**: Weekly or on-demand
- **Retention**: 2-4 weeks
- **Storage**: Local or minimal external storage
- **Priority**: Low (dev data can be regenerated)

### Production Environment

**Daily Backups**:
- **Frequency**: Daily (automated)
- **Retention**: 7 days
- **Storage**: External (Hetzner Storage Box or S3)
- **Priority**: High (user data)

**Weekly Backups**:
- **Frequency**: Weekly (automated)
- **Retention**: 4 weeks
- **Storage**: External
- **Priority**: Medium (recovery window)

**Monthly Backups**:
- **Frequency**: Monthly (automated)
- **Retention**: 6-12 months
- **Storage**: External (archival)
- **Priority**: Low (compliance/audit)

**Pre-Deployment Backups**:
- **Frequency**: Before major deployments
- **Retention**: Until deployment is verified stable
- **Storage**: Local or external
- **Priority**: High (rollback capability)

---

## Implementation (Future)

### Taskfile Tasks (Recommended)

```yaml
# Taskfile.backup.yml (future implementation)
backup:postgres:
  desc: Backup PostgreSQL database
  dir: /opt/giftfinder
  cmds:
    - docker-compose exec -T postgres pg_dump -U ${{.POSTGRES_USER}} ${{.POSTGRES_DB}} \
        | gzip > backups/postgres_$(date +%Y%m%d_%H%M%S).sql.gz

backup:opensearch:
  desc: Backup OpenSearch indices
  dir: /opt/giftfinder
  cmds:
    - curl -X PUT "http://localhost:9200/_snapshot/backup_repo/snapshot_$(date +%Y%m%d)?wait_for_completion=true"

backup:all:
  desc: Backup all critical data
  cmds:
    - task backup:postgres
    - task backup:opensearch

restore:postgres:
  desc: Restore PostgreSQL database from backup
  cmds:
    - docker-compose exec -T postgres psql -U ${{.POSTGRES_USER}} ${{.POSTGRES_DB}} < {{.BACKUP_FILE}}
```

### Ansible Tasks (Alternative)

```yaml
# ansible/tasks/backup.yml (future implementation)
- name: Backup PostgreSQL database
  docker_compose:
    project_src: /opt/giftfinder
    command: exec
    services: postgres
    exec_command: pg_dump -U {{ postgres_user }} {{ postgres_db }} > /backup/backup.sql

- name: Backup OpenSearch indices
  uri:
    url: "http://localhost:9200/_snapshot/backup_repo/snapshot_{{ ansible_date_time.epoch }}"
    method: PUT
```

### Automated Scheduling (Future)

**Option 1: Cron Jobs**
- System cron (`/etc/cron.daily/giftfinder-backup`)
- Simple, traditional approach
- Runs backup scripts

**Option 2: Ansible Scheduled Tasks**
- Ansible playbooks with scheduling
- More complex but integrated with configuration management

**Option 3: CI/CD Pipeline**
- Automated backups on schedule
- Integrates with deployment pipeline
- Can trigger pre-deployment backups

---

## Restore Procedures

### PostgreSQL Restore

```bash
# Restore from backup
docker-compose exec -T postgres psql -U $POSTGRES_USER $POSTGRES_DB < backup.sql

# Or from compressed backup
gunzip < backup.sql.gz | docker-compose exec -T postgres psql -U $POSTGRES_USER $POSTGRES_DB

# Selective restore (specific table)
docker-compose exec -T postgres psql -U $POSTGRES_USER $POSTGRES_DB -c "\copy table_name FROM '/backup/table_name.csv' CSV"
```

### OpenSearch Restore

```bash
# Restore snapshot
curl -X POST "http://localhost:9200/_snapshot/backup_repo/snapshot_20240115/_restore"

# Selective restore (specific index)
curl -X POST "http://localhost:9200/_snapshot/backup_repo/snapshot_20240115/_restore" \
  -H 'Content-Type: application/json' \
  -d '{ "indices": "specific_index" }'
```

### Full Disaster Recovery

**Scenario**: Complete server loss

1. **Recreate Infrastructure** (software-defined):
   ```bash
   terraform apply -- prod
   ```

2. **Reconfigure Server** (software-defined):
   ```bash
   ansible:bootstrap -- prod
   ansible:run -- prod
   ```

3. **Deploy Application** (software-defined):
   ```bash
   docker-compose up -d
   ```

4. **Restore Data** (from backups):
   ```bash
   # Restore PostgreSQL
   docker-compose exec -T postgres psql -U $POSTGRES_USER $POSTGRES_DB < backup.sql
   
   # Restore OpenSearch
   curl -X POST "http://localhost:9200/_snapshot/backup_repo/snapshot_20240115/_restore"
   ```

**Recovery Time Objective (RTO)**: 1-4 hours (infrastructure recreation + data restore)  
**Recovery Point Objective (RPO)**: Up to 24 hours (daily backups)

---

## Why Not Hetzner Snapshots?

**Hetzner snapshots are NOT needed** because:

1. **Infrastructure is software-defined**: Terraform + Ansible can recreate everything
2. **Application code is in Git**: Already backed up
3. **Configuration is in code**: Ansible can reconfigure everything
4. **Data backups are sufficient**: PostgreSQL dumps + OpenSearch snapshots cover all data

**When snapshots might be useful**:
- Faster recovery (minutes vs hours) - but not required if longer recovery is acceptable
- Configuration drift protection - but rebuilding from code eliminates drift
- Easier testing - but separate test environment is better

**Recommendation**: Skip Hetzner snapshots. Use application-native backups only.

---

## Cost Considerations

### Backup Storage Costs

**Hetzner Storage Box** (recommended):
- ~€5-10/month for 500GB-1TB
- Sufficient for daily backups with retention

**Alternative (S3)**:
- ~€0.023/GB/month (standard storage)
- ~€50-100/month for similar capacity
- More expensive but more features

**Cost Optimization**:
- Compress backups (gzip for PostgreSQL, OpenSearch snapshots are already compressed)
- Retention policy (delete old backups)
- Dev environment: less frequent backups = lower cost

### Total Backup Costs (Future - Production)

**Conservative Estimate**:
- Storage Box: ~€10/month
- Backup automation: Free (Taskfile/Ansible)
- **Total**: ~€10/month

**Comparison**:
- Hetzner snapshots: ~€20-40/month (full system snapshots)
- Docker-native backups: ~€10/month (application data only)
- **Savings**: ~50-75% by using application-native backups

---

## Monitoring & Alerting (Future)

### Backup Success Monitoring

**Requirements** (when implemented):
- Alert on backup failures
- Monitor backup storage usage
- Verify backup integrity (test restores periodically)
- Track backup ages (ensure recent backups exist)

**Implementation Options**:
- Ansible tasks with error handling
- Monitoring scripts (Prometheus metrics)
- Health checks (verify backups are recent)
- Automated restore testing (monthly)

---

## Testing & Validation

### Backup Testing (When Implemented)

**Requirements**:
- Test restores regularly (monthly recommended)
- Verify backup integrity
- Document restore procedures
- Practice disaster recovery scenarios

**Test Procedure**:
1. Create test environment
2. Restore from backup
3. Verify data integrity
4. Document any issues
5. Update procedures if needed

---

## Summary

### Current Phase (Infrastructure Only)
- ✅ **No backups needed** - Everything is reproducible from code

### Future Phase (Application Deployment)
- **Required**: PostgreSQL dumps + OpenSearch snapshots
- **Storage**: Hetzner Storage Box or external (S3)
- **Automation**: Taskfile tasks or Ansible playbooks
- **Frequency**: Daily (prod), Weekly (dev)
- **Retention**: 7 days daily, 4 weeks weekly, 6 months monthly

### Key Principles
1. **Software-defined**: Backup scripts in Git
2. **Docker-native**: Use Docker/Docker Compose
3. **Application-aware**: Use native backup tools (pg_dump, OpenSearch snapshots)
4. **Efficient**: Only backup data, not infrastructure
5. **Standard**: Use standard, well-tested tools

### Not Needed
- ❌ Hetzner snapshots (infrastructure is reproducible)
- ❌ Full system backups (only data needs backup)
- ❌ Complex backup infrastructure (simple scripts are sufficient)

---

## Next Steps (When Application is Deployed)

1. **Add backup tasks to Taskfile** (`task backup:postgres`, `task backup:opensearch`)
2. **Configure backup storage** (Hetzner Storage Box or S3)
3. **Automate backup scheduling** (cron or Ansible)
4. **Document restore procedures** (in this document or README)
5. **Test restore procedures** (monthly)
6. **Monitor backup success** (alerts on failures)

**Timeline**: Implement when Docker Compose is deployed to production with real data.

---

**Document Status**: Design/Planning - To be implemented when application deployment begins.
