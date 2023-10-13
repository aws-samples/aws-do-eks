#!/bin/bash

. .env

kubetail $JOB_NAME -s 60s

