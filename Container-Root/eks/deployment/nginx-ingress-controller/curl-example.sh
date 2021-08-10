#!/bin/bash

curl -H "Host: cpu-fastapi.torchserve.svc.cluster.local" htt-controller.ingress-nginx.svc.cluster.local/model/infer

