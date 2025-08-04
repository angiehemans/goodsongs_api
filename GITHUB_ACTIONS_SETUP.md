# GitHub Actions Automated Deployment Setup

This guide will help you set up automated deployments that trigger when you merge code into your main branch.

## Overview

The setup includes:
- **Automated testing** on every push/PR
- **Automated deployment** when code is merged to main
- **Security checks** with Brakeman and bundle audit
- **Code style checks** with RuboCop

## Setup Steps

### 1. GitHub Repository Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add these **Repository Secrets**:

```
RAILS_MASTER_KEY
└── Your Rails master key (from config/master.key or rails secret)

DATABASE_URL
└── postgresql://postgres:YOUR_PASSWORD@goodsongs-db:5432/goodsongs_api_production

JWT_SECRET_KEY
└── fdba597bbd4223b62673cb13777d550d1d3f1341761c9caede41c6e3833ebb4354ddfa138e93034fb05e61e269553a52fc82033657672c2b0cb43291ffbb70c3

SPOTIFY_CLIENT_ID
└── cce32bf752aa4646abe4043482d44034

SPOTIFY_CLIENT_SECRET
└── 91cd832e01f64c75959269412c5a8926

POSTGRES_PASSWORD
└── Your secure PostgreSQL password for production

KAMAL_REGISTRY_PASSWORD
└── Your Docker Hub access token

SSH_PRIVATE_KEY
└── Your SSH private key for server access (see below)
```

### 2. SSH Key Setup

Generate an SSH key pair for GitHub Actions:

```bash
# Generate a new SSH key pair
ssh-keygen -t ed25519 -C "github-actions@yourdomain.com" -f ./github_actions_key

# Copy public key to your server
ssh-copy-id -i ./github_actions_key.pub root@YOUR_SERVER_IP

# Test the connection
ssh -i ./github_actions_key root@YOUR_SERVER_IP "echo 'Connection successful'"
```

Add the **private key** content to GitHub secrets as `SSH_PRIVATE_KEY`:
```bash
cat ./github_actions_key
# Copy the entire output (including -----BEGIN and -----END lines)
```

### 3. Server SSH Configuration (Optional - Enhanced Security)

For better security, create a dedicated deployment user:

```bash
# On your server
sudo useradd -m -s /bin/bash deploy
sudo usermod -aG docker deploy

# Add the public key to deploy user
sudo mkdir -p /home/deploy/.ssh
sudo cp /root/.ssh/authorized_keys /home/deploy/.ssh/authorized_keys
sudo chown -R deploy:deploy /home/deploy/.ssh
sudo chmod 700 /home/deploy/.ssh
sudo chmod 600 /home/deploy/.ssh/authorized_keys
```

Then update your `config/deploy.yml`:
```yaml
ssh:
  user: deploy
```

### 4. Workflow Files

The following workflow files are created in `.github/workflows/`:

#### `test.yml` - Automated Testing
- Runs on every push to main/develop and all PRs
- Sets up PostgreSQL for testing
- Runs RSpec tests
- Performs security checks with Brakeman
- Checks code style with RuboCop

#### `deploy.yml` - Automated Deployment
- Runs only on pushes to main branch
- Requires tests to pass first
- Deploys using Kamal
- Can be triggered manually via GitHub UI

### 5. Deployment Flow

```mermaid
graph LR
    A[Push to main] --> B[Run Tests]
    B --> C{Tests Pass?}
    C -->|Yes| D[Deploy with Kamal]
    C -->|No| E[Deployment Blocked]
    D --> F[Production Updated]
```

## Workflow Features

### 🧪 **Automated Testing**
- PostgreSQL service container
- Environment variables for testing
- RSpec test suite
- Security vulnerability scanning
- Code style checking

### 🚀 **Automated Deployment**
- Only deploys on main branch
- Requires tests to pass
- Uses Kamal for zero-downtime deployment
- Proper secret management
- Git history tracking

### 🔒 **Security**
- Secrets stored securely in GitHub
- SSH key authentication
- Temporary secrets file (cleaned up after deployment)
- Bundle audit for gem vulnerabilities

## Usage

### Normal Development Flow
1. Create feature branch: `git checkout -b feature/my-feature`
2. Make changes and commit
3. Push branch: `git push origin feature/my-feature`
4. Create Pull Request
5. Tests run automatically on PR
6. After review, merge to main
7. **Automatic deployment happens!** 🎉

### Manual Deployment
You can also trigger deployments manually:
1. Go to your GitHub repository
2. Click "Actions" tab
3. Select "Deploy to Production"
4. Click "Run workflow"
5. Choose the branch and click "Run workflow"

### Monitoring Deployments
- Check the "Actions" tab in your GitHub repository
- View real-time logs of the deployment process
- Get notified of deployment success/failure

## Troubleshooting

### Common Issues

**SSH Connection Failed**
```bash
# Test SSH connection locally
ssh -i ./github_actions_key root@YOUR_SERVER_IP

# Check server SSH logs
sudo tail -f /var/log/auth.log
```

**Docker Registry Authentication Failed**
- Verify your Docker Hub username in `config/deploy.yml`
- Ensure `KAMAL_REGISTRY_PASSWORD` is an access token, not password

**Database Connection Issues**
- Check `DATABASE_URL` format in GitHub secrets
- Verify PostgreSQL container is running: `kamal accessory details db`

**Tests Failing**
- Check test database configuration
- Ensure all required environment variables are set
- Run tests locally: `bundle exec rspec`

### Debug Commands

```bash
# View GitHub Actions logs in your repository Actions tab

# SSH into your server to debug
ssh root@YOUR_SERVER_IP

# Check Kamal status
kamal app details

# View application logs
kamal app logs -f

# Check accessories
kamal accessory details all
```

## Advanced Configuration

### Staging Environment
Create a staging branch for testing:

```yaml
# In deploy.yml, add staging deployment
on:
  push:
    branches: [main, staging]

jobs:
  deploy:
    strategy:
      matrix:
        environment: 
          - ${{ github.ref == 'refs/heads/main' && 'production' || 'staging' }}
```

### Slack/Discord Notifications
Add notification steps:

```yaml
- name: Notify Slack
  if: always()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

### Database Migrations
Migrations run automatically via the Docker entrypoint, but you can add explicit steps:

```yaml
- name: Run database migrations
  run: kamal app exec "bin/rails db:migrate"
```

## Security Best Practices

1. **Use access tokens** instead of passwords for Docker registry
2. **Rotate SSH keys** regularly
3. **Use dedicated deployment user** instead of root
4. **Monitor deployment logs** for suspicious activity
5. **Keep secrets up to date** in GitHub
6. **Use branch protection rules** to require PR reviews

## File Structure

```
.github/
└── workflows/
    ├── deploy.yml     # Production deployment
    └── test.yml       # Automated testing

config/
└── deploy.yml         # Kamal configuration

GITHUB_ACTIONS_SETUP.md  # This guide
DEPLOYMENT.md            # Manual deployment guide
```

## Next Steps

1. Set up all GitHub secrets
2. Generate and configure SSH keys
3. Push to main branch to test the workflow
4. Monitor the deployment in the Actions tab
5. Verify your app is deployed successfully

Your app will now automatically deploy every time you merge code to main! 🚀