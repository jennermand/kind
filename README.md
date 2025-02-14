# kind

Following is used to test deployments in a local kubernetes cluster, running KIND

Remember to have a local system environment variable named **GITHUB_TOKEN**


# references
https://www.youtube.com/watch?v=LTlDRJovO7Q&t=189s&ab_channel=DevOpsToolkit

https://devopstoolkit.live/ci-cd/gitops-broke-ci-cd-here-is-how-to-fix-it-with-argo-events/

https://github.com/vfarcic/argo-events-gh-demo/blob/main/sa.yaml

## certs and key vault setup
https://azure.github.io/azure-workload-identity/docs/installation/self-managed-clusters/service-account-key-generation.html

https://azure.github.io/azure-workload-identity/docs/topics/self-managed-clusters/examples/kind.html

openssl genrsa -out ./certs/sa.key 2048
openssl rsa -in ./certs/sa.key -pubout -out ./certs/sa.pub