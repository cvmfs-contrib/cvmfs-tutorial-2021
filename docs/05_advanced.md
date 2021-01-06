# Advanced topics

- gateway-publisher (with warnings)
	- installing these takes time
	- prepared: 1 gateway + 2 publishers
	- demo only (no hands-on)
- exploding containers + use via Singularity
	- demo


## Gateway and Publishers

Only being able to modify your repository on the Stratum 0 server can be a bit of a limitation,
especially when multiple people have to maintain the repository.

A quite new feature in CernVM-FS allows you to set up so-called publisher machines, which are separate machines
that are allowed to modify the repository. It also allows for setting up simple ACLs to give certain machines only access to subtrees of the repository.

In order to use this feature you also need a gateway machine that has the repository storage mounted; the easiest way to set it up is by having a single machine that serves as both the
Stratum 0 and the gateway. This is the setup that we will explain here.

Do note that this is a fairly new feature and is not used a lot by production sites yet.
Therefore, use it at your own risk!

### Gateway

#### Requirements
This machine has the same requirements as a standard Stratum 0 server, except that it also needs
an additional port for the gateway service. This port is configurable, but by default port 4929 is used.

#### Installation
Perform the installation steps for the Stratum 0, which can be found in an earlier section.
Additionally, install the `cvmfs-gateway` package:
```
sudo yum install -y cvmfs-gateway
```

Now make your repository using:
```
sudo cvmfs_server mkfs -o $USER repo.organization.tld
```

#### Configuration

The gateway requires you to set up a configuration file `/etc/cvmfs/gateway/repo.json`.
This is a JSON file containing the name of the repository, the keys that can be used by publishers to get
access to the repository, and the (sub)path that these publishers are allowed to publish to.

The `cvmfs-gateway` package will make an example file for you, which you can edit or overwrite.
It should look like this:
```
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
an acquired lease. Assuming you do not have to change the port, you can leave it as it is for now.

#### Starting the service

We can now start the gateway service using:
```
systemctl start cvmfs-gateway
```

Do note that, once this service is running, you should not open transactions on this machine anymore, or you
may corrupt the repository. If you do want to open a transaction, stop the gateway service first.

### Publisher

#### Requirements
This machine has no special requirements.

#### Installation
The publisher only needs the `cvmfs-server` package to be installed:
```
sudo yum install -y https://ecsft.cern.ch/dist/cvmfs/cvmfs-release/cvmfs-release-latest.noarch.rpm
sudo yum install -y cvmfs-server
```

#### Configuration
The publisher machine only needs three files with keys:

 - the repository's public key: `repo.organization.tld.pub`;
 - the repository's public key encoded as X509 certificate: `repo.organization.tld.crt`;
 - the gateway API key stored in a file named `repo.organization.tld.gw`.

The first two files can be taken from `/etc/cvmfs/keys` on your Stratum 0 server.
The latter can be created manually and should just contain the secret that you used in the gateway configuration.

Place all these files in some (temporary) directory on your publisher machine.

#### Make the repository
We can now make the repository available for writing on our publisher machine by running:
```
sudo cvmfs_server mkfs -w http://YOUR_STRATUM0_GATEWAY/cvmfs/repo.organization.tld \
                       -u gw,/srv/cvmfs/repo.organization.tld/data/txn,http://YOUR_STRATUM0_GATEWAY:4929/api/v1 \
                       -k /path/to/keys/dir -o `whoami` repo.organization.tld
```
Replace both occurrences of `YOUR_STRATUM0_GATEWAY` by the IP address or hostname of your gateway / Stratum 0 server (and change 4929 in case you changed the gateway port), and `/path/to/keys/dir` by the path where you
stored the keys in the previous step.

#### Start publishing!
You should now be able to make changes to the repository by opening a transaction. Note that you can do it
as the regular user:
```
cvmfs_server transaction repo.organization.tld

# MAKE CHANGES TO /cvmfs/repo.organization.tld

cvmfs_server publish repo.organization.tld
```
