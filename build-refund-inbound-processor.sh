ballerina build refund-inbound-processor
docker build -t rajkumar/refund-inbound-processor:0.1.0 -f refund-inbound-processor/docker/Dockerfile .
docker push rajkumar/refund-inbound-processor:0.1.0
kubectl delete -f refund-inbound-processor/kubernetes/refund_inbound_processor_deployment.yaml
kubectl create -f refund-inbound-processor/kubernetes/refund_inbound_processor_deployment.yaml