FROM php:8.2-apache
RUN apt-get update && apt-get install -y libpq-dev \
    && docker-php-ext-install pdo pdo_pgsql \
    && pecl install redis && docker-php-ext-enable redis
COPY index.php /var/www/html/index.php
EXPOSE 80