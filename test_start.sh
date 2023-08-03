#!/bin/bash
cat skynet_test.pid | while read line
do
    echo $line
    if [[ $line != "" ]] && [[ $line != "1" ]]; then
        kill -2 $line
        while kill -0 "$line" 2>/dev/null; do
                sleep 0.1
        done
    else
        echo "no skynet process"
    fi;
done

export DAEMON=false

echo $ROOT

skynet/skynet etc/ws_skynet_test_config
