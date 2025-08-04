# GoodSongs API - DigitalOcean Deployment Guide

This comprehensive guide will walk you through deploying the GoodSongs API using Kamal on DigitalOcean, step by step.

## What You'll Need

- **DigitalOcean Account** (sign up at digitalocean.com)
- **Domain Name** (from Namecheap, GoDaddy, etc.)
- **Docker Hub Account** (free at hub.docker.com)
- **About 30-60 minutes** of your time

## Step-by-Step Deployment

### Step 1: Create DigitalOcean Droplet

1. **Log into DigitalOcean**

   - Go to https://digitalocean.com and sign in
   - Click the green "Create" button → "Droplets"

2. **Choose Configuration**

   - **Image**: Ubuntu 22.04 (LTS) x64
   - **Plan**: Basic plan, Regular Intel/AMD CPU
   - **CPU Options**: $12/month (2 GB RAM, 1 vCPU, 50 GB SSD) - good for small apps
   - **Region**: Choose closest to your users (e.g., New York, San Francisco)
   - **VPC Network**: Leave default
   - **Additional Options**: None needed

3. **Authentication**

   - **IMPORTANT**: Choose "SSH Keys" (more secure than password)
   - Click "New SSH Key"
   - Follow these steps to create an SSH key:

   **On Mac/Linux:**

   ```bash
   # Generate SSH key (press Enter for all prompts)
   ssh-keygen -t ed25519 -C "your-email@example.com"

   # Copy public key to clipboard
   cat ~/.ssh/id_ed25519.pub | pbcopy
   ```

   **On Windows (PowerShell):**

   ```powershell
   # Generate SSH key
   ssh-keygen -t ed25519 -C "your-email@example.com"

   # Copy public key to clipboard
   Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub | Set-Clipboard
   ```

   - Paste the key into DigitalOcean and give it a name like "My Laptop"

4. **Finalize and Create**

   - **Hostname**: Give it a name like "goodsongs-api-prod"
   - **Tags**: Optional (e.g., "production", "api")
   - Click "Create Droplet"
   - **Wait 1-2 minutes** for the droplet to be created

5. **Note Your Server IP**
   - Copy the IP address (e.g., 142.93.167.123)
   - You'll need this multiple times

### Step 2: Set Up Your Domain

1. **Point Domain to Server**

   **For Namecheap DNS Configuration:**

   - Go to Namecheap.com and log into your account
   - Go to "Domain List" and click "Manage" next to your domain
   - Click on "Advanced DNS" tab
   - Create/edit these DNS records:

   **For Frontend (Vercel hosting):**
   ```
   Type: A
   Host: @ 
   Value: 76.76.19.19 (Vercel's IP - check Vercel docs for current IP)
   TTL: Automatic

   Type: CNAME
   Host: www
   Value: cname.vercel-dns.com
   TTL: Automatic
   ```

   **For API (DigitalOcean hosting):**
   ```
   Type: A
   Host: api
   Value: 138.68.0.58 (your DigitalOcean droplet IP)
   TTL: Automatic
   ```

   **Note:** Replace `138.68.0.58` with your actual DigitalOcean droplet IP address.

   **Alternative Vercel Setup (Recommended):**
   Instead of using Vercel's IP, you can use their CNAME:
   ```
   Type: CNAME
   Host: @
   Value: cname.vercel-dns.com
   TTL: Automatic

   Type: CNAME
   Host: www
   Value: cname.vercel-dns.com
   TTL: Automatic
   ```

2. **Wait for DNS Propagation**
   - This can take 5 minutes to 48 hours
   - Test with: `nslookup your-domain.com`
   - Should return your server IP

### Step 3: Prepare Your Server

1. **Connect to Your Server**

   ```bash
   # Replace YOUR_SERVER_IP with your actual IP
   ssh root@YOUR_SERVER_IP

   # You should see something like: root@goodsongs-api-prod:~#
   ```

2. **Update System**

   ```bash
   # Update package list
   apt update

   # Upgrade all packages (this may take 5-10 minutes)
   apt upgrade -y

   # Install essential tools
   apt install -y curl wget git unzip
   ```

3. **Install Docker**

   ```bash
   # Download Docker installation script
   curl -fsSL https://get.docker.com -o get-docker.sh

   # Run the installation (takes 2-3 minutes)
   sh get-docker.sh

   # Add current user to docker group
   usermod -aG docker $USER

   # Test Docker installation
   docker --version
   # Should show: Docker version 24.x.x
   ```

