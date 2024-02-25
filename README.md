# HelloGreengrass
AWT IoTCore Greengrass のお勉強

Configure aws.greengrass.clientdevices.Auth
```json
{
  "reset": [],
  "merge": {
    "deviceGroups": {
      "formatVersion": "2021-03-05",
      "definitions": {
        "MyDeviceGroup": {
          "selectionRule": "thingName: HelloGreenClient",
          "policyName": "MyRestrictivePolicy"
        }
      },
      "policies": {
        "MyRestrictivePolicy": {
          "AllowConnect": {
            "statementDescription": "Allow client devices to connect.",
            "operations": [
              "mqtt:connect"
            ],
            "resources": [
              "*"
            ]
          },
          "AllowPublish": {
            "statementDescription": "Allow client devices to publish on lients/e2c/hello/world.",
            "operations": [
              "mqtt:publish"
            ],
            "resources": [
              "mqtt:topic:clients/e2c/hello/world"
            ]
          },
          "AllowSubscribe": {
            "statementDescription": "Allow client devices to subscribe to clients/c2e/hello/world.",
            "operations": [
              "mqtt:subscribe"
            ],
            "resources": [
              "mqtt:topicfilter:clients/c2e/hello/world"
            ]
          }
        }
      }
    }
  }
}
```

Configure aws.greengrass.clientdevices.mqtt.Moquette
```json
{
  "reset": [],
  "merge": {
    "mqttTopicMapping": {
      "ClientDeviceHelloWorld": {
        "topic": "clients/+/hello/world",
        "source": "LocalMqtt",
        "target": "IotCore"
      },
      "CloudToClientDevices": {
        "topic": "clients/+/hello/world",
        "source": "IotCore",
        "target": "LocalMqtt"
      },
      "ClientDeviceEvents": {
        "topic": "clients/+/detections",
        "targetTopicPrefix": "events/input/",
        "source": "LocalMqtt",
        "target": "Pubsub"
      },
      "ClientDeviceCloudStatusUpdate": {
        "topic": "clients/+/status",
        "targetTopicPrefix": "$aws/rules/StatusUpdateRule/",
        "source": "LocalMqtt",
        "target": "IotCore"
      }
    }
  }
}
```

Configure aws.greengrass.clientdevices.mqtt.Bridge
```json
{
  "reset": [],
  "merge": {
    "mqttTopicMapping": {
      "HelloWorldIotCore": {
        "topic": "clients/e2c/hello/world",
        "source": "LocalMqtt",
        "target": "IotCore"
      },
      "IotCoreHelloWorld": {
        "topic": "clients/c2e/hello/world",
        "source": "IotCore",
        "target": "LocalMqtt"
      }
    }
  }
}```

# References

* [AWS IoT Greengrassとローカルデバイスの連携について]( https://aws.amazon.com/jp/blogs/news/implementing-local-client-devices-with-aws-iot-greengrass/ )
* [クライアントデバイス認証]( https://docs.aws.amazon.com/ja_jp/greengrass/v2/developerguide/client-device-auth-component.html )


