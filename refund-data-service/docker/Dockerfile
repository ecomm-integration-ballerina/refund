FROM ballerina/ballerina:0.981.1
LABEL maintainer="rajkumarr@wso2.com"

COPY target/refund-data-service.balx /home/ballerina
COPY refund-data-service/ballerina.conf /home/ballerina

EXPOSE  8280

CMD ballerina run refund-data-service.balx
