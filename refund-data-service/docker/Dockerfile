FROM ballerina/ballerina:0.980.1
LABEL maintainer="dev@ballerina.io"

COPY target/refund-data-service.balx /home/ballerina

EXPOSE  8280

CMD ballerina run refund-data-service.balx
