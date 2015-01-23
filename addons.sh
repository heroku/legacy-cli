#!/bin/bash

function h() {
  output="$(bin/heroku $*)"

  (
    echo "***************"
    echo
    echo "> heroku $*"
    echo $output
    echo
    echo "***************"
    echo
  ) >&2

  echo $output
}


function create_addon() {
  app=$1
  service_plan=$2

  output="$(h addons:create $service_plan -a $app $*)"

  echo $output | ruby -e 'puts ARGF.read.match(/Adding ([a-z0-9-]+) /)[1]' 
}

APP_NAME=mathias-addon-test
APP_2_NAME=other-mathias-test

(
  # Classic create
  ./bin/heroku apps:create $APP_NAME

  # resource_name "./bin/heroku addons:create rollbar -a $APP_NAME"
  name="$(create_addon $APP_NAME rollbar)"
  echo $name
  ./bin/heroku addons:destroy $name -a $APP_NAME --confirm $APP_NAME

  # With many-per-app/attachable add-on:
  name="$(create_addon $APP_NAME slowdb)"
  echo $name
  ./bin/heroku addons:destroy $name -a $APP_NAME --confirm $APP_NAME

  # With switzerland feature flags
  ./bin/heroku apps:create $APP_2_NAME
  ./bin/heroku labs:enable switzerland-models -a $APP_2_NAME

  name="$(create_addon $APP_2_NAME slowdb)"
  echo $name
  ./bin/heroku addons:destroy $name -a $APP_2_NAME --confirm $APP_2_NAME

) || true

# Always teardown
(
  ./bin/heroku apps:destroy $APP_NAME --confirm $APP_NAME
  ./bin/heroku apps:destroy $APP_2_NAME --confirm $APP_2_NAME
)

if [[ success ]]; then echo "☁ ☁ ☁ ☁ yay cloud ☁ ☁ ☁ ☁"; fi

