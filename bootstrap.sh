#!/bin/sh
set +e
export TZ='Asia/Shanghai'

home=${MOUNTPOINT}
php_fpm="php-fpm${MAINVER}"

get_last() {
    echo "${1}" | sed -e 's/.*\(.\)$/\1/'
}
if [ $(get_last "${home}") = / ]; then home="${home%%/}"; fi

ensure_dir() {
    if [ "${1:0:1}" = / ]; then
        target="${1}"
    else
        target="${home}/${1}"
    fi

    if [ ! -e "${target}" ]; then
        echo "create ${target}"
        mkdir -p "${target}"
    fi
}

persist_r() {
    if [ $(get_last "${1}") = / ]; then dir="${1%%/}"; else dir="${1}"; fi
    if [ -z "${2}" ]; then prefix="${1}"; else prefix="${2}"; fi

    rela_d="${1##${prefix}}"
    if [ ! -z "${rela_d}" ]; then
        if [ "${rela_d:0:1}" = / ]; then target="${home}${rela_d}"; else target="${home}/${rela_d}"; fi
        ensure_dir "${target}"
    fi

    for f in "${dir}"/*; do
        if [ -d "${f}" ]; then persist_r "${f}" "${prefix}"; fi

        rela_f="${f##${prefix}}"
        if [ "${rela_f:0:1}" = / ]; then
            target="${home}${rela_f}"
        else
            target="${home}/${rela_f}"
        fi
        if [ ! -e "${target}" ]; then
            cp "${f}" "${target}"
        fi
    done
}

nginx_CAR() {
    if [ -e "${1}" ]; then
        rm -f "${1}" && nginx -t
        if [ $? -eq 0 ]; then
            nginx -s reload
        else
            nginx -t 1>>"${1}.FAIL" 2>&1
        fi
    fi
}

php_CAR() {
    if [ -e "${1}" ]; then
        rm -f "${1}" && ${php_fpm} -t
        if [ $? -eq 0 ]; then
            /bin/kill -USR2 $(cat /tmp/php.pid)
        else
            ${php_fpm} -t 1>>"${1}.FAIL" 2>&1
        fi
    fi
}




# init
ensure_dir logs/session
ensure_dir conf.d/nginx
ensure_dir conf.d/php

persist_r /usr/share/nas

# Supervise Nginx & PHP
while true
do
    if [ ! "$(ps aux | grep php-fpm | grep -v grep)" ]; then
        echo "starting php-fpm..."
        ${php_fpm} -t 1>/dev/null 2>&1
        if [ ! $? -eq 0 ]; then
            ${php_fpm} -t 1>>"${home}/logs/conf.d.log" 2>&1
            mv "${home}/conf.d/php" "${home}/conf.d/php_$(date +"%Y-%m-%dT%H:%MZ")"
            persist_r /usr/share/nas
        fi
        ${php_fpm} --daemonize --pid /tmp/php.pid
    fi
    if [ ! "$(ps aux | grep nginx | grep -v grep)" ]; then
        echo "starting nginx..."
        nginx -t 1>/dev/null 2>&1
        if [ ! $? -eq 0 ]; then
            nginx -t 1>>"${home}/logs/conf.d.log" 2>&1
            mv "${home}/conf.d/nginx" "${home}/conf.d/nginx_$(date +"%Y-%m-%dT%H:%MZ")"
            mkdir -p "${home}/conf.d/nginx"
        fi
        nginx
    fi

    nginx_CAR "${home}/conf.d/nginx/RELOAD"
    php_CAR "${home}/conf.d/php/RELOAD"
    sleep 1
done
