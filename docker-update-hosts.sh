#!/bin/bash

#============================================================================================
#   FILE:           docker-update-hosts.sh
#   USAGE:          ./docker-update-hosts.sh --hosts /etc/hosts --verbose
#   DESCRIPTION:    Updates the /etc/hosts file with all running docker services. It listen
#                   the docker start event to add new entries to hosts file, while remove it
#                   when the stop event is fired.
#
#   AUTHOR:         Renato Rodrigues, spamcares-github@yahoo.com
#   VERSION:        1.0
#============================================================================================

# shows the script usage
function usage() {
    # shows the error
    if [ -n "$1" ]; then
        echo -e "[WARN][$(date +"%Y-%m-%d %T")] ${RED}👉 $1${CLEAR}\n";
    fi

    # prints the usage
    echo "Usage: $0 [-h|--host] [-v|--verbose] [-q|quiet]"
    echo "  -h, --hosts              hosts file path"
    echo "  -v, --verbose            verbose output"
    echo "  -q, --quiet              executes quietelly without any changes and prints the result"
    echo ""
    echo "Eg.:    $0 --hosts /etc/hosts --verbose"
    echo "        $0 -h /etc/hosts -q -v"
    exit 1
}

# process start/stop Docker events
function processEvent() {
    
    local timestamp=$1      # event timestamp
    local event_type=$3     # event type
    local container_id=$4   # container id

    verbose "Event Timestamp: $timestamp    Event Type: $event_type     Container Id: $container_id"
    
    # creates the key with 8 char from container id
    local key="ID$( echo $container_id | cut -c1-8)"

    # process start event
    if [ $event_type = "start" ]; then

        # inspect the container and extract the service name
        local service_name=`docker inspect --format '{{ .Name }}' $container_id `
        local ip_only=`docker inspect --format '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $container_id `
        local ip_addr=`docker inspect --format '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{"\t"}}{{index .Aliases 1}}{{end}}' $container_id `

        verbose "Service key: $key  Service Name: $service_name ip: $ip_addr"
        # check if the service key not exists
        if ! [ ${services["$key"]+_} ] && ! [ -z "$ip_only" ]; then
            # adds the service name in the map
            services+=(["$key"]=${service_name:1} )
            
            if [ $QUIET = "0" ]; then

                # grep the inverted match (line) and save to the temp file
                grep -v ${services["$key"]} $processfile > $tmpfile
                
                # append the IP_ADDRESS and service name to $HOSTS
                echo ${ip_addr} ${services["$key"]}  >> $tmpfile

                # override the original file
                mv $tmpfile $processfile
            fi

            echo "[INFO][$(date +"%Y-%m-%d %T")] Appended line in the file '${processfile}':    ${ip_addr}   ${services["$key"]}"
        fi
    fi

    # process start event
    if [ $event_type = "stop" ]; then
        
        # check if the service key exists
        if [ ${services["$key"]+_} ]; then

            if [ $QUIET = "0" ]; then
                # grep the inverted match (line) and save to the temp file
                grep -v ${services["$key"]} $processfile > $tmpfile

                # override the original file
                mv $tmpfile $processfile
            fi
            
            echo "[INFO][$(date +"%Y-%m-%d %T")] Removed line from the file '${processfile}':  ${services["$key"]}"

            #removes the key from map
            unset services["$key"]
        fi
    fi
}

# verbose output
function verbose () {
    if [[ $VERBOSE -eq 1 ]]; then
        echo "[DEBUG][$(date +"%Y-%m-%d %T")] $@"
    fi
}

HOSTS=/etc/hosts
QUIET="0"
# parse params
while [[ "$#" > 0 ]]; do case $1 in
  -h|--hosts) HOSTS="$2";shift;shift;;
  -v|--verbose) VERBOSE=1;shift;;
  -q|--quiet) QUIET="1";shift;;
  *) usage "[ERROR][$(date +"%Y-%m-%d %T")] Unknown parameter: $1"; shift; shift;;
esac; done

# validate input parameters
if [ -z "$HOSTS" ];         then usage "[ERROR][$(date +"%Y-%m-%d %T")] Hosts file path not set.";  fi;

# formating colors
declare CLEAR='\033[0m'
declare RED='\033[0;31m'

declare processfile=${HOSTS}            # file to be processed (hosts file)
declare tmpfile=${processfile}.tmp      # create a temp file for processing
declare -A services                     # map of services (docker service name). Eg. services[key]=value

verbose "Processing file: $processfile  Temp file: $tmpfile     Quiet Mode: ${QUIET}"

# lookup the docker start/stop events
docker events --filter 'event=start' --filter 'event=stop' | while read event
do
    # process Docker event
    processEvent $event
done;
