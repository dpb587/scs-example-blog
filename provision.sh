#!/bin/bash

set -e

echo '--> Bootstrapping...'

if [[ -f scs-utils/bin/scs-bootstrap-dev ]] ; then
  bash scs-utils/bin/scs-bootstrap-dev
else
  wget -O- https://raw2.github.com/dpb587/scs-utils/master/bin/scs-bootstrap-dev | bash -s -
fi

apt-get install -y expect

RPWD=`echo $PWD | sed 's/\//\\\\\//'`

SERVICES=$(find supervisor/ -name *.ini | sed -r 's/supervisor\/([^\/]+).ini$/\1/' | grep -v scs-disco-server)


echo '--> Building runtime workspaces...'

mkdir -p /var/lib/scs-example-blog
[[ -e runtime ]] || ln -s /var/lib/scs-example-blog runtime

mkdir -p runtime/scs-base
if [[ ! -d runtime/scs-base/source ]] ; then
  git clone https://github.com/dpb587/scs-base.git runtime/scs-base/source
  docker build -t scs-base runtime/scs-base/source
fi

mkdir -p runtime/mysqlmaster
if [[ ! -d runtime/mysqlmaster/source ]] ; then
  git clone https://github.com/dpb587/scs-mysql.git runtime/mysqlmaster/source
fi

mkdir -p runtime/mysqlslave
if [[ ! -d runtime/mysqlslave/source ]] ; then
  git clone https://github.com/dpb587/scs-mysql-slave.git runtime/mysqlslave/source
fi

mkdir -p runtime/wordpress
if [[ ! -d runtime/wordpress/source ]] ; then
  git clone https://github.com/dpb587/scs-wordpress.git runtime/wordpress/source
fi


echo '--> Starting scs-disco-server...'
cp supervisor/scs-disco-server.ini /etc/supervisor/
supervisorctl update
supervisorctl start scs-disco-server


for SERVICE in $SERVICES ; do
  echo "--> Registering $SERVICE..."
  sed "s/\$PWD/$RPWD/g" supervisor/$SERVICE.ini > /etc/supervisor/$SERVICE.ini
  supervisorctl update

  echo "--> Recompiling $SERVICE..."
  ./bin/handle-service recompile $SERVICE

  echo "--> Building $SERVICE..."
  ./bin/handle-service build $SERVICE

  if supervisorctl status $SERVICE | grep RUNNING > /dev/null 2>&1 ; then
    echo "--> Restarting $SERVICE..."
    supervisorctl restart $SERVICE
  else
    echo "--> Starting $SERVICE..."
    supervisorctl start $SERVICE
  fi
done


echo '--> Waiting for services...'
sleep 30

if [[ -e runtime/mysqlmaster/dependency-volume-_alldata/data/test ]] ; then
  echo '--> Initializing mysqlmaster...'
  expect runtime/mysqlmaster/source/share/mysql-secure-installation.exp \
    $(cat runtime/mysqlmaster/docker.cid) password
fi

if [[ ! -e runtime/mysqlmaster/dependency-volume-_alldata/data/scs_example ]] ; then
  echo '--> Initializing mysqlmaster for wordpress...'
  expect bin/setup-mysqlmaster.exp \
    $(cat runtime/mysqlmaster/docker.cid)
fi

if [[ -e runtime/mysqlslave/dependency-volume-_alldata/data/test ]] ; then
  echo '--> Initializing mysqlslave...'
  expect runtime/mysqlmaster/source/share/mysql-secure-installation.exp \
    $(cat runtime/mysqlslave/docker.cid) password
fi


echo '--> Ready at http://192.168.191.92/wordpress/'
