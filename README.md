# swarm-health-alerter

Detect unhealthy containers using two methods:

1. **🚪 Opened ports/socks** - uses auto discovery and checks whether services with non zero replicas are available on those ports/socks.
2. **📜 Docker events** - analyzes events generated by swarm when containers are created/destroyed 🔁 or have failing healthcheck 💔.

## Configuration

### 🚪Opened ports/socks

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

The port monitoring does not ensure proper number of instances, it is satisfied when at least one instance is running on the port.

Monitoring of processes communicating via unix socks is supported - it has some advantages, but requires extra step - see [documentation](./docs/sock_monitoring.md).

### 📜 Docker events

Uses [Docker Events API](https://docs.docker.com/engine/api/v1.45/#tag/System/operation/SystemEvents) to monitor two conditions:

#### 🔁 Restarting services

Sometimes your service would fail (or be killed by healthcheck) and restart. This would be seen as event `destroy` and `create`. If both the number of `destroy` and `create` events exceed configured `EVENTS_THRESHOLD` within `EVENTS_WINDOW`, the service is deemed unhealthy and alert is created. If there was no event from the service within the window, the problem is deemed resolved.

> [!TIP]
> Services containing `adhoc` in their name are ignored.

#### 💔 Failing healthcheck

When healtcheck fails for given number of retries, it would normally lead to a service restart. In certain situation this is better avoided as it can lead to loss of data (imagine RabbitMQ being killed while recovering queues from disk). In such situation you may prefer to set high number of retries for healtcheck: `retries: 9999` and get alerted when the number of failed healthcheck retries exceeds configured `EVENTS_THRESHOLD`.

## Installation

Add an alerter service to some of your stacks and add it to all networks where it should be checking ports:

```yml
services:
   alerter:
        image: brablc/swarm-health-alerter
        tty: true
        hostname: '{{.Node.Hostname}}'
        networks:
            - app
            - web
        deploy:
            mode: global
        environment:
            ALERT_SCRIPT: /app/integrations/zenduty.sh
            EVENTS_THRESHOLD: 3
            EVENTS_WINDOW: 60
            LOOP_SLEEP: 10
            SWARM_NAME: ExampleSwarm
            ZENDUTY_API_KEY: YOUR_ZENDUTY_API_KEY
        volumes:
            - /var/run/docker.sock:/var/run/docker.sock
```

## Integrations

At the moment there is only integration - with [Zenduty.com](https://www.zenduty.com/pricing/). The Free plan supports creation of events via [API](https://apidocs.zenduty.com/?ref=zenduty.com#tag/Events). Events can be used to create and resolve incidents. Incidents are pushed to a mobile app with critical alert support. Perfect 😍! In your account navigate to **Setup** > **Step 4 Configure Integrations** and add **Zenduty API**. Copy the integration key and use in `ZENDUTY_API_KEY`.

You can add another integration without rebuilding the image (I would recommend using a swarm config and mounting it to the integrations directory and changing `ALERT_SCRIPT` variable acordingly). Or just ask me for help.

## Alerting for any service

You can utilize swarm service healthchecks to create/resolve incidents for any other service based on their condition (even when they do not fail).

See example of [Django management command for Celery monitoring ](https://gist.github.com/brablc/b5a585341af60dc2d2cc417b3d0b5a4e) - this script listens to celery workers' events (add `--events` to Celery worker command) and when it finds that some Celery task is failing consistently, its healthckeck would start failing too and this would be cought and reported by `swarm-health-alerter`.
