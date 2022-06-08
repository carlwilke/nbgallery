#!/bin/bash

# Rewite the entire file to use the new MariaDB data instead of MARIADB
# Create a new file called docker-entrypoint.sh with the correct data there
# Wait until MARIADB is up and available, retrying 10 times with a 5 second wait
MAX_TRIES=10
TRIES=0
WAIT_SECONDS=5
until [ ${TRIES} -ge ${MAX_TRIES} ]
do
    TRIES=$[${TRIES}+1]

    if MARIADBadmin ping --host=${GALLERY__MARIADB__HOST} --port=${GALLERY__MARIADB__PORT} \
        --user=${GALLERY__MARIADB__USERNAME} --password=${GALLERY__MARIADB__PASSWORD}; then
        echo "MARIADB service at ${GALLERY__MARIADB__HOST}:${GALLERY__MARIADB__PORT} was found to be UP on ${TRIES} of ${MAX_TRIES} tries. Continuing..."
        break
    else
        echo "MARIADB service at ${GALLERY__MARIADB__HOST}:${GALLERY__MARIADB__PORT} was found to be DOWN on ${TRIES} of ${MAX_TRIES} tries. Retrying..."
    fi

    sleep ${WAIT_SECONDS}
done

# Once MARIADB is up, create the database if it doesn't exist
echo "Creating database ${GALLERY__MARIADB__DATABASE} if it doesn't exist on ${GALLERY__MARIADB__HOST}"
MARIADB -h${GALLERY__MARIADB__HOST} -p${GALLERY__MARIADB__PORT} -u${GALLERY__MARIADB__USERNAME} -p"${GALLERY__MARIADB__PASSWORD}" \
    -e "CREATE DATABASE IF NOT EXISTS ${GALLERY__MARIADB__DATABASE}"

# Wait until the database has been created before starting the rest of the services, retrying 10 times with a 5 second wait
MAX_TRIES=10
TRIES=0
WAIT_SECONDS=5
until [ ${TRIES} -ge ${MAX_TRIES} ]
do
    TRIES=$[$TRIES+1]

    FOUND_DB=`MARIADBshow --host=${GALLERY__MARIADB__HOST} --user=${GALLERY__MARIADB__USERNAME} \
        --password=${GALLERY__MARIADB__PASSWORD} ${GALLERY__MARIADB__DATABASE}| grep -v Wildcard \
        | grep -o ${GALLERY__MARIADB__DATABASE}`

    if [ "$FOUND_DB" == "${GALLERY__MARIADB__DATABASE}" ]; then
        echo "Database ${GALLERY__MARIADB__DATABASE} found on try ${TRIES} of ${MAX_TRIES}. Continuing to startup services..."
        break
    else
        echo "Database ${GALLERY__MARIADB__DATABASE} NOT found on try ${TRIES} of ${MAX_TRIES}"
    fi

  sleep ${WAIT_SECONDS}
done

if [ -z "$SECRET_KEY_BASE" ]; then
  export SECRET_KEY_BASE=`bundle exec rake secret | grep -v Loading`
fi
bundle exec rake db:migrate
bundle exec rake assets:precompile
bundle exec rake create_default_admin
bundle exec rails server -b 0.0.0.0
