This repo is a demo using the *wip/prototype* [`scs-utils`](https://github.com/dpb587/scs-utils) managing a
[WordPress](http://wordpress.org/) blog with a [MySQL](http://www.mysql.com/) master/slave server across multiple
[Docker](https://www.docker.io/) containers and multiple hosts.

This creates and runs roles based on:

 * [`scs-mysql`](https://github.com/dpb587/scs-mysql) ([settings](https://github.com/dpb587/scs-example-blog/blob/master/mysql-master/manifest.yaml))
 * [`scs-mysql-slave`](https://github.com/dpb587/scs-mysql-slave) ([settings](https://github.com/dpb587/scs-example-blog/blob/master/mysql-slave/manifest.yaml)) - requires local `root`/`password` and master `repl`/`password`
 * [`scs-wordpress`](https://github.com/dpb587/scs-wordpress) ([settings](https://github.com/dpb587/scs-example-blog/blob/master/wordpress/manifest.yaml)) - requires a `scs_example` user and database; installs the [`jetpack`](https://wordpress.org/plugins/jetpack/) plugin and [`responsive`](https://wordpress.org/themes/responsive) theme

You'll see all the commands you'll need to run below and the prompt will indicate where you should run them:

 * `host$` - from your local machine
 * `vagrant$`, `vagrant2$` - from your virtual machine (via `vagrant ssh`)
 * `container$` - from inside a container (via `lxc-attach ...`)

I've primarily been running this under the following environment:

    $ uname -rs
    Darwin 13.0.2
    $ vagrant -v
    Vagrant 1.4.3
    $ node -v
    v0.10.22


## Getting Started

Clone this example and the [`scs-utils`](https://github.com/dpb587/scs-utils) repositories...

    git clone https://github.com/dpb587/scs-example-blog.git
    cd scs-example-blog/
    git clone https://github.com/dpb587/scs-utils.git scs-utils/
    cd scs-utils/ && npm install && cd ../

Use [`vagrant`](http://www.vagrantup.com/) and the included [`Vagrantfile`](./Vagrantfile) to start up a virtual machine...

          host$ vagrant up
          host$ vagrant ssh
       vagrant$ sudo -i
       vagrant$ cd /vagrant


## Start the disco server

The `scs-disco-server` handles service registration and discovery. Add it to supervisor and get it started...

       vagrant$ ln -s $PWD/supervisor/scs-disco-server.ini /etc/supervisor/
       vagrant$ supervisorctl update
                scs-disco-server: added process group


## Start the disco client

To simplify things, use `scs-disco-client` to forward local ports to wherever our soon-to-be-running Docker processes
end up. The command specifies that we'll forward port `80` to the `http` endpoint from `wordpress` and port `3306` to
`mysql` from `mysql-master`. It will use `127.0.191.92` for binding ports (aliasing it to `lo0`) and add
`scs-example-blog.dev` to `/etc/hosts`.

Run the following and keep it running in a minimized terminal...

          host$ sudo ./scs-utils/bin/scs-disco-client --log-level silly --disco-server 192.168.191.92 \
                  --forward 80:http:wordpress \
                  --forward 3306:mysql:mysql-master \
                  --ip 127.0.191.92 \
                  --host scs-example-blog.dev
                ...snip...


## MySQL Server (master)

The `mysql-master` role is the database that WordPress will eventually use. The first time we start the container we'll
need to initialize the database and grant permissions to a couple users.

Start by building the image to ensure it completes successfully...

       vagrant$ ( cd mysql-master && scs-docker --log-level silly build ../manifest-vagrant.yaml manifest.yaml )
                ...snip...

Then add it to supervisor and get it started...

       vagrant$ ln -s $PWD/supervisor/mysql-master.ini /etc/supervisor/
       vagrant$ supervisorctl update
                mysql-master: added process group

To initialize MySQL, we'll need to connect to the container to run some local commands...

       vagrant$ lxc-attach -n $(docker ps -notrunc | grep '-mysql-master--' | awk '{ print $1 }') /bin/bash

Run `mysql_secure_installation` and set the `root` password to `password`...

     container$ mysql_secure_installation
              > ...snip...

You'll need to create a database and user that WordPress will use...

     container$ mysql -u root -ppassword
              > CREATE DATABASE scs_example;
              > GRANT ALL PRIVILEGES ON scs_example.* TO scs_example@"%" IDENTIFIED BY "password";
              > FLUSH PRIVILEGES;
              > exit

The `mysql-slave` will also need a replication user later; go ahead and create that now...

     container$ mysql -u root -ppassword
              > GRANT REPLICATION CLIENT, REPLICATION SLAVE, SELECT ON *.* TO repl@"%" IDENTIFIED BY "password";
              > FLUSH PRIVILEGES;
              > exit

We're done with the container now and can exit back to the vagrant shell...

     container$ exit


## WordPress

Build `wordpress` and make sure it finishes cleanly...

       vagrant$ ( cd wordpress && scs-docker --log-level silly build ../manifest-vagrant.yaml manifest.yaml )
                ...snip...

Then add it to supervisor to get it started...

       vagrant$ ln -s $PWD/supervisor/wordpress.ini /etc/supervisor/
       vagrant$ supervisorctl update
                wordpress: added process group

To initialize WordPress, we'll need to run through its install process...

          host$ open http://scs-example-blog.dev/wordpress/wp-admin/install.php


## MySQL Server (slave)

Build `mysql-slave` and make sure it finishes cleanly...

       vagrant$ ( cd mysql-slave && scs-docker --log-level silly build ../manifest-vagrant.yaml manifest.yaml )

Then add it to supervisor to get it started...

       vagrant$ ln -s $PWD/supervisor/mysql-slave.ini /etc/supervisor/
       vagrant$ supervisorctl update
                mysql-slave: added process group

To initialize MySQL, we'll need to connect to the container to run some local commands...

       vagrant$ lxc-attach -n $(docker ps -notrunc | grep '-mysql-slave--' | awk '{ print $1 }') /bin/bash

Run `mysql_secure_installation` and set the `root` password to `password`...

     container$ mysql_secure_installation
              > ...snip...

Within a few seconds of setting the password, the slave should immediately start replicating from the master...

     container$ mysql -u root -ppassword scs_example
              > SELECT comment_date, comment_content FROM wp_comments ORDER BY comment_ID DESC LIMIT 1;
                ...snip...
              > exit

Add a test comment and then re-run the query to verify live replication...

          host$ open 'http://scs-example-blog.dev/wordpress/?p=1#respond'

We're done with the container now and can exit back to the vagrant shell...

     container$ exit


## Service Discovery Updates

Now that everything is running successfully, we can verify that the services follow their dependencies. Restore the
`scs-disco-client` window running on the host to see the registration events come through.

First, let's try restarting the `wordpress` container...

       vagrant$ supervisorctl restart wordpress
                wordpress: stopped
                wordpress: started

The disco client will immediately receive a message telling it that the `wordpress/http` endpoint has gone away. In a
moment it will get another message from the newly started container with the new port it should talk to. You can open
the blog to verify wordpress is back "online"...

          host$ open http://scs-example-blog.dev/wordpress/

A more complicated dependency is `mysql-master` which is required by `wordpress`, `mysql-slave`, and the local disco
client forwarding port `3306`. Try stopping it...

       vagrant$ supervisorctl stop mysql-master
                mysql-master: stopped

While it's offline, the PHP application server in `wordpress` will be offline, the mysql slave tasks in `mysql-slave`
will be stopped, and local `3306` connections will be terminated:

          host$ curl -sI http://scs-example-blog.dev/wordpress/ | head -n1
                HTTP/1.1 502 Bad Gateway
                ...snip...
       vagrant$ lxc-attach -n $(docker ps -notrunc | grep '-mysql-slave--' | awk '{ print $1 }') /scs/scs/bin/status-check \
                  | grep -E 'Running:|Slave_Master_Host:'
                Slave_Master_Host: 192.168.191.92
                Slave_Slave_IO_Running: No
                Slave_Slave_SQL_Running: No
          host$ telnet scs-example-blog.dev mysql
                Connected to scs-example-blog.dev.
                Escape character is '^]'.
                Connection closed by foreign host.

Bring `mysql-master` back online...

       vagrant$ supervisorctl start mysql-master

Then verify things are back online...

          host$ curl -sI http://scs-example-blog.dev/wordpress/ | head -n1
                HTTP/1.1 200 OK
                ...snip...
       vagrant$ lxc-attach -n $(docker ps -notrunc | grep '-mysql-slave--' | awk '{ print $1 }') /scs/scs/bin/status-check \
                  | grep -E 'Running:|Slave_Master_Host:'
                Slave_Master_Host: 192.168.191.92
                Slave_Slave_IO_Running: Yes
                Slave_Slave_SQL_Running: Yes


## Distributed Service Discovery

Right now all the services are running on a single virtual machine. Let's move `mysql-master` to a new virtual machine.
Create a second clone of this repository, and patch `Vagrantfile` with a different IP address...

          host$ git clone file://$PWD /tmp/scs-example-blog-vagrant2
          host$ cd /tmp/scs-example-blog-vagrant2
          host$ sed -i '' 's/192.168.191.92/192.168.191.93/' Vagrantfile
          host$ vagrant up
          host$ vagrant ssh
      vagrant2$ sudo -i
      vagrant2$ cd /vagrant

Stop `mysql-master` on `vagrant`...

       vagrant$ supervisorctl stop mysql-master
                mysql-master: stopped

Now let's copy over the existing database to the new instance...

       vagrant$ mkdir -p ~/.ssh
       vagrant$ wget -qO ~/.ssh/vagrant https://raw2.github.com/mitchellh/vagrant/master/keys/vagrant
       vagrant$ chmod 600 ~/.ssh/vagrant
       vagrant$ pushd /var/lib/scs-utils
       vagrant$ tar -czf- volume--local--default-default-mysql-master-* \
                  | ssh -i ~/.ssh/vagrant vagrant@192.168.191.93 \
                    'sudo bash -c "mkdir -p /var/lib/scs-utils && cd /var/lib/scs-utils && chmod 700 . && tar -xzf-"'
       vagrant$ popd

Now we should start `mysql-master` on `vagrant2` (it will take a few minutes because it needs to recompile and rebuild
the image from scratch)...

      vagrant2$ ln -s $PWD/supervisor/mysql-master.ini /etc/supervisor/
      vagrant2$ supervisorctl update
                mysql-master: added process group
      vagrant2$ tail -f /var/log/supervisor/mysql-master-std*
                ...snip...

Once built, it will run and register with the disco server on `192.168.191.92`. The `wordpress`, `mysql-slave`, and
local disco client will automatically start talking to `mysql-master` on `vagrant2`. You can check that the services are
back up...

          host$ curl -sI http://scs-example-blog.dev/wordpress/ | head -n1
                HTTP/1.1 200 OK
                ...snip...
       vagrant$ lxc-attach -n $(docker ps -notrunc | grep '-mysql-slave--' | awk '{ print $1 }') /scs/scs/bin/status-check \
                  | grep -E 'Running:|Slave_Master_Host:'
                Slave_Master_Host: 192.168.191.93
                Slave_Slave_IO_Running: Yes
                Slave_Slave_SQL_Running: Yes
