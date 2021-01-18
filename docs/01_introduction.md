# Introduction to CernVM-FS

## What is CernVM-FS?

Let's get started with explaining in detail what CernVM-FS is...

!!! note "CernVM-FS in a nutshell"

    *The CernVM File System (CernVM-FS) provides a scalable and reliable software distribution service,
    which is implemented as a read-only POSIX filesystem in user space (a FUSE module).*

    *Files and directories are hosted on standard web servers and mounted in the universal namespace* ``/cvmfs``.

That's a mouthful, so let's break it down a bit...


#### Read-only filesystem over HTTP

CernVM-FS is a ***network filesystem***,
which you can mount in Linux or macOS via [FUSE (Filesystem in Userspace)](https://github.com/libfuse/libfuse).
In some ways it is similar to other network filesystems like [NFS](https://en.wikipedia.org/wiki/Network_File_System)
or [AFS](https://en.wikipedia.org/wiki/Andrew_File_System),
but there are various aspects to it that are quite different.

The files and directories that are made available via CernVM-FS are always located
in a subdirectory of ``/cvmfs``, and are provisioned via a network of servers that
can basically by viewed as web servers since only outgoing ***HTTP*** connections are used.
This makes it easy to use CernVM-FS in environments that are protected by a strict firewall.

CernVM-FS is a ***read-only*** filesystem for those who access it; only those who administer it
are able to add or change its contents.

Internally, CernVM-FS uses content-addressable storage and Merkle trees in order to maintain file data and meta-data,
but the filesystem it exposes is a standard [POSIX filesystem](https://en.wikipedia.org/wiki/POSIX).


#### Software distribution system

The primary use case of CernVM-FS is to easily ***distribute software*** around the world,
which is reflected in various ways in the features implemented by CernVM-FS.

It's worth highlighting that with *software* we actually mean ***software installations***,
that is the files that collectively form a usable instance of an application, tool, or library.
This is in contrast with software *packages* (for example, RPMs), which are essentially bundles of files wrapped
together for easy distribution, and which need to be *installed* in order to provide a working instance of the
provided software.

Software installations have specific characteristics, such as often
involving lots of small files which are being opened and read as a whole regularly,
frequent searching for files in multiple directories, hierarchical structuring, etc.
CernVM-FS is heavily tuned to cater to this use case, with aggressive caching and reduction of latency,
for example via automatic file de-duplication and compression.


#### Scalable and reliable

CernVM-FS was designed to be ***scalable and reliable***, with known deployments involving hundreds of millions
of files and many thousands of clients. It was originally created to fulfill the software distribution needs of the
[Large Hadron Collider (LHC) project at CERN](https://home.cern/science/accelerators/large-hadron-collider).

The network of (web) servers that make a CernVM-FS instance accessible is constructed such that it is robust
against problems like network disconnects and hardware failures, and so it can be extended and tweaked on demand
for optimal performance.


More details are available in the [CernVM-FS documentation](https://cvmfs.readthedocs.io/en/stable/cpt-overview.html).

## Terminology

Before we get our hands dirty, let's cover some of the terminology used by the CernVM-FS project.

The figure included below shows the different components of the CernVM-FS network:

* the central *Stratum 0* server which hosts the filesystem;
* the *Stratum 1* replica servers, and the associated *proxies*;
* the *client* accessing the filesystem provided via CernVM-FS.

<p align="center">
<img src="../img/cvmfs_network.png" alt="CernVM-FS network" width="700px"/>
</p>

#### Clients

A ***client*** in the context of CernVM-FS is any system that mounts the filesystem.
This includes laptops or personal workstations who need access to the provided software installations,
but also High-Performance Computing (HPC) clusters, virtual machines running in a cloud environment, etc.

Clients only have *read-only* access to the files included in a CernVM-FS repository,
and are automatically notified when the contents of the filesystem has changed.

The filesystem that is mounted on a client (under ``/cvmfs``) is a virtual filesystem, in the sense that
*data is only (down)loaded when it is actually accessed* (and cached aggressively to ensure good performance).

Mounting a CernVM-FS repository on a client will be covered in [first hands-on part of this tutorial](02_getting_started.md).
Extensive documentation on configuring a client is available in the [CernVM-FS documentation](https://cvmfs.readthedocs.io/en/stable/cpt-configure.html).

#### Stratum 0 + repository

A CernVM-FS ***repository*** is the single source of (new) data for a filesystem.
This single source is also called the ***Stratum 0***, which can be viewed as the central server
the CernVM-FS network. Multiple repositories can be hosted on a single Stratum 0 server.

A repository is a form of content-addressable storage, which is maintained by a dedicated release manager machine or *publisher*.
All data stored into CernVM-FS has to be converted into a repository during the process of *publishing*,
which involves creating the file catalog(s), compressing files, calculating content hashes, etc.

A read-writable copy of a CernVM-FS repository is (only) available on a *publisher* system, which can be the same system
as the Stratum 0 server. Providing write access is done by means of a *union filesystem*, which involves
overlaying a read-only mount of the CernVM-FS filesystem with a writable scratch area.
Publishing is an atomic operation: adding or changing files in a repository is done by
*ingesting* files and creating a *transaction* that records the changes.

In the [first hands-on part of this tutorial](02_getting_started.md)
we will guide you through the process of creating a CernVM-FS repository,
which is also covered in detail in the [CernVM-FS documentation](https://cvmfs.readthedocs.io/en/stable/cpt-repo.html).

The [3rd hands-on part of this tutorial](04_publishing.md) will focus on the publishing procedure
to update the contents of a CernVM-FS repository.

#### Stratum 1 replica servers

A ***Stratum 1 replica server*** is a *standard web server* that provides a ***read-only mirror***
of a CernVM-FS repository served by a Stratum 0.

The main purpose of a Stratum 1 is to improve reliability of the CernVM-FS network, by reducing the load on the Stratum 0.
There usually are multiple Stratum 1 servers in a CernVM-FS network, which are typically distributed globally.
Although clients can access a CernVM-FS repository directly via the Stratum 0, this is better done via the Stratum 1
replica servers.

Stratum 1 servers enable clients to determine which Stratum 1 is geographically closest to connect to,
via the Geo API which uses a [GeoIP database](https://dev.maxmind.com/geoip/geoip2/geolite2/) that
translates IP addresses of clients to longitude and latitude.

Setting up a Stratum 1 replica server will be covered in the [second hands-on part of this tutorial](03_stratum1_proxies.md),
and is also covered in detail in the [CernVM-FS documentation](https://cvmfs.readthedocs.io/en/stable/cpt-replica.html).


#### Squid proxies

To reduce load on Stratum 1 servers and to help reduce latency on clients, it is recommended to set up a
[Squid forward proxy servers](http://www.squid-cache.org/).
A Squid proxy caches content that has been accessed recently, and helps to reduce bandwidth and improve response times.

This is particularly important on large systems like HPC clusters where many workernodes are accessing the
CernVM-FS repository, where it's recommended to set up multiple Squid proxies.

The [second hands-on part of this tutorial](03_stratum1_proxies.md) will also cover setting up a Squid proxy.
More details are available in the [CernVM-FS documentation](https://cvmfs.readthedocs.io/en/stable/cpt-squid.html).
