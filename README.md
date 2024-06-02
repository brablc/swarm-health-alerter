# swarm-health-alerter

Create/resolve alerts when some services are not running in docker swarm.

## Functionality

Uses auto discovery, just add labels to your services with list of ports: `swarm-health-alerter.port=80,443` . 

> [!TIP]
> More checking can be added, just ask for them.

### Monitored conditions:

- Monitored are services containing label `swarm-health-alerter.port` which are running in global mode or running in replicated mode with non-zero number of replicas.

### Configuration example

```sh
    rabbitmq:
        image: rabbitmq:3-management-alpine
        networks:
            - app
        deploy:
            replicas: 1
            labels:
                - "swarm-health-alerter.port=5672,15672"
```

## Installation

Add an alerter service to some of your stacks and add it to all networks it should be checking:

```yml
networks:
    app:
        external: true
    web:
        external: true

services:    
    alerter:
        image: brablc/swarm-health-alerter
        networks:
            - app
            - web
        deploy:
            replicas: 1
        environment:
            LOOP_SLEEP: 10s
            ZENDUTY_API_KEY: YOUR_ZENDDUTY_API_KEY
            ALERT_SCRIPT: /app/integrations/zenduty.sh
            SWARM_NAME: ExampleSwarm
        volumes:
            - /var/run/docker.sock:/var/run/docker.sock
```

## Integrations

At the moment there is only integration - with [Zenduty.com](https://www.zenduty.com/pricing/). The Free plan supports creation of events via [API](https://apidocs.zenduty.com/?ref=zenduty.com#tag/Events). Events can be used to create and resolve incidents. Incidents are pushed to a mobile app with critical alert support. Perfect 😍! In your account navigate to **Setup** > **Step 4 Configure Integrations** and add **Zenduty API**. Copy the integration key and use in `ZENDUTY_API_KEY`. 

You can add another integration without rebuilding the image (I would recommend using a swarm config and mounting it to the integrations directory and changing `ALERT_SCRIPT` variable acordingly). Or just ask me for help.


