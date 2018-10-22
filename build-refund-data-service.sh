ballerina build refund-data-service
docker build -t rajkumar/refund-data-service:0.1.0 -f refund-data-service/docker/Dockerfile .
docker push rajkumar/refund-data-service:0.1.0
kubectl delete -f refund-data-service/kubernetes/refund_data_service_deployment.yaml
kubectl create -f refund-data-service/kubernetes/refund_data_service_deployment.yaml