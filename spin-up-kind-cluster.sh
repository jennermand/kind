#!/bin/bash

# Name of the kind cluster
CLUSTER_NAME="jenk-cluster"
ARGO_NAMESPACE="argo-cd"
spinner() {
    local pid=$!
    local delay=0.1
    # Hide cursor
    tput civis
    
    # Set text color to green
    printf '\e[32m'
    
    # done
    local pnt=0 shs=( 01 08 10 20 80 40 04 02 09 18 30 a0 c0 44 06 03 19 38
        b0 e0 c4 46 07 0b 39 b8 f0 e4 c6 47 0f 1b b9 f8 f4 e6 c7 4f 1f 3b f9
        fc f6 e7 cf 5f 3f bb fd fe f7 ef df 7f bf fb f9 fc f6 e7 cf 5f 3f bb
        b9 f8 f4 e6 c7 4f 1f 3b 39 b8 f0 e4 c6 47 0f 1b 19 38 b0 e0 c4 46 07
    0b 09 18 30 a0 c0 44 06 03 )
    printf '\e7'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        printf %b\\e8  \\U28${shs[pnt++%${#shs[@]}]}
        sleep $delay
    done
    # Reset text color
    printf '\e[0m'
    
    # Show cursor
    tput cnorm
    printf "    \b\b\b\b"
}

# Function to run a command with a spinner
spinner_function() {
    # Run the command passed as an argument in the background
    "$@" &
    
    # Capture the PID of the command
    local cmd_pid=$!
    
    # Show spinner while the command is running
    spinner $cmd_pid
    
    # Wait for the command to complete
    wait $cmd_pid
}

perform_helm_upgrade() {
    echo "Detected changes in 0-boot folder. Performing Helm upgrade..."
    helm upgrade -n ${ARGO_NAMESPACE} ./0-boot
    #helm install argo-cd -n ${ARGO_NAMESPACE} ./0-boot/ --set argocd.argocd.token=$GITHUB_TOKEN
}

# Function to monitor file changes
monitor_file_changes() {
    inotifywait -m -r -e modify,create,delete,move ./0-boot |
    while read -r directory events filename; do
        echo "Change detected: $events in $directory$filename"
        perform_helm_upgrade
    done
}

# Check if the cluster already exists
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo "Cluster '${CLUSTER_NAME}' already exists."
    # delete cluster
    spinner_function kind delete cluster --name ${CLUSTER_NAME}
else
    echo "Cluster '${CLUSTER_NAME}' does not exist. Creating it now..."
  kind create cluster --name ${CLUSTER_NAME}  --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraMounts:
  - hostPath: /etc/ssl/certs/ca-certificates.crt
    containerPath: /etc/ssl/certs/ca-certificates.crt
#   - hostPath: ./apps
#     containerPath: /apps
EOF
    echo "Cluster '${CLUSTER_NAME}' created successfully."
    
    # Set the default context to the new cluster
    kubectl config set-context --current --namespace=default
    
    # wait cluster to be ready
    spinner_function kubectl wait --for=condition=Ready node --all --timeout=60s
    
    # Install ArgoCD
    spinner_function kubectl create namespace ${ARGO_NAMESPACE}
    spinner_function kubectl create namespace argo-events
    # spinner_function kubectl apply -n ${ARGO_NAMESPACE} -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    # spinner_function kubectl apply -n ${ARGO_NAMESPACE} -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.10.6/manifests/ha/install.yaml
    # helm install argocd -n ${ARGO_NAMESPACE} oci://registry-1.docker.io/bitnamicharts/argo-cd
    spinner_function kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/namespace-install.yaml
    
    # spinner_function kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml
    # Install with a validating admission controller
    # spinner_function kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install-validating-webhook.yaml
    
    spinner_function kubectl apply -n argo-events -f https://raw.githubusercontent.com/argoproj/argo-events/stable/examples/eventbus/native.yaml
    
    echo
    
    # Ensure the correct path to the Helm chart
    spinner_function helm install argo-cd -n ${ARGO_NAMESPACE} ./0-boot/ --set argocd.argocd.token=$GITHUB_TOKEN
    spinner_function kubectl patch svc argocd-server -n ${ARGO_NAMESPACE} -p '{"spec": {"type": "LoadBalancer"}}'
    # wait for argocd to be ready
    spinner_function kubectl wait --for=condition=Ready pod -l app.kubernetes.io/component=server -n ${ARGO_NAMESPACE} --timeout=360s
    
    # Capture the PID of the kubectl command
    kubectl_pid=$!
    
    # # Show spinner while the kubectl command is running
    spinner $kubectl_pid
    
    # Wait for the kubectl command to complete
    wait $kubectl_pid
    
    #wait for password to be generated in argocd-secret
    spinner_function kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server -n ${ARGO_NAMESPACE} --timeout=360s
    
    
    
    echo "Username: \"admin\""
    if kubectl get secret argocd-initial-admin-secret -n ${ARGO_NAMESPACE} > /dev/null 2>&1; then
        echo "Password: $(kubectl get secret argocd-initial-admin-secret -n ${ARGO_NAMESPACE} -o jsonpath="{.data.password}" | base64 --decode)"
    else
        echo "Password: $(kubectl -n ${ARGO_NAMESPACE} get secret argocd-secret -o jsonpath="{.data.clearPassword}" | base64 -d)"
    fi
    #kubectl port-forward svc/argocd-argo-cd-server -n argocd 8080:443
    # Check if the argocd-argo-cd-server service exists
    if kubectl get svc/argocd-argo-cd-server -n ${ARGO_NAMESPACE} > /dev/null 2>&1; then
        echo "Service argocd-argo-cd-server exists. Starting port-forward..."
        kubectl port-forward svc/argocd-argo-cd-server -n ${ARGO_NAMESPACE} 8080:443
        elif kubectl get svc/argocd-server -n ${ARGO_NAMESPACE} > /dev/null 2>&1; then
        echo "Service argocd-argo-cd-server exists. Starting port-forward..."
        kubectl port-forward svc/argocd-server -n ${ARGO_NAMESPACE} 8080:443
        elif kubectl get svc/argo-cd-server -n ${ARGO_NAMESPACE} > /dev/null 2>&1; then
        echo "Service argocd-argo-cd-server exists. Starting port-forward..."
        
        #create a thread that monitors file changes in "0-boot" folder and subfolder. When change is detected, a helm upgrade is performed
        
        # monitor_file_changes &
        kubectl port-forward svc/argo-cd-server -n ${ARGO_NAMESPACE} 8080:443
        
        
        #open browser to localhost:8080
        open http://localhost:8080
    else
        echo "Service argocd-argo-cd-server does not exist. Exiting."
    fi
fi

# Docs

#https://gitlab.com/rumble-o-bin/playground/multicluster-play/-/tree/main/app?ref_type=heads
