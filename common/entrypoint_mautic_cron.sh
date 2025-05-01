#!/bin/bash

mkdir -p /opt/mautic/cron

if [ ! -f /opt/mautic/cron/mautic ]; then

	cat <<EOF > /opt/mautic/cron/mautic
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
BASH_ENV=/tmp/cron.env

# Segments Update - every 15 min
0,15,30,45 * * * * php /var/www/html/bin/console mautic:segments:update 2>&1 | tee /tmp/stdout

# Campaigns Update - every 15 min starting at 5 past the hour
5,20,35,50 * * * * php /var/www/html/bin/console mautic:campaigns:update 2>&1 | tee /tmp/stdout

# Trigger Update - every 15 min starting at 10 past the hour
10,25,40,55 * * * * php /var/www/html/bin/console mautic:campaigns:trigger 2>&1 | tee /tmp/stdout

# Monitored E-mail - every 1 min
#* * * * * php /var/www/html/bin/console mautic:email:fetch 2>&1 | tee /tmp/stdout

# Social Monitoring - every 6 min
#*/6 * * * * php /var/www/html/bin/console mautic:social:monitoring 2>&1 | tee /tmp/stdout

# Import Contacts - every 3 min - fix 269
#*/3 * * * * php /var/www/html/bin/console mautic:import 2>&1 | tee /tmp/stdout

# Export Contacts - every 3 min
#*/3 * * * * php /var/www/html/bin/console mautic:contacts:scheduled_export 2>&1 | tee /tmp/stdout

# Webhooks - every 1 min
#* * * * * php /var/www/html/bin/console mautic:webhooks:process 2>&1 | tee /tmp/stdout

# Update MaxMind GeoLite2 IP database - every hour - fix 171
#0 * * * * php /var/www/html/bin/console mautic:iplookup:download 2>&1 | tee /tmp/stdout

# Clean up old data - at 02:01 - fix 207
#1 2 * * * php /var/www/html/bin/console mautic:maintenance:cleanup --days-old=365 2>&1 | tee /tmp/stdout - DISABLED, MAY CAUSE DATALOSS - TBD

# MaxMind CCPA compliance - at 03:02 on sunday, at 03:12 on sunday
#2 3 * * 0 php /var/www/html/bin/console mautic:donotsell:download 2>&1 | tee /tmp/stdout
#12 3 * * 0 php /var/www/html/bin/console mautic:max-mind:purge 2>&1 | tee /tmp/stdout

# Mautic Integrations - every 13 min - READ DOCUMENTATION BEFORE ENABLING
#*/13 * * * 0 php /var/www/html/bin/console mautic:integration:fetchleads 2>&1 | tee /tmp/stdout
#*/13 * * * 0 php /var/www/html/bin/console mautic:integration:pushactivity 2>&1 | tee /tmp/stdout


EOF
fi

# register the crontab file for the www-data user
crontab -u www-data /opt/mautic/cron/mautic

# create the fifo file to be able to redirect cron output for non-root users
mkfifo /tmp/stdout
chmod 777 /tmp/stdout

# ensure the PHP env vars are present during cronjobs
declare -p | grep 'PHP_INI_VALUE_' > /tmp/cron.env

# wait until Mautic is installed
until php -r 'file_exists("/var/www/html/config/local.php") ? include("/var/www/html/config/local.php") : exit(1); exit(isset($parameters["site_url"]) ? 0 : 1);'; do
	echo "Mautic not installed, waiting to start cron"
	sleep 5
done

# run cron and print the output
cron -f | tail -f /tmp/stdout
