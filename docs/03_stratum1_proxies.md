# Stratum 1 and proxies

- short summary previous session
- Stratum-1
- proxy
- hands-on homework

In the previous section we have set up a Stratum 0 server and a client that directly connects to the Stratum 0.
Although this worked fine, this setup is neither scalable, nor very reliable, nor secure: it is a single point of failure,
too open in terms of connectivity, and it will have to serve all possible clients on its own.

Therefore, this section will show how all these points can be addressed by adding one or more Stratum 1 servers and caching proxy servers. A Stratum 1 is a replica server that keeps mirrors of the repositories served by a Stratum 0.
It is basically a web server that periodically synchronizes the contents of the repositories,
and, in contrast to a Stratum 0 server, you can have multiple Stratum 1 servers.
It is recommended to have several ones that are geographically distributed, so that clients always have a nearby Stratum 1 server.
How many you need mostly depends on the distribution and number of clients, but often a few is already sufficient. More scalability can be added with proxies, which we will discuss later in this section.

INSERT IMAGE OF CVMFS INFRA HERE

## Set up a Stratum 1 server


### Requirements
A Stratum 1 servers has similar requirements as a Stratum 1. In addition to port 80, also port 8000 has to be accessible for a Stratum 1. Furthermore, you need a (free) license key for [Maxmind's Geo API](https://dev.maxmind.com/geoip/geoip2/geolite2/), which you can obtain by [signing up for an account](https://www.maxmind.com/en/geolite2/signup/).

### Installation
For the Stratum 1 you need to install the following packages:
```bash
sudo yum install -y https://ecsft.cern.ch/dist/cvmfs/cvmfs-release/cvmfs-release-latest.noarch.rpm
sudo yum install -y epel-release
sudo yum install -y cvmfs-server
sudo yum install -y mod_wsgi
sudo yum install -y squid
```

### Apache and Squid
```
port 8080 locally? -> Listen 127.0.0.1:8080
sudo systemctl enable httpd
sudo systemctl start httpd
```

```
/etc/squid/squid.conf:

http_port 80 accel
http_port 8000 accel
http_access allow all
cache_peer localhost parent 8080 0 no-query originserver

acl CVMFSAPI urlpath_regex ^/cvmfs/[^/]*/api/
cache deny !CVMFSAPI

cache_mem 256 MB


ulimit -n 8192 ?
start squid
```

### DNS cache?
Skip this for now and point to the documentation?

### Register the Stratum 1
```
echo 'CVMFS_GEO_LICENSE_KEY=YOUR_KEY' >> /etc/cvmfs/server.local
chmod 600 /etc/cvmfs/server.local

```

### Make the first snapshot
```
cvmfs_server snapshot repo.organization.tld
```

### Make cronjobs
```
/etc/logrotate.d/cvmfs does not exist!
To prevent this error message, create the file or use -n option.
Suggested content:
/var/log/cvmfs/*.log {
    weekly
    missingok
    notifempty
}

$ cat /etc/cron.d/cvmfs_stratum1_snapshot
*/5 * * * * root output=$(/usr/bin/cvmfs_server snapshot -a -i 2>&1) || echo "$output"

$ cat /etc/cron.d/cvmfs_geoip_db_update
4 2 2 * * root /usr/bin/cvmfs_server update-geodb
```

## Set up a proxy

## Client configuration

## Homework
