#!/bin/bash

aws cloud9 update-environment --environment-id $C9_PID --managed-credentials-action DISABLE

