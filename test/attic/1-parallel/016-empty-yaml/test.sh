#!/bin/bash

# Copyright 2018 Datawire. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License

set -e -o pipefail

NAMESPACE="016-empty-yaml"

cd $(dirname $0)
ROOT=$(cd ../..; pwd)
source ${ROOT}/utils.sh
bootstrap --cleanup ${NAMESPACE} ${ROOT}

python ${ROOT}/yfix.py ${ROOT}/fixes/test-dep.yfix \
    ${ROOT}/ambassador-deployment.yaml \
    k8s/ambassador-deployment.yaml \
    ${NAMESPACE} \
    ${NAMESPACE}

kubectl apply -f k8s/rbac.yaml
kubectl apply -f k8s/ambassador.yaml
# This QOTM service has an extra triple dash (---) in the YAML which is treated as empty YAML
kubectl apply -f k8s/qotm.yaml
# This service has an empty Ambassador YAML
kubectl apply -f k8s/empty-config.yaml
kubectl apply -f k8s/ambassador-deployment.yaml

set +e +o pipefail

wait_for_pods ${NAMESPACE}

CLUSTER=$(cluster_ip)
APORT=$(service_port ambassador ${NAMESPACE})

BASEURL="http://${CLUSTER}:${APORT}"

echo "Base URL $BASEURL"
echo "Diag URL $BASEURL/ambassador/v0/diag/"

wait_for_ready "$BASEURL" ${NAMESPACE}

if ! check_diag "$BASEURL" 1 "No annotated services"; then
    exit 1
fi

if [ -n "$CLEAN_ON_SUCCESS" ]; then
    drop_namespace ${NAMESPACE}
fi
