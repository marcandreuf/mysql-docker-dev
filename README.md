# Build the custom image
```shell
docker build -t mysql-dev-init .
```

# Create custom docker network if not exists
```shell
docker network create mysql-net
```

# Run custom mysql
```shell
# Run and do NOT delete the container so the entry point can load
# the new models added to the db-models folder.
docker run --network mysql-net --name localtest -e MYSQL_ROOT_PASSWORD=roottest1 -e MYSQL_DATABASE=employees -v $PWD/db-models:/docker-entrypoint-initdb.d -d mysql-dev-init:latest
```


# Test connecting another mysql container
```shell
docker run -it --rm --network mysql-net mysql mysql -hlocaltest -uroot -p
#or
docker run -it --rm --network mysql-net mysql:8.0.26 mysql -hlocaltest -uroot -p
```


# Connect via adminer
```shell
docker run --rm --network mysql-net --name adminer -p 8080:8080 adminer
```

# Stop test containers
```shell
docker stop localtest adminer
```


# Run dev interactive mode with shared db-models folder to directly run commands and test the entry point script step by step.
```shell
docker run -it --network mysql-net \
--name localtest \
-v $PWD:/e2edev \
-v $PWD/db-models:/docker-entrypoint-initdb.d \
-w /e2edev \
-e MYSQL_ROOT_PASSWORD=roottest1 \
-e MYSQL_DATABASE=employees \
--entrypoint '' \
mysql-dev-init:latest bash
#-u $(id -u ${USER}):$(id -g ${USER}) \
```

## Table in mysql db to keep track of latest init file name
```sql
# USE mysql;

CREATE TABLE IF NOT EXISTS mysql.dev_init_scripts(id MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT, filename VARCHAR(80) NOT NULL, lastUpdate DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, PRIMARY KEY(id));
# 
DROP TABLE dev_init_scripts;
#
INSERT INTO mysql.dev_init_scripts (filename) VALUES ('005_filename');
INSERT INTO mysql.dev_init_scripts (filename) VALUES ('006_filename');
INSERT INTO mysql.dev_init_scripts (filename) VALUES ('007_filename');
# Select latest registered script 
SELECT filename FROM mysql.dev_init_scripts ORDER BY `id` DESC LIMIT 1;

```

# TODO.
1. Continue from testing running the shared folder db-models mode