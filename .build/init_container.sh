#!/bin/bash

# setup server root
test ! -d "$HOME_SITE" && echo "INFO: $HOME_SITE not found. creating..." && mkdir -p "$HOME_SITE"
if [ ! $WEBSITES_ENABLE_APP_SERVICE_STORAGE ]; then
    echo "INFO: NOT in Azure, chown for "$HOME_SITE
    chown -R nobody:nogroup $HOME_SITE
fi

if [ ! ${SYMFONY_ENV} ]; then
    export SYMFONY_ENV=${SYMFONY_ENV:-prod}
fi
if [ ! ${COMPOSER_HOME} ]; then
    export COMPOSER_HOME=${HOME_SITE}/.composer
fi

if [ ! -d ${COMPOSER_HOME} ]; then
    mkdir -p $COMPOSER_HOME && chown nobody:nogroup -R ${COMPOSER_HOME}
fi

if [ ${STARTUP_SCRIPT} ] && [ -f "${HOME_SITE}/${STARTUP_SCRIPT}" ]; then
    sed -i "s|command=.*|command=bash ${STARTUP_SCRIPT}|" /etc/supervisor/conf.d/06-startup.conf
    sed -i "s/autostart=.*/autostart=true/" /etc/supervisor/conf.d/06-startup.conf
fi

# Get environment variables to show up in SSH session
eval $(printenv | awk -F= '{print "export " $1"="$2 }' >> /etc/profile)

echo "Starting Container ..."
test ! -d /home/LogFiles && mkdir /home/LogFiles
test ! -f /home/LogFiles/nginx-access.log && touch /home/LogFiles/nginx-access.log
test ! -f /home/LogFiles/nginx-error.log && touch /home/LogFiles/nginx-error.log
test ! -f /home/LogFiles/php7.1-fpm.log && touch /home/LogFiles/php7.1-fpm.log
test ! -d /home/LogFiles/supervisor && mkdir /home/LogFiles/supervisor
chown -R nobody:nogroup /home/LogFiles
chown -R nobody:nogroup /run/php


sed -i "s|loglevel=.*|loglevel=${SUPERVISOR_LOG_LEVEL:-warn}|" /etc/supervisor/conf.d/00-supervisord.conf
rm -rf /var/log/supervisor
ln -s /home/LogFiles/supervisor /var/log/supervisor


phpenmod opcache

if [ -f "${HOME_SITE}/php.ini" ]; then
    cat "${HOME_SITE}/php.ini" >> /etc/php/7.1/fpm/php.ini
fi

if [ -f "${HOME_SITE}/php-cli.ini" ]; then
    cat "${HOME_SITE}/php-cli.ini" >> /etc/php/7.1/cli/php.ini
fi

if [ ${APPLICATION_INSTALLED:-0} == 1 ]; then
    if [ -f "${HOME_SITE}/composer.json" ]; then
        sed -i "s/autostart=.*/autostart=true/" /etc/supervisor/conf.d/05-composer.conf
    fi
fi

echo 'opcache.memory_consumption=128' >> /etc/php/7.1/fpm/php.ini
echo 'opcache.interned_strings_buffer=8' >> /etc/php/7.1/fpm/php.ini
echo 'opcache.max_accelerated_files=4000' >> /etc/php/7.1/fpm/php.ini
echo 'opcache.revalidate_freq=60' >> /etc/php/7.1/fpm/php.ini
echo 'opcache.fast_shutdown=1' >> /etc/php/7.1/fpm/php.ini
echo 'opcache.enable_cli=1' >> /etc/php/7.1/fpm/php.ini

echo 'opcache.memory_consumption=128' >> /etc/php/7.1/cli/php.ini
echo 'opcache.interned_strings_buffer=8' >> /etc/php/7.1/cli/php.ini
echo 'opcache.max_accelerated_files=4000' >> /etc/php/7.1/cli/php.ini
echo 'opcache.revalidate_freq=60' >> /etc/php/7.1/cli/php.ini
echo 'opcache.fast_shutdown=1' >> /etc/php/7.1/cli/php.ini
echo 'opcache.enable_cli=1' >> /etc/php/7.1/cli/php.ini

if [ ${DEBUG:-0} == 1 ]; then
    ln -sf /dev/stdout /var/log/nginx/access.log
    ln -sf /dev/stderr /var/log/nginx/error.log
    ln -sf /dev/stderr /var/log/php7.1-fpm.log
else
    ln -sf /home/LogFiles/nginx-access.log /var/log/nginx/access.log
    ln -sf /home/LogFiles/nginx-error.log /var/log/nginx/error.log
    ln -sf /home/LogFiles/php7.1-fpm.log /var/log/php7.1-fpm.log
fi

/usr/bin/supervisord
