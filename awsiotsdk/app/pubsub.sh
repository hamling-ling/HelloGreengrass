#!/bin/bash

MSG_ENV_NOT_FOUND="not found in environmental variables"
[ "$PREFIX" == "" ]        && echo "PREFIX $MSG_ENV_NOT_FOUND"        && exit 1
[ "$PEM_CERT" == "" ]      && echo "PEM_CERT $MSG_ENV_NOT_FOUND"      && exit 1
[ "$PRI_KEY" == "" ]       && echo "PUB_KEY $MSG_ENV_NOT_FOUND"       && exit 1
[ "$CA" == "" ]            && echo "CA $MSG_ENV_NOT_FOUND"            && exit 1
[ "$DATA_ENDPOINT" == "" ] && echo "DATA_ENDPOINT $MSG_ENV_NOT_FOUND" && exit 1

python3 samples/pubsub.py \
--endpoint $DATA_ENDPOINT \
--ca_file $CA \
--cert $PEM_CERT \
--key $PRI_KEY

