#!/bin/bash
# © Copyright IBM Corporation 2023
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

namespace=${1:-"cp4i"}
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
INSTALL_CP4I=${2:-true}

function wait_for_operator_start() {
    subscriptionName=${1}
    installedNamespace=${2}
    echo "Waiting on subscription $subscriptionName in namespace $installedNamespace"

    wait_time=1
    time=0
    currentCSV=""
    while [[ -z "$currentCSV" ]]; do
      currentCSV=$(oc get subscriptions -n ${installedNamespace} ${subscriptionName} -o jsonpath={.status.currentCSV} 2>/dev/null)
      ((time = time + $wait_time))
      sleep $wait_time
      if [ $time -ge 300 ]; then
        echo "ERROR: Failed after waiting for 5 minutes"
        exit 1
      fi
    done

    echo "Waiting on CSV status $currentCSV"
    phase=""
    until [[ "$phase" == "Succeeded" ]]; do
      phase=$(oc get csv -n ${installedNamespace} ${currentCSV} -o jsonpath={.status.phase} 2>/dev/null)
      sleep $wait_time
      if [ $time -ge 600 ]; then
        echo "ERROR: Failed after waiting for 10 minutes"
        exit 1
      fi
      if [ $time -ge 300 ]; then
        echo "INFO: Waited over five minute and the status is $phase"
        exit 1
      fi
    done

}

oc new-project $namespace

if [ "$INSTALL_CP4I" = true ] ; then

    oc apply -f $SCRIPT_DIR/setupResources/ibm-catalog-source.yaml
    oc apply -f $SCRIPT_DIR/setupResources/operator-group.yaml
    
    cat $SCRIPT_DIR/setupResources/platform-nav-operator-subscription.yaml_template |
      sed "s#{{NAMESPACE}}#$namespace#g;" > $SCRIPT_DIR/setupResources/platform-nav-operator-subscription.yaml
    oc apply -f $SCRIPT_DIR/setupResources/platform-nav-operator-subscription.yaml
    rm $SCRIPT_DIR/setupResources/platform-nav-operator-subscription.yaml
    wait_for_operator_start ibm-integration-platform-navigator $namespace

    cat $SCRIPT_DIR/setupResources/cert-manager.yaml_template |
      sed "s#{{NAMESPACE}}#$namespace#g;" > $SCRIPT_DIR/setupResources/cert-manager.yaml
    oc apply -f $SCRIPT_DIR/setupResources/cert-manager.yaml
    rm $SCRIPT_DIR/setupResources/cert-manager.yaml
    wait_for_operator_start cert-manager-operator openshift-operators

    cat $SCRIPT_DIR/setupResources/ibm-common-services.yaml_template |
      sed "s#{{NAMESPACE}}#$namespace#g;" > $SCRIPT_DIR/setupResources/ibm-common-services.yaml
    oc apply -f $SCRIPT_DIR/setupResources/ibm-common-services.yaml
    rm $SCRIPT_DIR/setupResources/ibm-common-services.yaml
    wait_for_operator_start ibm-common-service-operator $namespace

fi

cat $SCRIPT_DIR/setupResources/apic-operator-subscription.yaml_template |
  sed "s#{{NAMESPACE}}#$namespace#g;" > $SCRIPT_DIR/setupResources/apic-operator-subscription.yaml

oc apply -f $SCRIPT_DIR/setupResources/apic-operator-subscription.yaml

rm $SCRIPT_DIR/setupResources/apic-operator-subscription.yaml

wait_for_operator_start ibm-apiconnect $namespace

cat $SCRIPT_DIR/setupResources/appconnect-operator-subscription.yaml_template |
  sed "s#{{NAMESPACE}}#$namespace#g;" > $SCRIPT_DIR/setupResources/appconnect-operator-subscription.yaml

oc apply -f $SCRIPT_DIR/setupResources/appconnect-operator-subscription.yaml

rm $SCRIPT_DIR/setupResources/appconnect-operator-subscription.yaml

wait_for_operator_start ibm-appconnect  $namespace

echo "Completed installation of API Connect and App Connect operators successfully"