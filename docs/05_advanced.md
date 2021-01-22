# 5. Advanced topics

## 5.1 Automatic deployment of CernVM-FS servers and clients

As you may have experienced during this tutorial, it takes quite a bit of manual effort to deploy all the different CernVM-FS components, and you can easily make mistakes.
Therefore, we strongly recommend to automate this in a production setup with a tool like [Ansible](https://www.ansible.com/) or [Puppet](https://puppet.com/).

For Ansible, you could take a look at [the playbooks of the EESSI project](https://github.com/EESSI/filesystem-layer), which use [the Ansible role from the Galaxy Project](https://github.com/galaxyproject/ansible-cvmfs) to install and configure both servers and clients.
Compute Canada also offers [an Ansible role](https://git.computecanada.ca/cc-cvmfs-public/ansible-cvmfs-client) to configure CernVM-FS clients.

CERN offers [its own Puppet module](https://github.com/cvmfs/puppet-cvmfs) that allows you to install and configure CernVM-FS servers and clients.


## 5.2 Debugging issues

If you are experiencing issues with your CernVM-FS setup, there are various ways to start debugging.
Most issues are caused by wrongly configured clients (either a configuration issue, or a wrong public key)
and connection or firewall issues.

### 5.2.1 Debugging with `cvmfs_config`

In order to find the cause of the issue, you should first find out *where* the issue is being caused.
You can start by checking the client configuration for syntax errors:

```bash
sudo cvmfs_config chksetup
```

This should print `OK`.

To make sure that your configuration is really picked up and set correctly
(because of the hierarchical structure of the configuration,
it is possible that some parameter gets overwritten by another configuration file),
you can dump the effective configuration for your repository:

```bash
cvmfs_config showconfig repo.organization.tld
```

Make sure that at least `CVMFS_HTTP_PROXY` and `CVMFS_SERVER_URL` are set correctly, and that the directory pointed to by `CVMFS_KEYS_DIR` really contains the (correct) public key file.

The `probe` subcommand can be used for (re)trying to mount the repository, and should print `OK`:
```
$ cvmfs_config probe repo.organization.tld
Probing /cvmfs/repo.organization.tld... OK
```

However, since you are debugging a problem, it probably returns an error...

So, let's enable some debugging output by adding the following line to your `/etc/cvmfs/default.local`:
```
CVMFS_DEBUGLOG=/path/to/cvmfs.log
```
Now we unmount the repository, re-run the setup step, and try to probe it again:

```
sudo cvmfs_config umount
sudo cvmfs_config setup
cvmfs_config probe repo.organization.tld
```

You can now check your debug log file, and look for any error messages near the bottom of the file; they may reveal more details about the issue.


### 5.2.2 Debugging connection issues

If the problem turns out to be some kind of connection issue, you can trace it down further
by manually checking the connections from your client to the proxy and/or Stratum 1 server.

First, let's rule out that it is some kind of firewall issue by verifying that you can actually
connect to the appropriate ports on those servers:

```bash
telnet <PROXY_IP> 3128
telnet <STRATUM1_IP> 80
```

If this does work, probably something is wrong with the services running on these machines.

Every CernVM-FS repository has a file named `.cvmfspublished`, and you can try to fetch it manually
using `curl`, both directly from the Stratum 1 and via your proxy:

```bash
# Without your own proxy, so directly to the Stratum 1:
curl --head http://<STRATUM1_IP>/cvmfs/repo.organization.tld/.cvmfspublished
```

```bash
# With your caching proxy between the client and Stratum 1:
curl --proxy http://<PROXY_IP>:3128 --head http://url-to-your-stratum1/cvmfs/repo.organization.tld/.cvmfspublished
```

These commands should return `HTTP/1.1 200 OK`. If the first command returns something else, you should inspect your CernVM-FS, Apache, and Squid configuration (and log) files on the Stratum 1 server. If the first `curl` command does work, but the second does not, there is something wrong with your Squid proxy; make sure that it is running, configured, and able to access your Stratum 1 server.

## 5.3 Garbage collection

As mentioned in [the section about publishing](04_publishing.md), the default configuration of a Stratum 0 enables automatic tagging,
which automatically assigns a timestamped tag to each published transaction.
However, by default, these automatically generated tags will not be removed automatically.
As a result, files that you remove in later transactions will still take up space in your repository...

### 5.3.1 Setting the lifetime of automatically generated tags

Instead of removing tags manually, you can automatically mark these automatically generated tags for
removal after a certain period by setting the following variable
in the file `/etc/cvmfs/repositories.d/repo.organization.tld/server.conf` on your Stratum 0:
```
CVMFS_AUTO_TAG_TIMESPAN="30 days ago"
```
This should be a string that can be parsed by the `date` command, and defines the lifetime of the tags.

### 5.3.2 Cleaning up tags marked for removal

In order to actually *clean up* unreferenced data, garbage collection has to be enabled for
the repository by adding `CVMFS_GARBAGE_COLLECTION=true` in the `server.conf` configuration file on Stratum 0.

The garbage collector of the CernVM-FS server can then be run using:

```bash
sudo cvmfs_server gc repo.organization.tld
```

The `gc` subcommand has several options; a useful way to run it,
especially if you want to do this with a cron job, is:

```bash
sudo cvmfs_server gc -a -l -f
```

The `-a` option will automatically run the garbage collection for all your repositories that have garbage collection enabled and log to `/var/log/cvmfs/gc.log`;
the `-l` option will make the command print which objects are actually removed;
and the `-f` option will not prompt for confirmation.

Note that you cannot run the garbage collection while a publish operation is ongoing.

## 5.4 Gateway and Publishers

Only being able to modify your repository on the Stratum 0 server can be a bit limiting,
especially when multiple people have to maintain the repository.

A very recent feature of CernVM-FS allows you to set up so-called *publisher machines*,
which are separate systems that are allowed to modify the repository.
It also allows for setting up simple ACLs to let a system only access specific subtrees of the repository.

In order to use this feature you also need a *gateway machine* that has the repository storage mounted.
The easiest way to set it up is by having a single system that serves as both the
Stratum 0 and the gateway. This is the setup that we will explain here.

Do note that this is a fairly new feature and is not used a lot by production sites yet.
Therefore, use it at your own risk!

### 5.4.1 Gateway

#### Requirements

The gateway system has the same requirements as a standard Stratum 0 server, except that it also needs
an additional port for the gateway service. This port is configurable, but by default port 4929 is used.

#### Installation

Perform the installation steps for the Stratum 0, which can be found in an
[earlier section](02_stratum0_client.md#212-installing-cernvm-fs).
Additionally, install the `cvmfs-gateway` package:

```bash
sudo yum install -y cvmfs-gateway
```

Then create the repository [just like we did on Stratum 0](02_stratum0_client.md#214-creating-the-repository):

```bash
sudo cvmfs_server mkfs -o $USER repo.organization.tld
```

#### Configuration

The gateway requires you to set up a configuration file `/etc/cvmfs/gateway/repo.json`.
This is a JSON file containing the name of the repository, the keys that can be used by publishers to get
access to the repository, and the (sub)path that these publishers are allowed to publish to.

The `cvmfs-gateway` package will make an example file for you, which you can edit or overwrite.
It should look like this:

```json
{
    "version": 2,
    "repos" : [
        {
            "domain" : "repo.organization.tld",
            "keys" : [
                {
                    "id": "keyid1",
                    "path": "/"
                },
                {
                    "id": "keyid2",
                    "path": "/restricted/to/subdir"
                }
            ]
        }
    ],
    "keys" : [
        {
            "type" : "plain_text",
            "id" : "keyid1",
            "secret" : "SOME_SECRET"
        },
        {
            "type" : "plain_text",
            "id" : "keyid2",
            "secret" : "SOME_OTHER_SECRET"
        },
    ]
}
```

You can choose the key IDs and secrets yourself; the secret has to be given to the owner of the
corresponding publisher machine.

Finally, there is a second configuration file `/etc/cvmfs/gateway/user.json`.
This is where you can, for instance, change the port of the gateway service and the maximum length of
an acquired lease. Assuming you do not have to change the port, you can leave it as it is.

#### Starting the service

To start the gateway service, use:

```bash
systemctl start cvmfs-gateway
```

Note that once this service is running you should *not* open transactions on this Stratum 0 server anymore,
or you may corrupt the repository. If you do want to open a transaction, stop the gateway service first!

### 5.4.2 Publisher

#### Requirements

There a no special requirements for a publisher system with respect to resources.

#### Installation

The publisher only needs to have the `cvmfs-server` package installed:
```
sudo yum install -y https://ecsft.cern.ch/dist/cvmfs/cvmfs-release/cvmfs-release-latest.noarch.rpm
sudo yum install -y cvmfs-server
```

#### Configuration

The publisher machine only needs three files with keys:

 - the repository's public master key: `repo.organization.tld.pub`;
 - the repository's public key encoded as X509 certificate: `repo.organization.tld.crt`;
 - the gateway API key stored in a file named `repo.organization.tld.gw`.

The first two files can be taken from `/etc/cvmfs/keys` on your Stratum 0 server.
The latter can be created manually and should just contain the secret that was used in the gateway configuration.

All these files should be placed in some (temporary) directory on the publisher system.

#### Creating the repository

We can now create the repository available for writing on our publisher machine by running:

```bash
export S0_IP='<STRATUM0_IP>'
sudo cvmfs_server mkfs -w http://$S0_IP/cvmfs/repo.organization.tld \
                       -u gw,/srv/cvmfs/repo.organization.tld/data/txn,http://$S0_IP:4929/api/v1 \
                       -k /path/to/keys/dir -o $USER repo.organization.tld
```
Replace `<STRATUM0_IP>` with the IP address (or hostname) of your gateway / Stratum 0 server
(and change 4929 in case you changed the gateway port), and `/path/to/keys/dir` by the path where you
stored the keys in the previous step.

#### Start publishing!

You should now be able to make changes to the repository by starting a transaction:
```bash
cvmfs_server transaction repo.organization.tld
```

making some changes to the repository at `/cvmfs/repo.organization.tld`, and then publishing the changes:

```bash
cvmfs_server publish repo.organization.tld
```
