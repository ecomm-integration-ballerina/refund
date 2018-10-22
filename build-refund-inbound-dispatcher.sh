ballerina build refund-inbound-dispatcher
docker build -t rajkumar/refund-inbound-dispatcher:0.1.0 -f refund-inbound-dispatcher/docker/Dockerfile .
docker push rajkumar/refund-inbound-dispatcher:0.1.0
kubectl delete -f refund-inbound-dispatcher/kubernetes/refund_inbound_dispatcher_deployment.yaml
kubectl create -f refund-inbound-dispatcher/kubernetes/refund_inbound_dispatcher_deployment.yaml