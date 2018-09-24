FROM ballerina/ballerina:0.981.1
LABEL maintainer="rajkumarr@wso2.com"

COPY target/refund-inbound-processor.balx /home/ballerina
COPY refund-inbound-processor/conf/ballerina.conf /home/ballerina

COPY refund-inbound-processor/dependencies/packages/dependencies/* /ballerina/runtime/bre/lib/
COPY refund-inbound-processor/dependencies/packages/balo/* /ballerina/runtime/lib/repo/

CMD ballerina run refund-inbound-processor.balx
