ballerina build refund-outbound
docker build -t rajkumar/refund-outbound:0.2.0 -f refund-outbound/docker/Dockerfile .
docker push rajkumar/refund-outbound:0.2.0 
kubectl delete -f refund-outbound/kubernetes/refund_outbound_deployment.yaml
kubectl create -f refund-outbound/kubernetes/refund_outbound_deployment.yaml