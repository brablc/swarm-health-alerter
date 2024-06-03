# swarm-health-alerter

Detect unhealthy containers using two methods:

1. **🚪Opened ports** - uses auto discovery and checks whether services with non zero replicas are available on those ports.
2. **💔 Failing services** - uses [Docker Events API](https://docs.docker.com/engine/api/v1.45/#tag/System/operation/SystemEvents) to detect containers, that are restarted too often.

## Configuration

### 🚪Opened ports

Add label `swarm-health-alerter.port` to all services, that should be monitored. Add `alerter` service to all networks so it can reach the ports:

```yml
services:
    rabbitmq:
        image: rabbitmq:3-management-alpine
        networks:
            - app
        deploy:
            replicas: 1
            labels:
                - "swarm-health-alerter.port=5672,15672"
```

### 💔 Failing services

Sometimes your service would fail (or be killed by healthcheck) and restart. The `scraper` service (does not have to be in the same network) monitors events `destroy` and `create` and sends them to the `alerter` who evaluates them.

If the number of `destroy` or `create` events exceeds configured `EVENTS_THRESHOLD` within `EVENTS_WINDOW` the service is deemed unhealthy and alert is created. If there was no event from the service withing the window, the problem is deemed resolved.

## Installation

Add an alerter service to some of your stacks and add it to all networks where it should be checking ports:

> [!IMPORTANT]
> Service `alerter` and `scraper` must be both in the same network (does not have to be dedicated).
> If you change the name of the `alerter` service you have to change `scraper`'s `ALERTER_URL`.

```yml
networks:
    alerter:
        driver: overlay
        attachable: true
    app:
        external: true
    web:
        external: true

services:
   alerter:
        image: brablc/swarm-health-alerter
        tty: true
        hostname: '{{.Node.Hostname}}'
        networks:
            - alerter
            - app
            - web
        deploy:
            replicas: 1
            placement:
                constraints:
                    - node.role == manager
        environment:
            ALERT_SCRIPT: /app/integrations/zenduty.sh
            EVENTS_THRESHOLD: 3
            EVENTS_WINDOW: 300
            LOOP_SLEEP: 10
            SWARM_NAME: ExampleSwarm
            ZENDUTY_API_KEY: YOUR_ZENDUTY_API_KEY
        volumes:
            - /var/run/docker.sock:/var/run/docker.sock

    scraper:
        image: brablc/swarm-health-alerter
        tty: true
        hostname: '{{.Node.Hostname}}'
        networks:
            - alerter
        deploy:
            mode: global
        environment:
            ALERTER_URL: http://alerter:80
        volumes:
            - /var/run/docker.sock:/var/run/docker.sock
```

## Integrations

At the moment there is only integration - with [Zenduty.com](https://www.zenduty.com/pricing/). The Free plan supports creation of events via [API](https://apidocs.zenduty.com/?ref=zenduty.com#tag/Events). Events can be used to create and resolve incidents. Incidents are pushed to a mobile app with critical alert support. Perfect 😍! In your account navigate to **Setup** > **Step 4 Configure Integrations** and add **Zenduty API**. Copy the integration key and use in `ZENDUTY_API_KEY`.

You can add another integration without rebuilding the image (I would recommend using a swarm config and mounting it to the integrations directory and changing `ALERT_SCRIPT` variable acordingly). Or just ask me for help.
