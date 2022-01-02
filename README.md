# Useful scripts

## docker-update-hosts.sh
This is part of article published: https://www.linkedin.com/pulse/learn-how-access-docker-container-its-name-from-host-renato-rodrigues/?published=t

- [docker-update-hosts.sh](docker-update-hosts.sh): Updates the /etc/hosts file with all running docker services.
It listen the docker start event to add new entries to hosts file, while remove it when the stop event is fired.