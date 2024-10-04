#!/bin/bash
set -eo pipefail
shopt -s nullglob

source "$(which docker-entrypoint.sh)"

# --- ADDED 2022.12.5
mysql_note "Custom entrypoint script for MySQL Server ${MYSQL_VERSION} started."

register_latest_init_file() {
    echo
    mysql_note "Register latest processed file."    
    local lindex="$#"    
    local filename=$(basename ${!lindex})
    mysql_note "Last processed init file index ${lindex} is: ${filename}"
    insert_latest_init_file_to_db "${filename}"
}

insert_latest_init_file_to_db() {
    local filename="$1"
    docker_process_sql --database=mysql <<-EOSQL
			CREATE TABLE IF NOT EXISTS mysql.dev_init_scripts(id MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT, filename VARCHAR(80) NOT NULL, lastUpdate DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, PRIMARY KEY(id));
            INSERT INTO mysql.dev_init_scripts (filename) VALUES ('${filename}');
		EOSQL
    mysql_note "Last processed init file ${filename} has been registered to the table mysql.dev_init_scripts"
}

get_new_files() {
    local lindex="$#"    
    local cnt=1
    local newFiles
    for arg in "$@"
    do
       if [[ $cnt -lt $lindex ]]; then
            filename=$(basename $arg)
            if [[ $filename > ${!lindex} ]]; then
                newFiles+="$arg "
            fi
       fi
       let "cnt+=1"
    done
    echo $newFiles
}

get_latest_processed_model() {
    local query_latest_model="SELECT filename FROM mysql.dev_init_scripts ORDER BY id DESC LIMIT 1;"
    echo $(mysql --protocol=socket -uroot -hlocalhost --socket="${SOCKET}" -p"${MYSQL_ROOT_PASSWORD}" mysql -s -N -e "${query_latest_model}")
}
# ---


# If command starts with an option, prepend mysqld
if [ "${1:0:1}" = '-' ]; then
    mysql_note "prepend mysqld"
    set -- mysqld "$@"
fi

mysql_note "Start setup"
# skip setup if they aren't running mysqld or want an option that stops mysqld
if [ "$1" = 'mysqld' ] && ! _mysql_want_help "$@"; then
    mysql_note "Entrypoint script for MySQL Server ${MYSQL_VERSION} started."

    cnt=1
    for arg in "$@"
    do
        mysql_note "Arg #$cnt= $arg"
        let "cnt+=1"
    done

    mysql_check_config "$@"
    # Load various environment variables
    docker_setup_env "$@"
    docker_create_db_directories

    # If container is started as root user, restart as dedicated mysql user
    if [ "$(id -u)" = "0" ]; then
        mysql_note "Switching to dedicated user 'mysql'"
        exec gosu mysql "$BASH_SOURCE" "$@"
    fi

    # there's no database, so it needs to be initialized
    if [ -z "$DATABASE_ALREADY_EXISTS" ]; then
        docker_verify_minimum_env

        # check dir permissions to reduce likelihood of half-initialized database
        ls /docker-entrypoint-initdb.d/ > /dev/null

        docker_init_database_dir "$@"

        mysql_note "Starting temporary server"
        docker_temp_server_start "$@"
        mysql_note "Temporary server started."

        docker_setup_db
        docker_process_init_files /docker-entrypoint-initdb.d/*

        # --- ADDED 2022.12.5
        register_latest_init_file /docker-entrypoint-initdb.d/*
        # ---

        mysql_expire_root_user

        mysql_note "Stopping temporary server"
        docker_temp_server_stop
        mysql_note "Temporary server stopped"

        echo
        mysql_note "MySQL init process done. Ready for start up."
        echo
    
    # --- ADDED 2022.12.5 New else case to run after first time.
    else
        echo
        mysql_note "DB is already created."

        # check dir permissions to reduce likelihood of half-initialized database
        ls /docker-entrypoint-initdb.d/ > /dev/null

        mysql_note "Starting temporary server"
        docker_temp_server_start "$@"
        mysql_note "Temporary server started."

        SOCKET="$(mysql_get_config 'socket' "$@")"
        mysql_note "Socket is ${SOCKET}"

        latest="$(get_latest_processed_model)"
        mysql_note "Latest processed model was: ${latest}" 

        new_files=$(get_new_files /docker-entrypoint-initdb.d/* $latest)
        if [ "$new_files" = "" ]; then
            mysql_note "NO new DB models found. Not processing more init files."
        else
            mysql_note "Processing new DB models '$new_files'"
            docker_process_init_files $new_files
            register_latest_init_file $new_files
        fi

        mysql_note "Stopping temporary server"
        docker_temp_server_stop
        mysql_note "Temporary server stopped"
    fi
    # ---
else
    mysql_note "Skipping setup. Argument 1 missing: '$1'"
fi
exec "$@"
