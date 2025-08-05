# GoodSongs API Deployment Guide

This guide covers how to deploy the GoodSongs API to production using Kamal.

## Prerequisites

- Docker installed locally
- Access to the production server (SSH key configured)
- Docker Hub account with push access to `angiehemans/goodsongs-api`
- Kamal gem installed (`gem install kamal`)

## Quick Deploy

For routine deployments after the initial setup:

```bash
kamal deploy
```

That's it! The deployment should complete in ~20-30 seconds.

## Configuration Files

The deployment uses these key files:

### `config/deploy.yml`
- Main Kamal configuration
- Defines servers, environment variables, and deployment settings
- Uses `RAILS_ENV: development` for simplified deployment (avoids Rails credentials complexity)

### `.kamal/secrets`
- Contains sensitive environment variables
- **Never commit this file to git**
- Required variables:
  - `SECRET_KEY_BASE`
  - `DATABASE_URL`
  - `JWT_SECRET_KEY`
  - `SPOTIFY_CLIENT_ID`
  - `SPOTIFY_CLIENT_SECRET`
  - `POSTGRES_PASSWORD`
  - `KAMAL_REGISTRY_PASSWORD`

## Environment Setup

The API runs with these environment variables:

**Clear (non-secret) variables:**
- `RAILS_ENV: development`
- `RAILS_LOG_LEVEL: info`
- `DB_HOST: goodsongs-api-db`
- `FRONTEND_URL: https://www.goodsongs.app`

**Secret variables** (from `.kamal/secrets`):
- Database credentials
- JWT secret
- Spotify OAuth credentials
- Docker registry access

## Infrastructure

### Server
- Production server: `143.198.62.246`
- Domain: `api.goodsongs.app`
- SSL: Handled automatically by Kamal proxy with Let's Encrypt

### Services
- **PostgreSQL**: Container `goodsongs-api-db` on port 5433
- **Redis**: Container `goodsongs-api-redis` on port 6379
- **Rails API**: Main application container with health checks

## Common Commands

### Deploy
```bash
kamal deploy                    # Full deployment
```

### Database
```bash
kamal app exec "bin/rails db:migrate"           # Run migrations
kamal app exec "bin/rails db:seed"              # Seed database
kamal app exec "bin/rails console"              # Rails console
```

### Monitoring
```bash
kamal app logs                  # View application logs
kamal app logs -f               # Follow logs in real-time
kamal proxy logs                # View proxy logs
```

### Container Management
```bash
kamal app details              # Show running containers
kamal app stop                 # Stop the application
kamal app start                # Start the application
kamal app restart              # Restart the application
```

### Accessories (Database/Redis)
```bash
kamal accessory logs db        # Database logs
kamal accessory logs redis     # Redis logs
kamal accessory stop db        # Stop database
kamal accessory start db       # Start database
```

## Troubleshooting

### Deployment Fails
1. Check logs: `kamal app logs`
2. Verify secrets file has correct values
3. Ensure Docker Hub access token is valid
4. Check server SSH access

### Database Issues
1. Check database is running: `kamal accessory details db`
2. Verify database connection: `kamal app exec "bin/rails db:version"`
3. Run migrations if needed: `kamal app exec "bin/rails db:migrate"`

### SSL/Domain Issues
1. Check proxy status: `kamal proxy logs`
2. Verify DNS points to server IP: `143.198.62.246`
3. Let's Encrypt certificates auto-renew

### Health Check Failures
The app has a health check at `/up`. If deployments fail with timeout:
1. Check if Rails is starting properly in logs
2. Verify database connectivity
3. Ensure all required environment variables are set

## Complete Teardown & Fresh Deploy

If you need to completely reset the deployment:

```bash
# 1. Remove everything
kamal app remove
kamal server exec "docker system prune -af --volumes"

# 2. Fresh setup
kamal setup

# 3. Run migrations
kamal app exec "bin/rails db:migrate"
```

## File Structure

```
goodsongs_api/
├── config/
│   ├── deploy.yml              # Main Kamal config
│   └── init.sql               # Database initialization
├── .kamal/
│   └── secrets                # Secret environment variables
└── DEPLOYMENT.md              # This file
```

## Security Notes

- `.kamal/secrets` contains sensitive data - never commit to git
- Server uses SSH key authentication
- SSL certificates managed automatically
- Database and Redis are not exposed publicly (only via Docker network)

## Production Environment

Despite using `RAILS_ENV: development` in the configuration, this is running on production infrastructure with:
- Production SSL certificates
- Production domain (api.goodsongs.app)
- Production database with proper backups
- Production-grade container orchestration

The development Rails environment setting simply avoids Rails 8 credentials complexity while maintaining production deployment benefits.
