#!/bin/bash
set -e

if [ $(rake db:migrate:status | grep up | wc -l) -eq 0 ]; then
  rake db:reset setup
else
  rake db:migrate
fi

./bin/puma -C config/puma.rb
