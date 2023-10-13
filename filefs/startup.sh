#!/bin/sh

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
/usr/local/bin/cloudflared tunnel run guacamole

# Start the cloudflare tunnel but after you check if cloudflared is already running
if ! pgrep -x "cloudflared" > /dev/null; then
  echo "Starting cloudflared..."
  
  # initiate Cloudflare login and authorize
  /usr/local/bin/cloudflared tunnel login

  # Create the tunnel and add the DNS
  /usr/local/bin/cloudflared tunnel create guacamole

  # Add the DNS route
  /usr/local/bin/cloudflared tunnel route dns guacamole guacamole

  # start tunnel
  /usr/local/bin/cloudflared tunnel run guacamole
else
  echo "cloudflared is already running."
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
