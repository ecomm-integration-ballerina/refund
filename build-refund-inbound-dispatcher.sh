ballerina build refund-inbound-dispatcher
docker build -t refund-inbound-dispatcher:0.1.0 -f refund-inbound-dispatcher/docker/Dockerfile .
kubectl delete -f refund-inbound-dispatcher/kubernetes/refund_inbound_dispatcher_deployment.yaml
kubectl create -f refund-inbound-dispatcher/kubernetes/refund_inbound_dispatcher_deployment.yaml