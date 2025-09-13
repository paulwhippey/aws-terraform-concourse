#!/bin/bash
export HOME="/root"
export AWS_DEFAULT_REGION=${aws_default_region}
export CONCOURSE_USER=${concourse_username}
export CONCOURSE_PASSWORD=${concourse_password}

fly_tarball="/usr/local/concourse/fly-assets/fly-linux-amd64.tgz"
mkdir -p $HOME/bin
tar -xzf $fly_tarball -C $HOME/bin/

echo `date +'%Y %b %d %H:%M:%S'` "Waiting for Concourse to start."
while [[ "$(netstat -pln | grep ${concourse_web_port} | grep LISTEN | wc -l)" -lt 1 ]]; do
  sleep 5
  ((i=i+1))
  if [[ $i -gt 200 ]]; then
    exit 1
    echo `date +'%Y %b %d %H:%M:%S'` "Timed out waiting for Concourse to start."
  fi
done
echo `date +'%Y %b %d %H:%M:%S'` "Concourse service is up and listening on TCP port ${concourse_web_port}"

echo `date +'%Y %b %d %H:%M:%S'` "Creating Concourse teams"
$HOME/bin/fly --target ${target} login \
--concourse-url http://127.0.0.1:${concourse_web_port} \
--username $CONCOURSE_USER \
--password $CONCOURSE_PASSWORD

team_check=`$HOME/bin/fly -t ${target} teams | grep -v name | grep -v main`

for team in $(ls $HOME/teams); do
    echo `date +'%Y %b %d %H:%M:%S'` "--- Creating team: $team ---"
    /root/bin/fly -t ${target} set-team \
    --non-interactive \
    --team-name=$team \
    --config=/root/teams/$team/team.yml
done
