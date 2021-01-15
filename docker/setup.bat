@echo off

RD /S /Q %CD%\tmp
docker-compose build
docker-compose down
docker-compose run web bundle exec rake db:setup