4. **Configure Firewall**

   ```bash
   # Install UFW firewall
   apt install -y ufw

   # Allow SSH (IMPORTANT: don't lock yourself out!)
   ufw allow ssh

   # Allow HTTP and HTTPS
   ufw allow 80
   ufw allow 443

   # Enable firewall
   ufw --force enable

   # Check status
   ufw status
   ```

5. **Reboot Server**

   ```bash
   # Reboot to apply all changes
   reboot

   # Wait 1-2 minutes, then reconnect
   ssh root@YOUR_SERVER_IP
   ```

### Step 4: Set Up Docker Hub

1. **Create Docker Hub Account**

   - Go to https://hub.docker.com
   - Sign up for free account
   - Verify your email

2. **Create Access Token**

   - Click your username → "Account Settings"
   - Click "Security" tab
   - Click "New Access Token"
   - Description: "GoodSongs API Deployment"
   - Permissions: "Read, Write, Delete"
   - Click "Generate"
   - **IMPORTANT**: Copy and save this token - you can't see it again!

3. **Test Docker Hub Login**
   ```bash
   # On your local machine (not the server)
   docker login
   # Username: your-docker-hub-username
   # Password: paste-your-access-token
   ```

### Step 5: Configure Kamal on Your Local Machine

1. **Install Kamal Gem**

   ```bash
   # On your local machine (in your project directory)
   gem install kamal

   # Verify installation
   kamal version
   # Should show: Kamal version 1.x.x
   ```

2. **Update Deploy Configuration**

   Open `config/deploy.yml` and update these values:

   ```yaml
   # Replace these placeholders with YOUR actual values:

   # Line 5: Replace "your-username" with your Docker Hub username
   image: YOUR_DOCKERHUB_USERNAME/goodsongs-api

   # Line 10: Replace with your DigitalOcean droplet IP
   servers:
     web:
       - YOUR_DROPLET_IP_HERE

   # Line 22: Replace with your actual domain
   proxy:
     ssl: true
     host: your-actual-domain.com

   # Line 28: Replace with your Docker Hub username
   registry:
     username: YOUR_DOCKERHUB_USERNAME

   # Line 107: Replace with your droplet IP (same as line 10)
   accessories:
     db:
       host: YOUR_DROPLET_IP_HERE
   ```

   **Example with real values:**

   ```yaml
   image: johnsmith/goodsongs-api
   servers:
     web:
       - 142.93.167.123
   proxy:
     ssl: true
     host: myawesomemusic.com
   registry:
     username: johnsmith
   accessories:
     db:
       host: 142.93.167.123
   ```

3. **Set up Secrets File**

   ```bash
   # Copy the template
   cp .kamal/secrets.example .kamal/secrets

   # Open the secrets file for editing
   nano .kamal/secrets
   # (or use your preferred editor like VS Code: code .kamal/secrets)
   ```

4. **Fill in Secrets File**

   Replace ALL the placeholder values in `.kamal/secrets`:

   ```bash
   # Generate a Rails master key if you don't have one
   rails secret
   # Copy the output (long string) to RAILS_MASTER_KEY

   # Your secrets file should look like this (with YOUR actual values):
   RAILS_MASTER_KEY=your_generated_key_from_rails_secret_command
   DATABASE_URL=postgresql://postgres:your_strong_password@goodsongs-db:5432/goodsongs_api_production
   JWT_SECRET_KEY=fdba597bbd4223b62673cb13777d550d1d3f1341761c9caede41c6e3833ebb4354ddfa138e93034fb05e61e269553a52fc82033657672c2b0cb43291ffbb70c3
   SPOTIFY_CLIENT_ID=cce32bf752aa4646abe4043482d44034
   SPOTIFY_CLIENT_SECRET=91cd832e01f64c75959269412c5a8926
   POSTGRES_PASSWORD=your_strong_password_here_make_it_complex
   KAMAL_REGISTRY_PASSWORD=your_docker_hub_access_token_from_step_4
   ```

   **Important Notes:**

   - Use the SAME password for `DATABASE_URL` and `POSTGRES_PASSWORD`
   - Make the PostgreSQL password strong (mix of letters, numbers, symbols)
   - Use your Docker Hub ACCESS TOKEN (not your password) for `KAMAL_REGISTRY_PASSWORD`

### Step 6: Update Spotify OAuth Settings

1. **Go to Spotify Developer Dashboard**

   - Visit https://developer.spotify.com/dashboard/applications
   - Log in with your Spotify account
   - Click on your existing GoodSongs app

