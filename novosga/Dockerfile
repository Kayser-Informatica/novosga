FROM trafex/php-nginx:3.4.0 AS php

USER root

RUN apk add --no-cache \
    git \
    php82-iconv \
    php82-pdo_mysql \
    php82-pdo_pgsql \
    php82-simplexml \
    php82-tokenizer \
    php82-xmlwriter \
    php82-fileinfo \
    php82-sodium \
    php82-xsl

ADD etc/php.ini /etc/php82/conf.d/custom.ini
ADD etc/nginx.conf /etc/nginx/conf.d/default.conf

USER 65534
ADD --chown=65534:65534 . /var/www/html


FROM php AS composer

ARG GIT_COMMIT
ENV COMPOSER_CACHE_DIR=/tmp/
ENV APP_ENV=prod
ENV APP_DEBUG=0

RUN curl -o composer.phar https://getcomposer.org/download/2.7.2/composer.phar

RUN set -xe \
    && touch .env \
    && echo "APP_BUILD_NUMBER=$GIT_COMMIT" >> .env.local
RUN php composer.phar install --no-dev --optimize-autoloader --no-scripts
RUN php composer.phar dump-autoload --no-dev --classmap-authoritative
RUN php composer.phar dump-env prod
# Create bundles directory (assets will be installed at runtime)
RUN mkdir -p public/bundles


FROM alpine/openssl AS cert

RUN mkdir /jwt \
    && openssl genrsa -out /jwt/private.pem 2048 \
    && openssl rsa -in /jwt/private.pem -pubout -out /jwt/public.pem


FROM php

# Set the default parameters
ENV APP_ENV=prod \
    APP_DEBUG=0 \
    APP_SECRET \
    DATABASE_URL \
    MERCURE_URL \
    MERCURE_PUBLIC_URL \
    MERCURE_JWT_SECRET \
    OAUTH_PRIVATE_KEY \
    OAUTH_PUBLIC_KEY \
    OAUTH_PASSPHRASE \
    OAUTH_ENCRYPTION_KEY \
    LANGUAGE=pt_BR \
    NOVOSGA_ADMIN_USERNAME="admin" \
    NOVOSGA_ADMIN_PASSWORD="123456" \
    NOVOSGA_ADMIN_FIRSTNAME="Administrador" \
    NOVOSGA_ADMIN_LASTNAME="Global" \
    NOVOSGA_UNITY_NAME="Minha Unidade" \
    NOVOSGA_UNITY_CODE="U01" \
    NOVOSGA_NOPRIORITY_NAME="Normal" \
    NOVOSGA_NOPRIORITY_DESCRIPTION="Serviço normal" \
    NOVOSGA_PRIORITY_NAME="Prioridade" \
    NOVOSGA_PRIORITY_DESCRIPTION="Serviço prioritário" \
    NOVOSGA_PLACE_NAME="Guichê"

USER root

# Install supervisor
RUN apk add --no-cache supervisor

# Install supercronic
# https://github.com/aptible/supercronic/releases/tag/v0.2.33
ENV SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.2.33/supercronic-linux-amd64 \
    SUPERCRONIC_SHA1SUM=71b0d58cc53f6bd72cf2f293e09e294b79c666d8 \
    SUPERCRONIC=supercronic-linux-amd64

RUN curl -fsSLO "$SUPERCRONIC_URL"
RUN echo "${SUPERCRONIC_SHA1SUM}  ${SUPERCRONIC}" | sha1sum -c -
RUN chmod +x "$SUPERCRONIC"
RUN mv "$SUPERCRONIC" "/usr/local/bin/${SUPERCRONIC}"
RUN ln -s "/usr/local/bin/${SUPERCRONIC}" /usr/local/bin/supercronic

# Copy application files
COPY --from=composer --chown=65534:65534 /var/www/html/vendor /var/www/html/vendor
COPY --from=composer --chown=65534:65534 /var/www/html/.env.local.php /var/www/html/.env.local.php
# Create bundles directory (will be populated by assets:install at runtime if needed)
RUN mkdir -p /var/www/html/public/bundles && chown 65534:65534 /var/www/html/public/bundles
COPY --from=cert --chown=65534:65534 /jwt /var/www/html/config/jwt
# Ensure .env file exists (will be populated from ENV vars at runtime in start.sh)
RUN touch /var/www/html/.env && chown 65534:65534 /var/www/html/.env

# Copy scripts and configurations
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh
COPY etc/consumer.sh /usr/local/bin/consumer.sh
RUN chmod +x /usr/local/bin/consumer.sh
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY config/crontab /etc/crontab

USER nobody

CMD ["/usr/local/bin/start.sh"]
