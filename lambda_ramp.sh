#!/bin/bash
# Ramp lambda from 5 to 50 over 10 minutes

topic=$1
initial=5
max=50
step=5
interval=60

for ((lam=$initial; lam<=$max; lam+=$step)); do
  echo "$lam" > lambda_${topic}.txt
  echo "$(date): λ = $lam"
  sleep $interval
done
