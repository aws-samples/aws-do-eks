# Traefik Reverse Proxy Example

This example deploys a service called `whoami`, scaled to two pods.
It exposes the service in two different ways:

1. Traefik Ingress Route - accessible via path `/notls` on the traefik-dashboard URL
2. Kubernetes Ingress - accessible via path /notls-whoami on the traefik web URL 

As the service endpoints are accessed, the traefik_service_requests_total Prometheus counters served by the Traefik `/metrics` API reflect the number of requests to the service.
These metrics can be used for horizontal pod autoscaling via Prometheus and Keda.

