FROM ballerina/ballerina:0.981.1
LABEL maintainer="rajkumarr@wso2.com"

COPY target/refund-outbound.balx /home/ballerina
COPY refund-outbound/conf/ballerina.conf /home/ballerina

CMD ballerina run refund-outbound.balx
