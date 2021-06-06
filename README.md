# freebsd-storj-storagenode
Setup and Helper scripts for running Storj Storage Nodes on FreeBSD

**update-storagenode.sh**

Will ensure `$HOME/bin/storagenode` exists and that `$HOME/bin/storagenode-latest` will be a link to the latest suggested version as defined by [https://version.storj.io](https://version.storj.io)

package requirements:
* curl
* jq
* unzip (should already be installed on FreeBSD)

Usage:
* Run manually to fetch the current storagenode binary to allow initial config
  `./update-storagenode.sh -v`
* As a cron job to peridically update
  `0 0/6 * * * /home/storj/update-storagenode.sh`


**restart-storagenode-on-update.sh**

Script to check if `$HOME/bin/storagenode` and `$HOME/bin/storagenode-latest`
differ if so, stop the supervisor storagenode service, copy
`$HOME/bin/storagenode-latest` to `$HOME/bin/storagenode` and restart the
service if it was originally running.

package requirements:
* sudo
* py37-supervisor

Usage:
* Run manually to update the storagenode binary
  `./restart-storagenode-on-update.sh -v`
* As a cron job to automatically pick up updates
  `0 1/6 * * * /home/storj/restart-storagenode-on-update.sh`


**usr/local/etc/logrotate.d/storagenode**

An example logrotate configuration to rotate the storagenode logs.  You will
need to install the logrotate package itself and customise the configuration
to match your installation.  Check `man 8 logrotate` for more information.


**usr/local/etc/supervisor/conf,d/storagenode.conf**

An example supervisor service configuration to ensure storagenode is restarted
on boot and restarted if any errors occur.
Check [http://supervisord.org/](http://supervisord.org/) for more information.
