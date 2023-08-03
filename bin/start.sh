#!/bin/sh
cat skynet.pid | while read line
do
    echo $line
    if [[ $line != "" ]] && [ "$line" -ge 10 ]; then
        kill -2 $line
        while kill -0 "$line" 2>/dev/null; do
                sleep 0.1
        done
    else
        echo "no skynet process"
    fi;
done

echo $1

if [[ $1 == "true" ]]; then

    export DAEMON=true
else
    export DAEMON=false
fi;


skynet/skynet etc/config.test