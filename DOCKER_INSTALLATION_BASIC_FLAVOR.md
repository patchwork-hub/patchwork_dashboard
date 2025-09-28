# Patchwork Dashboard (Basic) - Docker Installation Guide

This guide provides step-by-step instructions for installing Patchwork Dashboard (Basic) using Docker containers.

## Prerequisites

Before starting, ensure you have:

- **Docker Engine** installed (version 20.10+ recommended)
- **Docker Compose** installed (version 2.0+ recommended)
- **A running Mastodon server** with database access
- **Basic knowledge** of Docker and environment variables

### Verify Docker Installation

```bash
docker --version
docker-compose --version
```

## Step 1: Clone the Repository

Clone the Patchwork Dashboard repository to your server:

```bash
git clone https://github.com/patchwork-hub/patchwork_dashboard.git
cd patchwork_dashboard
```

## Step 2: Configure Environment Variables

### Create Environment File

Copy the sample environment file and configure it:

```bash
cp .env.sample .env
```

### Edit Environment Configuration

Open the `.env` file and configure it accordingly:

```bash
nano .env
```

## Step 3: Start the Application

### Pull and Start Services

```bash
# Pull the latest image
docker-compose -f docker-compose.basic.yml pull

# Start the services in detached mode
docker-compose -f docker-compose.basic.yml up -d --build
```

### Verify Container Status

```bash
# Check if container is running
docker-compose -f docker-compose.basic.yml ps

# Check container logs
docker-compose -f docker-compose.basic.yml logs -f app
```

## Step 4: Initialize the Database

### Run Database Migrations

```bash
# Run migrations
docker-compose -f docker-compose.basic.yml exec app bundle exec rails db:migrate

# Seed the database (creates initial data and master admin)
docker-compose -f docker-compose.basic.yml exec app bundle exec rails db:seed
```

## Step 5: Access the Dashboard

1. Open your browser and go to: `http://your-server-ip:3001` (or your configured domain)
2. You should see the Patchwork Dashboard login page
3. Login with the master admin credentials you created

## Step 6: Activate Patchwork Dashboard

### Get API Key from Patchwork Hub

1. Go to [Patchwork Hub](https://hub.patchwork.online/)
2. Register a new account and verify it
3. Generate an API key on the landing page

### Add API Key to Dashboard

1. Login to your Patchwork Dashboard
2. Click **"API key"** in the left sidebar
3. Enter the **Key** and **Secret** from Patchwork Hub
4. Save the configuration

## Step 7: Health Check and Monitoring

### Check Application Health

```bash
# Check health endpoint
curl http://localhost:3001/health_check

# Monitor container health
docker-compose -f docker-compose.basic.yml ps
```

### View Logs

```bash
# View application logs
docker-compose -f docker-compose.basic.yml logs -f app

# View logs with timestamps
docker-compose -f docker-compose.basic.yml logs -f -t app
```

## Step 8: Maintenance Commands

### Update the Application

```bash
# Pull latest image
docker-compose -f docker-compose.basic.yml pull

# Restart with new image
docker-compose -f docker-compose.basic.yml up -d
```

### Backup Data

```bash
# Backup volumes
docker run --rm -v patchwork_basic_storage:/data -v $(pwd):/backup alpine tar czf /backup/patchwork_storage_backup.tar.gz -C /data .
docker run --rm -v patchwork_basic_public:/data -v $(pwd):/backup alpine tar czf /backup/patchwork_public_backup.tar.gz -C /data .
docker run --rm -v patchwork_basic_logs:/data -v $(pwd):/backup alpine tar czf /backup/patchwork_logs_backup.tar.gz -C /data .
```

### Restore Data

```bash
# Restore volumes (stop container first)
docker-compose -f docker-compose.basic.yml down
docker run --rm -v patchwork_basic_storage:/data -v $(pwd):/backup alpine tar xzf /backup/patchwork_storage_backup.tar.gz -C /data
docker-compose -f docker-compose.basic.yml up -d
```

## Troubleshooting

### Common Issues

1. **Container won't start**: Check logs with `docker-compose logs app`
2. **Database connection errors**: Verify database credentials in `.env`
3. **Permission issues**: Ensure Docker has proper permissions
4. **Port conflicts**: Make sure `EXTERNAL_PORT` is not in use

### Debug Commands

```bash
# Access container shell
docker-compose -f docker-compose.basic.yml exec app bash

# Check environment variables
docker-compose -f docker-compose.basic.yml exec app env

# Test database connection
docker-compose -f docker-compose.basic.yml exec app bundle exec rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1').first"
```

## Security Considerations

1. **Use HTTPS** in production with proper SSL certificates
2. **Secure your environment file** with appropriate permissions:
   ```bash
   chmod 600 .env
   ```
3. **Regular updates**: Keep Docker images updated
4. **Firewall**: Restrict access to necessary ports only
5. **Backup strategy**: Implement regular automated backups

## Support

For additional help:
- Review container logs for specific error messages
- Contact support at support@newsmastfoundation.org

---

**Congratulations!** Your Patchwork Dashboard should now be running successfully with Docker. You can now install additional plug-ins and customize your server through the dashboard interface.