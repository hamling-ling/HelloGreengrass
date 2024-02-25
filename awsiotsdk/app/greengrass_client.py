
import time
import json
import os
from concurrent.futures import Future
from awscrt import io
from awscrt.mqtt import QoS
from awsiot.greengrass_discovery import DiscoveryClient
from awsiot import mqtt_connection_builder

class GreengrassClient:
    def __init__(self,
                 client_thing_name,
                 pem_cert,
                 pub_key,
                 pri_key,
                 ca,
                 region,
                 data_endpoing,
                 topic_publish,
                 topic_subscribe
                 ):
        self.CLIENT_THING_NAME=client_thing_name
        self.PEM_CERT=pem_cert
        self.PUB_KEY=pub_key
        self.PRI_KEY=pri_key
        self.CA=ca
        self.AWS_REGION=region
        self.DATA_ENDPOINT=data_endpoing

        self.TOPIC_PUBLISH=topic_publish
        self.TOPIC_SUBSCRIBE=topic_subscribe

        tls_options = io.TlsContextOptions.create_client_with_mtls_from_path(self.PEM_CERT, self.PRI_KEY)
        tls_options.override_default_trust_store_from_path(None, self.CA)
        self.tls_context = io.ClientTlsContext(tls_options)

        self.socket_options = io.SocketOptions()
        self.discover_response = None

    def connect(self):
        self.discover()
        self.mqtt_connection = self.try_iot_endpoints()
        #self.subsctibe()

    def on_connection_interupted(self, connection, error, **kwargs):
        print('connection interrupted with error {}'.format(error))

    def on_connection_resumed(self, connection, return_code, session_present, **kwargs):
        print('connection resumed with return code {}, session present {}'.format(return_code, session_present))

    def on_publish(self, topic, payload, dup, qos, retain, **kwargs):
        print('Publish received on topic {}'.format(topic))
        print(payload)

    def discover(self):
        print('Performing greengrass discovery...')
        discovery_client = DiscoveryClient(io.ClientBootstrap.get_or_create_static_default(), self.socket_options, self.tls_context, self.AWS_REGION)
        resp_future = discovery_client.discover(self.CLIENT_THING_NAME)
        self.discover_response = resp_future.result()

        print(self.discover_response)

    # Try IoT endpoints until we find one that works
    def try_iot_endpoints(self):
        for gg_group in self.discover_response.gg_groups:
            for gg_core in gg_group.cores:
                for connectivity_info in gg_core.connectivity:
                    try:
                        print('Trying core {} at host {} port {}'.format(gg_core.thing_arn, connectivity_info.host_address, connectivity_info.port))
                        mqtt_connection = mqtt_connection_builder.mtls_from_path(
                            endpoint=connectivity_info.host_address,
                            port=connectivity_info.port,
                            cert_filepath=self.PEM_CERT,
                            pri_key_filepath=self.PRI_KEY,
                            ca_bytes=gg_group.certificate_authorities[0].encode('utf-8'),
                            on_connection_interrupted=self.on_connection_interupted,
                            on_connection_resumed=self.on_connection_resumed,
                            client_id=self.CLIENT_THING_NAME,
                            clean_session=False,
                            keep_alive_secs=30)

                        connect_future = mqtt_connection.connect()
                        connect_future.result()
                        print('Connected!')
                        return mqtt_connection

                    except Exception as e:
                        print('Connection failed with exception {}'.format(e))
                        continue

        exit('All connection attempts failed')

    def subsctibe(self):
        subscribe_future, _ = self.mqtt_connection.subscribe(self.TOPIC_SUBSCRIBE, QoS.AT_MOST_ONCE, self.on_publish)
        subscribe_result = subscribe_future.result()
        print(subscribe_result)

    def publish(self, message):
        messageJson = json.dumps(message)
        pub_future, _ = self.mqtt_connection.publish(self.TOPIC_PUBLISH, messageJson, QoS.AT_MOST_ONCE)
        pub_future.result()
        print('Published topic {}: {}\n'.format(self.TOPIC_PUBLISH, messageJson))
