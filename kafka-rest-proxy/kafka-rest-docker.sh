#!/bin/bash

##################################################################################################################
### This script boots the kafka-rest container.
### It is expected/assumed that schema-registry and zookeeper containers are linked to this container via docker-compose
### PREQUISITES:
### 1) At least one Schema-registry container which is linked to this container via a link named 'schemaregistry'
###    AND which is running on/exposing port 8081
### 2) A Zookeeper container which is linked to this container via a link named 'zookeeper'
###    AND which is running on/exposing port 2181
### ACTIONS: 
### This script boots the kafka-rest container, as part of the booting process it does the following
### 1) Setup Default values, based on the linked schema-registry and zookeeper containers
### 2) Use any environment variable that matches 'KAFKA_REST_*' pattern to generate a server settings file
### 3) Repeatedly try to connect to the linked schema-registry containers on their advertised ports.
### 4) Once all linked schema-registry's are up and connectable, then start kafka-rest 
##################################################################################################################

### Setup and export default values.
: ${KAFKA_REST_ID:=kafka-rest-server-$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 7 | head -n 1)}
: ${KAFKA_REST_SCHEMA_REGISTRY_URL:=http://$SCHEMAREGISTRY_PORT_8081_TCP_ADDR:$SCHEMAREGISTRY_PORT_8081_TCP_PORT}
: ${KAFKA_REST_ZOOKEEPER_CONNECT:=$ZOOKEEPER_PORT_2181_TCP_ADDR:$ZOOKEEPER_PORT_2181_TCP_PORT}

export KAFKA_REST_ID
export KAFKA_REST_SCHEMA_REGISTRY_URL
export KAFKA_REST_ZOOKEEPER_CONNECT


### Generate the server properties file using environment variables that match 'KAFKA_REST_*' pattern
### E.g an environment variable KAFKA_REST_ID wqe2wek will result in 'id=wqe2wek' in the properties file
echo '# Generated by kafka-rest-docker.sh' > /etc/kafka-rest/kafka-rest.properties

for var in $(env | sort | grep '^KAFKA_REST_'); do
  key=$(echo $var | sed -r 's/KAFKA_REST_(.*)=.*/\1/g' | tr A-Z a-z | tr _ .)
  value=$(echo $var | sed -r 's/.*=(.*)/\1/g')
  echo "${key}=${value}" >> /etc/kafka-rest/kafka-rest.properties
done

### Wait for the linked schemaregistry to be running and contactable on it's advertised port.
for var in $(env | grep '^SCHEMAREGISTRY[[:digit:]]*_PORT=' | sort); do
  schemaregistry=$(echo $var | cut -d'_' -f1)
  schemaregistry_ip=$(echo $var | cut -d':' -f2 | cut -c3-)
  schemaregistry_port=$(echo $var | cut -d':' -f3)
  while true; do
    printf 'Waiting for %s to come online\n' ${schemaregistry}
    echo "" >> /dev/tcp/${schemaregistry_ip}/${schemaregistry_port} && printf "%s is online\n" ${schemaregistry} && break
    sleep 5
  done
done

### Start the kafka rest proxy
exec /usr/bin/kafka-rest-start /etc/kafka-rest/kafka-rest.properties

