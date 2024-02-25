#!/bin/bash

curl -LO https://github.com/aws/aws-iot-device-sdk-python-v2/archive/refs/tags/v1.12.0.zip && \
unzip v1.12.0.zip && \
mv aws-iot-device-sdk-python-v2-1.12.0/samples awsiotsdk/app/samples && \
rm -rf aws-iot-device-sdk-python-v2-1.12.0 v1.12.0.zip
