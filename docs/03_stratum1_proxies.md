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
For the Stratum 1 you need the same packages to be installed as with a Stratum 0:
```bash
sudo yum install -y https://ecsft.cern.ch/dist/cvmfs/cvmfs-release/cvmfs-release-latest.noarch.rpm
sudo yum install -y epel-release
sudo yum install -y cvmfs cvmfs-server
```

### Start Apache and Squid

### DNS cache?

### Register the Stratum 1

### Make the first snapshot

### Make a snapshot cronjob


## Set up a proxy

## Client configuration

## Homework
