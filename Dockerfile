FROM php:8.0-fpm

# Install dependencies
RUN apt-get update && apt-get install -y \
 nginx \
 libfreetype6-dev \
 libjpeg62-turbo-dev \
 libpng-dev \
 libxml2-dev \
 libzip-dev \
 default-mysql-client \
 libpq-dev \
 git \
 curl \
 zip \
 unzip \
 libicu-dev \
 gettext \
 && docker-php-ext-install -j$(nproc) mysqli pdo_mysql pdo_pgsql pgsql \
 zip exif pcntl bcmath opcache intl gettext \
 && docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j$(nproc) gd

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_16.x | bash - \
 && apt-get install -y nodejs

# Set working directory
WORKDIR /var/www/html

# Copy OJS files first
COPY . /var/www/html
RUN chown -R www-data:www-data /var/www/html

# Install or update dependencies via Composer
WORKDIR /var/www/html/lib/pkp
RUN composer install

WORKDIR /var/www/html/plugins/paymethod/paypal
RUN composer install

WORKDIR /var/www/html/plugins/generic/citationStyleLanguage
RUN composer install

# Install or update dependencies via NPM
WORKDIR /var/www/html
RUN mkdir -p /var/www/.npm /var/www/.cache && chown -R www-data:www-data /var/www/.npm /var/www/.cache
USER www-data
RUN npm install && npm run build
USER root

# Configure PHP
RUN { \
 echo 'upload_max_filesize = 50M'; \
 echo 'post_max_size = 50M'; \
 echo 'memory_limit = 256M'; \
 echo 'max_execution_time = 300'; \
 echo 'max_input_time = 300'; \
 echo 'opcache.memory_consumption = 128'; \
 echo 'opcache.interned_strings_buffer = 8'; \
 echo 'opcache.max_accelerated_files = 4000'; \
 echo 'opcache.revalidate_freq = 2'; \
 echo 'opcache.fast_shutdown = 1'; \
 } > /usr/local/etc/php/conf.d/ojs-recommended.ini

# Configure Nginx
COPY ./docker/nginx.conf /etc/nginx/sites-available/default
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
 && ln -sf /dev/stderr /var/log/nginx/error.log

# Expose port
EXPOSE 80

# Start Nginx and PHP-FPM
COPY ./docker/start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

CMD ["/usr/local/bin/start.sh"]