2. **Update Redirect URIs**
   - Click "Edit Settings"
   - In "Redirect URIs" section, add:
     ```
     https://your-actual-domain.com/auth/spotify/callback
     ```
   - Click "Add"
   - Click "Save" at the bottom

### Step 7: Deploy Your Application

**IMPORTANT**: Make sure you're in your project directory on your local machine.

1. **Test Connection to Server**

   ```bash
   # Test SSH connection
   ssh root@YOUR_DROPLET_IP
   # If this works, type 'exit' to return to your local machine
   ```

2. **Initial Server Setup** (First time only)

   ```bash
   # This sets up Docker containers on your server
   kamal setup

   # This will take 5-10 minutes and you'll see output like:
   # "Acquiring the deploy lock..."
   # "Logging into image registry..."
   # "Building goodsongs-api:xxx..."
   # "Deploying goodsongs-api:xxx..."
   ```

   **What happens during setup:**

   - Builds your Docker image locally
   - Pushes image to Docker Hub
   - Sets up PostgreSQL database container
   - Sets up Redis container
   - Gets SSL certificate from Let's Encrypt
   - Starts your application

3. **Deploy Your Application**

   ```bash
   # Deploy the app (after setup is complete)
   kamal deploy

   # This is faster than setup (2-3 minutes)
   ```

4. **Verify Deployment**

   ```bash
   # Check if everything is running
   kamal app details

   # Should show something like:
   # goodsongs-api-web-xxx running
   ```

### Step 8: Test Your Deployment

1. **Check Your Website**

   - Open browser and go to: `https://your-domain.com/health`
   - Should see: "OK"

2. **Test API Endpoints**

   ```bash
   # Test health endpoint
   curl https://your-domain.com/health
   # Should return: OK

   # Test signup endpoint
   curl -X POST https://your-domain.com/signup \
     -H "Content-Type: application/json" \
     -d '{"username":"testuser","email":"test@example.com","password":"password123","password_confirmation":"password123"}'
   # Should return JSON with auth_token
   ```

3. **Check Application Logs**

   ```bash
   # View recent logs
   kamal app logs

   # Follow logs in real-time (Ctrl+C to stop)
   kamal app logs -f
   ```

## Regular Deployment Commands

After initial setup, use these commands for updates:

### Deploy Updates

```bash
# Deploy latest code changes
kamal deploy

# Deploy with specific version
kamal deploy --version=v1.2.3
```

### Database Management

```bash
# Run database migrations (if you added new ones)
kamal app exec "bin/rails db:migrate"

# Access database console (to run SQL queries)
kamal app exec "bin/rails dbconsole"

# Check database container status
kamal accessory details db

# View database logs
kamal accessory logs db
```

### Monitoring & Debugging

```bash
# View application logs (recent)
kamal app logs

# Follow logs in real-time
kamal app logs -f

# Check all running containers
kamal app details

# Check database and Redis status
kamal accessory details all

# SSH directly into your server
ssh root@YOUR_DROPLET_IP

# Check server resource usage
ssh root@YOUR_DROPLET_IP "top"
```

### Rollback (if something goes wrong)

```bash
# See deployment history
kamal app versions

# Rollback to previous version
kamal app rollback [VERSION_NUMBER]
```

## Troubleshooting Common Issues

### 1. "kamal setup" Fails

**Error: "Could not connect to server"**

```bash
# Test SSH connection
ssh root@YOUR_DROPLET_IP

# If SSH fails, check:
# - Is your droplet IP correct?
# - Is your SSH key added to DigitalOcean?
# - Is the droplet running?
```

**Error: "Docker not found"**

```bash
# SSH into server and check Docker
ssh root@YOUR_DROPLET_IP
docker --version

# If Docker not installed, run:
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
```

### 2. SSL Certificate Issues

**Error: "Let's Encrypt certificate failed"**

- Make sure your domain DNS is pointing to your server
- Wait for DNS propagation (can take up to 48 hours)
- Test DNS: `nslookup your-domain.com`

### 3. Database Connection Issues

**Error: "Could not connect to database"**

```bash
# Check if PostgreSQL container is running
kamal accessory details db

# Restart database container
kamal accessory restart db

# Check database logs
kamal accessory logs db
```

### 4. Application Won't Start

**Check logs first:**

```bash
kamal app logs

# Common issues:
# - Missing environment variables
# - Database migration needed
# - Port conflicts
```

**Restart the application:**

```bash
kamal app restart
```

### 5. "Out of Memory" Errors

**Upgrade your DigitalOcean droplet:**

