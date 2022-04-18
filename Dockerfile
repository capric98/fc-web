FROM alpine:3.15
LABEL GitRepo="https://github.com/capric98/fc-web"

ARG MOUNT_POINT=/home/app
ARG NAS_UID=10003
ARG NAS_GID=10003
ARG FC_PORT=9000

ARG PHP_VER="php8"
ARG PHP_MAIN_VER="8"

# timezone
RUN apk add --no-cache tzdata
RUN cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
RUN apk add --no-cache \
  curl nginx \
  ${PHP_VER}-fpm \
  ${PHP_VER}-common \
  ${PHP_VER}-ctype \
  ${PHP_VER}-curl \
  ${PHP_VER}-fileinfo \
  ${PHP_VER}-gd \
  ${PHP_VER}-json \
  ${PHP_VER}-mbstring \
  ${PHP_VER}-opcache \
  ${PHP_VER}-openssl \
  ${PHP_VER}-pdo_sqlite \
  ${PHP_VER}-soap \
  ${PHP_VER}-session \
  ${PHP_VER}-sqlite3 \
  ${PHP_VER}-tokenizer \
  ${PHP_VER}-xml \
  ${PHP_VER}-zip

# Nginx default log dir.
RUN rm -rf /var/lib/nginx/logs
RUN ln -s ${MOUNT_POINT}/logs /var/lib/nginx/logs

# Configure nginx
COPY nginx.conf /etc/nginx/nginx.conf
RUN sed -i "s|\${FCPORT}|${FC_PORT}|g" /etc/nginx/nginx.conf
RUN sed -i "s|\${MOUNTPOINT}|${MOUNT_POINT}|g" /etc/nginx/nginx.conf
# Configure PHP
COPY php-fpm.conf /etc/php${PHP_MAIN_VER}/php-fpm.d/www.conf
RUN sed -i "s|\${MOUNTPOINT}|${MOUNT_POINT}|g" /etc/php${PHP_MAIN_VER}/php-fpm.d/www.conf

RUN sed -i "s|expose_php|; expose_php|g" /etc/php${PHP_MAIN_VER}/php.ini
RUN sed -i "s|memory_limit|; memory_limit|g" /etc/php${PHP_MAIN_VER}/php.ini
RUN sed -i "s|post_max_size|; post_max_size|g" /etc/php${PHP_MAIN_VER}/php.ini
RUN sed -i "s|upload_max_filesize|; upload_max_filesize|g" /etc/php${PHP_MAIN_VER}/php.ini

RUN echo "session.save_path = "${MOUNT_POINT}/logs/session"" >> /etc/php${PHP_MAIN_VER}/php.ini
RUN ln -s "${MOUNT_POINT}/conf.d/php/ini" /usr/share/php${PHP_MAIN_VER}

# Persistent files
COPY nas /usr/share/nas

# Init script
COPY bootstrap.sh /bootstrap
RUN sed -i "s|\${MOUNTPOINT}|${MOUNT_POINT}|g" /bootstrap
RUN sed -i "s|\${MAINVER}|${PHP_MAIN_VER}|g" /bootstrap
RUN chmod +x /bootstrap

# Make sure files/folders needed by the processes are accessable.
RUN chown -R ${NAS_UID}:${NAS_GID} \
  /bootstrap \
  /usr/share/nas \
  /usr/share/nginx /usr/share/php${PHP_MAIN_VER} \
  /var/lib/nginx /etc/nginx /etc/php${PHP_MAIN_VER}

# Expose the service
EXPOSE ${FC_PORT}
USER ${NAS_UID}:${NAS_GID}
CMD ["/bootstrap"]
