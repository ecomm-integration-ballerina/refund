FROM ballerina/ballerina:0.981.1
LABEL maintainer="rajkumarr@wso2.com"

COPY target/refund-inbound-dispatcher.balx /home/ballerina
COPY refund-inbound-dispatcher/conf/ballerina.conf /home/ballerina

COPY refund-inbound-dispatcher/dependencies/packages/dependencies/* /ballerina/runtime/bre/lib/
COPY refund-inbound-dispatcher/dependencies/packages/balo/* /ballerina/runtime/lib/repo/

CMD ballerina run refund-inbound-dispatcher.balx