1. Go to DigitalOcean dashboard
2. Click your droplet
3. Click "Resize" tab
4. Choose larger size (e.g., $24/month for 4GB RAM)
5. Click "Resize Droplet"

### 6. Domain Not Working

**Check DNS:**

```bash
nslookup your-domain.com
# Should return your server IP
```

**Check if site loads on IP:**

- Try: `http://YOUR_DROPLET_IP` (note: http, not https)
- If this works, it's a DNS issue

## Backup Strategy

### Database Backups

```bash
# Create backup
kamal accessory exec db "pg_dump -U postgres goodsongs_api_production" > backup_$(date +%Y%m%d).sql

# Restore backup (CAREFUL: this overwrites data)
kamal accessory exec db "psql -U postgres goodsongs_api_production" < backup_20240101.sql
```

### File Storage Backups

```bash
# The uploaded files are in a Docker volume
# Check volume location
ssh root@YOUR_DROPLET_IP "docker volume ls"

# Create volume backup
ssh root@YOUR_DROPLET_IP "docker run --rm -v goodsongs_api_storage:/data -v $(pwd):/backup ubuntu tar czf /backup/storage_backup.tar.gz /data"
```

## Updating Your App

### When You Make Code Changes

1. **Commit your changes**

   ```bash
   git add .
   git commit -m "Add new feature"
   git push origin main
   ```

2. **Deploy the update**

   ```bash
   kamal deploy
   ```

3. **That's it!** Your production app is updated

### When You Add New Gems

1. **Update locally**

   ```bash
   bundle install
   git add Gemfile Gemfile.lock
   git commit -m "Add new gems"
   ```

2. **Deploy**
   ```bash
   kamal deploy
   ```

### When You Add Database Migrations

1. **Create migration locally**

   ```bash
   rails generate migration AddNewField
   ```

2. **Deploy (migrations run automatically)**
   ```bash
   kamal deploy
   ```

## Production Environment Variables

Your production app will have these environment variables automatically set:

- `RAILS_ENV=production`
- `DATABASE_URL` - PostgreSQL connection string
- `JWT_SECRET_KEY` - JWT signing key
- `SPOTIFY_CLIENT_ID` - Spotify OAuth client ID
- `SPOTIFY_CLIENT_SECRET` - Spotify OAuth client secret
- `FRONTEND_URL` - Your frontend domain for OAuth redirects

## Backup Strategy

### Database Backups

```bash
# Create backup
kamal accessory exec db "pg_dump -U postgres goodsongs_api_production" > backup.sql

# Restore backup
kamal accessory exec db "psql -U postgres goodsongs_api_production" < backup.sql
```

### File Storage Backups

- The `goodsongs_api_storage` volume contains uploaded files
- Set up regular backups of this volume

## Troubleshooting

### Common Issues

1. **Build fails**: Check Dockerfile and ensure gems install correctly
2. **Database connection fails**: Verify DATABASE_URL and PostgreSQL container
3. **SSL issues**: Ensure domain points to server IP
4. **Permission errors**: Check file permissions and user setup

### Debug Commands

```bash
# Check app status
kamal app details

# Check container logs
kamal app logs -f

# Execute commands in app container
kamal app exec "bash"

# Check PostgreSQL container
kamal accessory details db

# Restart services
kamal app restart
```

## File Structure

```
.kamal/
├── secrets           # Your production secrets (DON'T COMMIT)
└── secrets.example   # Template for secrets

config/
├── deploy.yml        # Main Kamal configuration
├── database.yml      # Database configuration
└── init.sql         # PostgreSQL initialization

Dockerfile           # Production container setup
```

## Security Notes

- Never commit `.kamal/secrets` to version control
- Use strong passwords for PostgreSQL
- Keep your Docker registry credentials secure
- Regularly update your dependencies
- Monitor your server for security updates

## Automated Deployment with GitHub Actions

For automated deployments when you merge to main branch, see:

- `GITHUB_ACTIONS_SETUP.md` - Complete GitHub Actions setup guide

The automated workflow will:

- ✅ Run tests on every push/PR
- ✅ Deploy automatically when merging to main
- ✅ Run security checks and code style validation
- ✅ Provide deployment status notifications

## Support

For issues specific to Kamal deployment, check:

- [Kamal Documentation](https://kamal-deploy.org/)
- [Rails Docker Guide](https://guides.rubyonrails.org/getting_started_with_devcontainer.html)
- `GITHUB_ACTIONS_SETUP.md` - Automated deployment troubleshooting
