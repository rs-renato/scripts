#!/opt/homebrew/bin/bash

# Usage: sudo ./docker-update-hos.sh /etc/hosts


# Retrieve the argument and create a name for a tmp file
#
declare processfile=$1
declare tmpfile=${1}.tmp
declare -A services

event () {
    
    local timestamp=$1
    local event_type=$3
    local container_id=$4
    
    local key="ID$( echo $container_id | cut -c1-8)"

    if [ $event_type = "start" ];
    then
        local servicename=`docker inspect --format '{{ .Name }}' $container_id `
        local ipaddress=`docker inspect --format '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $container_id`

        if ! [ ${services["$key"]+_} ]; then
            services+=(["$key"]=${servicename:1} )
            echo "inserting entry 127.0.0.1 ${services["$key"]}"
            grep -v ${services["$key"]} $processfile > $tmpfile
            echo '127.0.0.1' ${services["$key"]}  >> $tmpfile
            mv $tmpfile $processfile
        fi
    fi

    if [ $event_type = "stop" ];
    then
        if [ ${services["$key"]+_} ]; then
            echo "stoping service: ${services["$key"]}"
            grep -v ${services["$key"]} $processfile > $tmpfile
            unset services["$key"]
            mv $tmpfile $processfile
        fi
    fi
}

docker events --filter 'event=start' --filter 'event=stop' | while read event
do
    event $event
done;