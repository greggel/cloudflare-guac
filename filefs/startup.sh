#!/bin/sh

if [ -f .env ]; then
  source .env
fi

echo "Running startup scripts"
/usr/local/bin/_startup.sh

echo "Running Postgres"
/etc/init.d/postgres start

echo "Running Guacamole server"
bash -c '/opt/guacamole/sbin/guacd -b 0.0.0.0 -L $GUACD_LOG_LEVEL -f' &

echo "Post startup DB scripts"
gosu postgres bash -c '/usr/local/bin/_post_startup.sh'

echo "Running Tomcat"
# Wait for postgres to be ready
while ! nc -z localhost 5432; do   
  sleep 5
done
/etc/init.d/tomcat start

# Check if cloudflared is running
if pgrep -x "cloudflared" > /dev/null; then
  echo "cloudflared is already running."
  exit 0
fi

# Check if cert.pem exists in /root/.cloudflared
if [ -f "/root/.cloudflared/cert.pem" ]; then
  echo "cert.pem found. Starting cloudflared..."
  echo "Using $hostname as Cloudflare team name"

  # Start the tunnel
  /usr/local/bin/cloudflared tunnel run $hostname
else
  echo "Starting cloudflared..."
  echo "Using $hostname as Cloudflare team name"

  # Initiate Cloudflare login and authorize
  /usr/local/bin/cloudflared tunnel login

  # Create the tunnel and add the DNS
  /usr/local/bin/cloudflared tunnel create $hostname

  # Add the DNS route
  /usr/local/bin/cloudflared tunnel route dns $hostname $hostname

  # Start the tunnel
  /usr/local/bin/cloudflared tunnel run $hostname
fi

# Add any other startup commands or services you might need

# Run your main application process
# For example, if your main application is guacamole:
# /path/to/guacamole/startup/script.sh

# Keep the container running
tail -f /dev/null

echo "container started"
#tail -f /dev/null
# Wait for any process to exit
wait -n
  
# Exit with status of process that exited first
exit $?
