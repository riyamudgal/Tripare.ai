# Infrastructure & Database Reliability Assessment

This repository contains modular AWS infrastructure definitions written in Terraform alongside a containerized PostgreSQL setup with automated migrations, seed data, query indexing, and backup/restore tooling.

## Architecture Overview

Traffic flows from the public internet to an Application Load Balancer in public subnets, forwards to ECS Fargate tasks running in private subnets, and connects to a private RDS PostgreSQL instance:

```
Internet ──▶ ALB (Public Subnets) ──▶ ECS Fargate (Private Subnets) ──▶ RDS PostgreSQL (Private Subnets)
```

- **Network isolation:** RDS has `publicly_accessible = false` and its security group accepts port `5432` traffic strictly from the ECS task security group.
- **Environment separation:** `infra/envs/dev` and `infra/envs/prod` consume shared modules (`network`, `ecs`, `rds`) with distinct state backends, instance sizing, backup retention windows (1 day vs. 30 days), Multi-AZ settings, and deletion protection flags.

---

## 1. Terraform Validation & Plan Review

To validate formatting, configuration syntax, and execution plans locally without live AWS credentials:

```bash
# Check formatting across all modules and environments
terraform fmt -check -recursive infra/

# Validate and plan Dev
cd infra/envs/dev
terraform init -backend=false
terraform validate
AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_EC2_METADATA_DISABLED=true \
  terraform plan -refresh=false

# Validate and plan Prod
cd ../prod
terraform init -backend=false
terraform validate
AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_EC2_METADATA_DISABLED=true \
  terraform plan -refresh=false
```

---

## 2. Local Database Setup

Start the PostgreSQL 16 container. On initial startup, Docker automatically executes the schema creation, index creation, and seed scripts located in `db/`:

```bash
docker compose up -d
```

Verify the container is healthy and populated:

```bash
docker exec -it booking_db psql -U appuser -d bookings_db -c "\dt"
```

---

## 3. Query Optimization Notes

Target reporting query:

```sql
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi'
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
```

### Index Choice (`db/migrations/002_add_indexes.sql`)

```sql
CREATE INDEX idx_hotel_bookings_city_created_org_status 
ON hotel_bookings (city, created_at, org_id, status) 
INCLUDE (amount);
```

- **Equality before range (`city`, `created_at`):** Placing the equality predicate (`city = 'delhi'`) first narrows the B-tree scan immediately to a single city partition before scanning the 30-day range on `created_at`.
- **Covering columns (`org_id`, `status`) & `INCLUDE (amount)`:** Including the `GROUP BY` columns in the key and `amount` in the leaf payload allows PostgreSQL to satisfy the entire aggregation via an **Index-Only Scan**, avoiding random heap page reads as the table scales.

Verify the execution plan locally:

```bash
docker exec -it booking_db psql -U appuser -d bookings_db -c "
SET enable_seqscan = off;
EXPLAIN ANALYZE
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi'
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;"
```

---

## 4. Backup and Restore Verification

Ensure executable permissions are set on the scripts:

```bash
chmod +x scripts/backup.sh scripts/restore.sh
```

### Step 1: Create a timestamped dump
```bash
./scripts/backup.sh
```
This outputs a compressed custom-format dump (`pg_dump -F c`) to `./backups/bookings_db_<TIMESTAMP>.dump`.

### Step 2: Restore into a fresh database
```bash
./scripts/restore.sh
```
By default, `restore.sh` picks up the latest `.dump` file in `./backups/`, drops/recreates `bookings_db_restored`, restores the schema, indexes, and data inside a single transaction, and prints row counts.

### Step 3: Verify restored data integrity
Confirm table counts and run a sample query against the restored database:

```bash
docker exec -it booking_db psql -U appuser -d bookings_db_restored -c "
SELECT city, status, COUNT(*) AS bookings, SUM(amount) AS total_revenue
FROM hotel_bookings
GROUP BY city, status
ORDER BY city, status;"
```
