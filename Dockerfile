FROM mysql:8.0.26

COPY dev-init-entry-point.sh /usr/local/bin/dev-init-entry-point.sh

ENTRYPOINT ["dev-init-entry-point.sh"]

CMD ["mysqld"]
