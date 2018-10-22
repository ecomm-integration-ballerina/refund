kubectl delete -f refund-data-service/kubernetes/refund_data_service_deployment.yaml
kubectl delete -f refund-inbound-dispatcher/kubernetes/refund_inbound_dispatcher_deployment.yaml
kubectl delete -f refund-inbound-processor/kubernetes/refund_inbound_processor_deployment.yaml
kubectl delete -f refund-outbound/kubernetes/refund_outbound_deployment.yaml