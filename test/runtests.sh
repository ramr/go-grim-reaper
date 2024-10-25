#!/bin/bash


readonly MAX_SLEEP_TIME=$((5 + 2))
readonly IMAGE="reaper/test"

logfile="/tmp/reaper_test.log"


function get_sleepers() {
    #shellcheck disable=SC2009
    ps -ef -p "$1" | grep sleep | grep -v grep

}  #  End of function  get_sleepers.


function check_orphans() {
    local pid1=$1

    sleep "${MAX_SLEEP_TIME}"
    local orphans=""
    orphans=$(get_sleepers "${pid1}")

    if [ -n "${orphans}" ]; then
        echo ""
        echo "FAIL: Got orphan processes attached to pid ${pid1}"
        echo "============================================================="
        echo "${orphans}"
        echo "============================================================="
        echo "      No sleep processes expected."
        return 1
    fi

    return 0

}  #  End of function  check_orphans.


function terminate_container() {
    docker logs "$1" > "${logfile}"
    echo "  - Container logs saved to ${logfile}"

    echo "  - Terminated container $(docker rm -f "$1")"

}  #  End of function  terminate_container.


function run_tests() {
    local image=${1:-"${IMAGE}"}

    logfile=/tmp/$(echo "${image}" | tr '/' '_').log

    echo "  - Removing any existing log file ${logfile} ... "
    rm -f "${logfile}"

    echo "  - Starting docker container running image ${image} ..."
    local elcid=""
    elcid=$(docker run -dit "${image}")

    echo "  - Docker container name=${elcid}"
    local pid1=""
    pid1=$(docker inspect --format '{{.State.Pid}}' "${elcid}")

    echo "  - Docker container pid=${pid1}"
    echo "  - Sleeping for ${MAX_SLEEP_TIME} seconds ..."
    sleep "${MAX_SLEEP_TIME}"

    echo "  - Checking for orphans attached to pid1=${pid1} ..."
    if ! check_orphans "${pid1}"; then
        #  Got an error, cleanup and exit with error code.
        terminate_container "${elcid}"
        echo ""
        echo "FAIL: All tests failed - (1/1)"
        exit 65
    fi
 

    local cname=""
    cname=$(echo "${elcid}" | cut -c 1-12)
    echo "  - Sending SIGUSR1 to ${cname} (pid ${pid1}) to start more workers ..."
    docker kill -s USR1 "${elcid}"

    sleep 1
    echo "  - PID ${pid1} has $(get_sleepers "${pid1}" | wc -l) sleepers."

    echo "  - Sleeping once again for ${MAX_SLEEP_TIME} seconds ..."
    sleep "${MAX_SLEEP_TIME}"

    echo "  - Checking for orphans attached to pid1=${pid1} ..."
    if ! check_orphans "${pid1}"; then
        #  Got an error, cleanup and exit with error code.
        terminate_container "${elcid}"
        echo ""
        echo "FAIL: Some tests failed - (1/2)"
        exit 65
    fi

    #  Do the cleanup.
    terminate_container "${elcid}"

    echo ""
    echo "OK: All tests passed - (2/2)"

} #  End of function  run_tests.


#
#  main():
#
run_tests "$@"
