# topic to Publish: clients/e2c/hello/world
# topic to Subscribe: clients/c2e/hello/world

import os
import time
import threading
from greengrass_client import GreengrassClient

CLIENT_THING_NAME=os.environ['CLIENT_THING_NAME']
PEM_CERT=os.environ['PEM_CERT']
PUB_KEY=os.environ['PUB_KEY']
PRI_KEY=os.environ['PRI_KEY']
CA=os.environ['CA']
AWS_REGION=os.environ['AWS_REGION']
DATA_ENDPOINT=os.environ['DATA_ENDPOINT']

TOPIC_PUBLISH="clients/e2c/hello/world"
TOPIC_SUBSCRIBE="clients/c2e/hello/world"


def publish_proc(max_message=30):
    loop_count = 0
    while loop_count < max_message:
        message = {}
        message['message'] = "Hello World"
        message['sequence'] = loop_count

        client.publish(message)

        loop_count += 1
        #time.sleep(1)


client=GreengrassClient(
    CLIENT_THING_NAME,
    PEM_CERT,
    PUB_KEY,
    PRI_KEY,
    CA,
    AWS_REGION,
    DATA_ENDPOINT,
    TOPIC_PUBLISH,
    TOPIC_SUBSCRIBE
)

client.connect()

threads = []
for x in range(1000):
    th = threading.Thread(target=publish_proc)
    th.start()
    threads.append(th)

for th in threads:
    th.join()
