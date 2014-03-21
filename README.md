This repo is a demo using the *wip/prototype* [`scs-utils`](https://github.com/dpb587/scs-utils) managing a
[WordPress](http://wordpress.org/) blog with a [MySQL](http://www.mysql.com/) master/slave server across multiple
[Docker](https://www.docker.io/) containers and multiple hosts.

This creates and runs roles based on:

 * [`scs-mysql`](https://github.com/dpb587/scs-mysql) ([settings](https://github.com/dpb587/scs-example-blog/blob/master/mysql-master/manifest.yaml))
 * [`scs-mysql-slave`](https://github.com/dpb587/scs-mysql-slave) ([settings](https://github.com/dpb587/scs-example-blog/blob/master/mysql-slave/manifest.yaml)) - requires local `root`/`password` and master `repl`/`password`
 * [`scs-wordpress`](https://github.com/dpb587/scs-wordpress) ([settings](https://github.com/dpb587/scs-example-blog/blob/master/wordpress/manifest.yaml)) - requires a `scs_example` user and database; installs the [`jetpack`](https://wordpress.org/plugins/jetpack/) plugin, upgraded [`akismet`](https://wordpress.org/plugins/akismet/) plugin, and [`responsive`](https://wordpress.org/themes/responsive) theme

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

Clone this example and use [Vagrant](http://www.vagrantup.com) to start the environment...

    host$ git clone https://github.com/dpb587/scs-example-blog.git
    host$ cd scs-example-blog/
    host$ vagrant up
          ...snip...
          --> Ready at http://192.168.191.92/wordpress/
