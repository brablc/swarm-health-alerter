### 🚪Check opened socks

Jump to [alerter configuration](./sock_monitoring.md#configuration).

#### Example

Imagine you want two services to communicate on the same host without using the docker mash network - via unix socks:

```yml
services:

    nginx:
        image: nginx:stable-alpine
        networks:
            - web
            - myproject
        deploy:
            replicas: 2
            placement:
                constraints:
                    - node.role == worker
                max_replicas_per_node: 1
            labels:
                - "traefik.enable=true"
                - "traefik.docker.network=web"
                - "traefik.http.routers.myproject-nginx.entrypoints=websecure"
                - "traefik.http.routers.myproject-nginx.rule=Host(`www.example.com`)"
                - "traefik.http.services.myproject-nginx.loadbalancer.server.port=80"
                - "swarm-health-alerter.port=80"
        configs:
            - source: myproject_nginx.conf_jing
              target: /etc/nginx/nginx.conf
        healthcheck:
            test: ["CMD-SHELL", "curl -sS -f http://localhost/health || exit 1"]
            interval: 10s
            timeout: 3s
            retries: 3
            start_period: 3s
        volumes:
            - /run:/run
            - django_static:/usr/share/nginx/html/static:ro

    django:
        image: myproject-django-app:latest
        networks:
            - myproject
        deploy:
            replicas: 2
            placement:
                constraints:
                    - node.role == worker
                max_replicas_per_node: 1
            update_config:
                delay: 10s
            labels:
                - "swarm-health-alerter.sock=unix:/run/myproject_django.sock"
        secrets:
            - source: myproject.env_jing
              target: /app/.env
        entrypoint: ["/bin/sh", "-c"]
        command: >
            "
            cp -Rf web/staticfiles/* /shared-static/;
            /swarm/bin/dockerize -wait tcp://rabbitmq:5672 -wait tcp://postgres:5432 gunicorn --chdir web adm.wsgi:application --bind unix:/run/myproject_django.sock
            "
        healthcheck:
            test: ["CMD-SHELL", "curl -sS -f --unix-socket /run/myproject_django.sock -H 'Host: www.example.com' http://localhost/health/ || exit 1"]
            interval: 10s
            timeout: 5s
            retries: 4
            start_period: 5s
        volumes:
            - /run:/run
            - /var/lib/swarm:/swarm
            - django_static:/shared-static
```

The complete nginx config `myproject_nginx.conf`:

```nginx
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;

events {
    worker_connections  256;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent" $request_time $host';

    access_log  /var/log/nginx/access.log  main;

    sendfile on;
    keepalive_timeout  65;

    set_real_ip_from  10.0.0.0/8;
    real_ip_header    X-Forwarded-For;
    real_ip_recursive on;

    resolver 127.0.0.11 valid=5s;

    upstream django {
        server unix:/run/myproject_django.sock;
    }

    server {
        listen 80;
        server_name www.example.com;

        location /static/ {
            alias /usr/share/nginx/html/static/;
        }

        location /health {
            return 200 'Healthy';
            add_header Content-Type text/plain;
        }

        location / {
            proxy_pass http://django;
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
        }
    }
}
```

#### Configuration

Alerter runs on all nodes, however, on worker nodes it has no way to access Docker API endpoint /services to read the labels for autodiscovery.
We enable access using service `swarm-api` - see that it has its own network `swarm-api` which is used to grant access to API. This acts as a proxy.

```yml
networks:
    edge:
        external: true
    web:
        external: true
    myproject:
        external: true
    swarm-api:
        external: true

services:
    swarm-api:
        image: alpine/socat
        networks:
            - swarm-api
        deploy:
            replicas: 2
            placement:
                constraints:
                    - node.role == manager
                max_replicas_per_node: 2
            update_config:
                delay: 30s
        command: "-dd TCP-L:2375,fork UNIX:/var/run/docker.sock"
        volumes:
           - /var/run/docker.sock:/var/run/docker.sock

    alerter:
        image: brablc/swarm-health-alerter
        networks:
            - myproject
            - edge
            - web
            - swarm-api
        deploy:
            mode: global
        environment:
            SWARM_API_URL: "http://swarm-api:2375"
            EVENTS_THRESHOLD: 3
            EVENTS_WINDOW: 120
            LOOP_SLEEP: 10
            ZENDUTY_API_KEY: XXXX
            ALERT_SCRIPT: /app/integrations/zenduty.sh
            SWARM_NAME: CanaryEggs
        volumes:
            - /run:/run
            - /var/run/docker.sock:/var/run/docker.sock
```

Sock monitoring checks presence of the sock file on each node. If it exists it checks if the sock is alive - more accurate than port check, because it checks every instance.
