FROM phusion/baseimage:0.9.15

MAINTAINER Nikita Makarov <mesaverde228@gmail.com>

# Ensure UTF-8
RUN locale-gen en_US.UTF-8
ENV LANG       en_US.UTF-8
ENV LC_ALL     en_US.UTF-8

ENV HOME /root

# INITIAL
RUN /etc/my_init.d/00_regen_ssh_host_keys.sh
CMD ["/sbin/my_init"]

# Add Additional pakage repositories
RUN add-apt-repository -y ppa:ondrej/php
RUN add-apt-repository -y ppa:nginx/stable

# Update the list of packages
RUN apt-get update

# Install all required packages
RUN DEBIAN_FRONTEND="noninteractive" apt-get install -y --force-yes \
    supervisor \
    curl \
    wget \
    build-essential \
    python-software-properties \
    git \
    subversion \
    openssh-server \
    php7.1-cli php7.1-fpm \
    php7.1-mysql \
    php7.1-pgsql \
    php7.1-curl \
    php7.1-gd \
    php7.1-mcrypt \
    php7.1-intl \
    php7.1-mbstring \
    php7.1-xml \
    php7.1-soap \
    php7.1-zip zip unzip \
    nginx \
    mc \
    cron

# Clean UP
RUN set -ex && apt-get autoremove -y
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Configue SSH
COPY .build/sshd_config /etc/ssh/
ENV SSH_PASSWD "root:Docker!"
RUN echo "$SSH_PASSWD" | chpasswd

# Composer
RUN curl -sS https://getcomposer.org/installer | php -- \
    --install-dir=/usr/bin \
    --filename=composer

# Setup required folders tree & copy initial start pages
ENV HOME_SITE "/home/site/wwwroot"

RUN set -ex && mkdir -p \
    /var/run/sshd \
    /run/php

RUN set -ex\
    && rm -rf /var/www \
    && test ! -d /var/www && mkdir -p /var/www/ \
	&& chown -R www-data:www-data /var/www

COPY .build/hostingstart.html /var/www

# Configure PHP CLI
RUN sed -i "s/;date.timezone =.*/date.timezone = UTC/" /etc/php/7.1/cli/php.ini

# Configure PHP FPM
COPY .build/www.conf /etc/php/7.1/fpm/pool.d/www.conf
RUN sed -i "s/;date.timezone =.*/date.timezone = UTC/" /etc/php/7.1/fpm/php.ini
RUN sed -i "s/short_open_tag =.*/short_open_tag = Off/" /etc/php/7.1/fpm/php.ini
RUN sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/7.1/fpm/php-fpm.conf
RUN sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.1/fpm/php.ini
RUN sed -i "s/session.auto_start\s*=.*/session.auto_start = 0/" /etc/php/7.1/fpm/php.ini

#NGinx
COPY .build/nginx.conf /etc/nginx/nginx.conf
ADD .build/default.conf /etc/nginx/sites-available/default

#Supervisor configs
RUN rm -rf /etc/supervisor/conf.d/*.conf
COPY .build/supervisord/*.conf /etc/supervisor/conf.d/


# Copy initialize script
COPY .build/init_container.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init_container.sh

# Define ports
EXPOSE 8000 2222

# Define entrypoint
ENTRYPOINT ["init_container.sh"]
