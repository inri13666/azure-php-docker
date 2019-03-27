#!/bin/bash

sed -i "s|loglevel=.*|loglevel=${SUPERVISOR_LOG_LEVEL:-warn}|" /etc/supervisor/conf.d/00-supervisord.conf

if [ ! ${SYMFONY_ENV} ]; then
    export SYMFONY_ENV=prod
else
    export SYMFONY_ENV=${SYMFONY_ENV}
fi

# Get environment variables to show up in SSH session
eval $(printenv | awk -F= '{print "export " $1"="$2 }' >> /etc/profile)

# setup server root
test ! -d "$HOME_SITE" && echo "INFO: $HOME_SITE not found. creating..." && mkdir -p "$HOME_SITE"
if [ ! $WEBSITES_ENABLE_APP_SERVICE_STORAGE ]; then
    echo "INFO: NOT in Azure, chown for "$HOME_SITE
    chown -R nobody:nogroup $HOME_SITE
fi

echo "Starting Container ..."
test ! -d /home/LogFiles && mkdir /home/LogFiles
test ! -f /home/LogFiles/nginx-access.log && touch /home/LogFiles/nginx-access.log
test ! -f /home/LogFiles/nginx-error.log && touch /home/LogFiles/nginx-error.log
test ! -f /home/LogFiles/php7.1-fpm.log && touch /home/LogFiles/php7.1-fpm.log
test ! -d /home/LogFiles/supervisor && mkdir /home/LogFiles/supervisor
chown -R nobody:nogroup /home/LogFiles
chown -R nobody:nogroup /run/php

rm -rf /var/log/supervisor
ln -s /home/LogFiles/supervisor /var/log/supervisor

if [ -f "${HOME_SITE}/composer.json" ]
then
    echo "Performing composer operation ..."
    cd ${HOME_SITE} && composer install --no-interaction --prefer-dist
fi

if [ ${DEBUG} ]; then
    ln -sf /dev/stdout /var/log/nginx/access.log \
        && ln -sf /dev/stderr /var/log/nginx/error.log \
        && ln -sf /dev/stderr /var/log/php7.1-fpm.log
else
    ln -sf /home/LogFiles/nginx-access.log /var/log/nginx/access.log \
        && ln -sf /home/LogFiles/nginx-error.log /var/log/nginx/error.log \
        && ln -sf /home/LogFiles/php7.1-fpm.log /var/log/php7.1-fpm.log
fi

/usr/bin/supervisord
