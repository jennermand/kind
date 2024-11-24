#!/bin/bash

# Name of the kind cluster
CLUSTER_NAME="jenk-cluster"

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
  - hostPath: ./apps
    containerPath: /apps
EOF
    echo "Cluster '${CLUSTER_NAME}' created successfully."
    
    # Set the default context to the new cluster
    kubectl config set-context --current --namespace=default
    
    
    # wait cluster to be ready
    spinner_function kubectl wait --for=condition=Ready node --all --timeout=60s
    
    # Install ArgoCD
    spinner_function kubectl create namespace argocd
    
    #get working directory
    WORKING_DIR=$(pwd)
    
    # Ensure the correct path to the Helm chart
    spinner_function helm install argocd -n argocd $WORKING_DIR/cluster/
    
    # wait for argocd to be ready
    spinner_function kubectl wait --for=condition=Ready pod -l app.kubernetes.io/component=server -n argocd --timeout=360s
    # Capture the PID of the kubectl command
    # kubectl_pid=$!
    
    # # Show spinner while the kubectl command is running
    # spinner $kubectl_pid
    
    # # Wait for the kubectl command to complete
    # wait $kubectl_pid
    
    #wait for password to be generated in argocd-secret
    # kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=360s
    
    
    echo "Username: \"admin\""
    echo "Password: $(kubectl -n argocd get secret argocd-secret -o jsonpath="{.data.clearPassword}" | base64 -d)"
    
    kubectl port-forward svc/argocd-argo-cd-server -n argocd 8080:443
fi