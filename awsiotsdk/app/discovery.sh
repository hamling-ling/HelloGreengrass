#!/bin/bash

MSG_ENV_NOT_FOUND="not found in environmental variables"
[ "$CLIENT_THING_NAME" == "" ] && echo "CLIENT_THING_NAME $MSG_ENV_NOT_FOUND" && exit 1
[ "$CERT_DIR" == "" ]          && echo "CERT_DIR $MSG_ENV_NOT_FOUND"          && exit 1
[ "$PREFIX" == "" ]            && echo "PREFIX $MSG_ENV_NOT_FOUND"            && exit 1
[ "$PEM_CERT" == "" ]          && echo "PEM_CERT $MSG_ENV_NOT_FOUND"          && exit 1
[ "$PUB_KEY" == "" ]           && echo "PUB_KEY $MSG_ENV_NOT_FOUND"           && exit 1
[ "$PRI_KEY" == "" ]           && echo "PUB_KEY $MSG_ENV_NOT_FOUND"           && exit 1
[ "$CA" == "" ]                && echo "CA $MSG_ENV_NOT_FOUND"                && exit 1
[ "$AWS_REGION" == "" ]        && echo "AWS_REGION $MSG_ENV_NOT_FOUND"        && exit 1

# Test Authentication
curl -i \
--cert $PEM_CERT \
--key $PRI_KEY \
https://greengrass-ats.iot.$AWS_REGION.amazonaws.com:8443/greengrass/discover/thing/$CLIENT_THING_NAME


# Test Publish to e2c topic
python3 samples/basic_discovery.py \
--thing_name $CLIENT_THING_NAME \
--topic 'clients/e2c/hello/world' \
--message 'Hello World!' \
--ca_file $CA \
--cert $PEM_CERT \
--key $PRI_KEY \
--region $AWS_REGION \
--verbosity Warn \
--mode publish \
--max_pub_ops 3

# Test Subscribe to c2e topic
python3 samples/basic_discovery.py \
--thing_name $CLIENT_THING_NAME \
--topic 'clients/c2e/hello/world' \
--message 'Hello World!' \
--ca_file $CA \
--cert $PEM_CERT \
--key $PRI_KEY \
--region $AWS_REGION \
--verbosity Warn \
--mode subscribe
