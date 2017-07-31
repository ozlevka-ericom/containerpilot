#!/bin/bash
# test_tasks: runs multiple tasks with timeouts for a period of time and
# then parses their logs to verify that they ran the expected number of times.

# start up consul and wait for leader election
docker-compose up -d consul
docker exec -it "$(docker-compose ps -q consul)" assert ready

docker-compose up -d app
APP_ID="$(docker-compose ps -q app)"

sleep 3.5
docker-compose stop app

docker logs "${APP_ID}" > "${APP_ID}.log"
docker cp "${APP_ID}:/task1.txt" "${APP_ID}.task1"
docker cp "${APP_ID}:/task2.txt" "${APP_ID}.task2"
docker cp "${APP_ID}:/task3.txt" "${APP_ID}.task3"

PASS=0

check() {
    local taskname=$1
    local expect_runs=$2
    local expect_timeouts=$3
    local timeouts=$(grep -c "$taskname timeout" "$APP_ID.log")
    local runs=$(wc -l < "$APP_ID.$taskname" | tr -d '[:space:]')
    rm "$APP_ID.$taskname"

    if [[ "$runs" -ne "$expect_runs" ]]; then
        echo "expected $taskname to have $expect_runs executions: got $runs"
        PASS=1
    fi
    if [[ "$timeouts" -ne "$expect_timeouts" ]]; then
        echo "expected $taskname to have $expect_timeouts time outs: got $timeouts"
        PASS=1
    fi
}

check "task1" 6 0
check "task2" 6 0
check "task3" 6 6
result=$PASS

if [ $result -ne 0 ]; then
    mv "${APP_ID}.log" task.log
    echo "test target logs in ./task.log"
else
    rm "${APP_ID}.log"
fi


exit $result
