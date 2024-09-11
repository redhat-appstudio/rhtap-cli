#!/usr/bin/env bash

shopt -s inherit_errexit
set -Eeu -o pipefail

declare -r NAMESPACE="${NAMESPACE:-}"
declare -r -a KAFKA_TOPICS=("${@}")

kafka_topic_ready() {
    status="$(
        oc get kafkatopics.kafka.strimzi.io "${1}" \
            --namespace="${NAMESPACE}" \
            --output=jsonpath='{.status.conditions[0].status}'
    )"
    [[ ${status} == "True" ]]
}

wait_for_kafka_topics() {
    for t in "${KAFKA_TOPICS[@]}"; do
        echo "# Checking if Kafka topic '${t}' is ready..."
        if ! kafka_topic_ready "${t}"; then
            echo -en "#\n# WARNING: Kafka topic '${t}' is not ready!\n#\n"
            return 1
        fi
        echo "# Kafka topic '${t}' is ready!"
    done
}

test_kafka_topics() {
    if [[ -z "${NAMESPACE}" ]]; then
        echo "Usage: $$ NAMESPACE=namespace $0 <STATEFULSETS>"
        exit 1
    fi

    if [[ ${#KAFKA_TOPICS[@]} -eq 0 ]]; then
        echo "Usage: $$ NAMESPACE=namespace $0 <KAFKA_TOPICS>"
        exit 1
    fi

    for i in {1..30}; do
        wait=$((i * 5))
        echo "### [${i}/30] Waiting for ${wait} seconds before retrying..."
        sleep ${wait}

        wait_for_kafka_topics &&
            return 0
    done
    return 1
}

if test_kafka_topics; then
    echo "# Kafka topics are ready: '${KAFKA_TOPICS[*]}'"
    exit 0
else
    echo "# ERROR: Kafka topics not ready!"
    exit 1
fi
