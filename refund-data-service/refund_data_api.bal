import ballerina/http;
import ballerina/log;
import ballerina/mysql;
import ballerinax/kubernetes;

@kubernetes:Service {
    serviceType: "LoadBalancer",
    name: "refund-data-service-service" 
}
endpoint http:Listener refundListener {
    port: 8280
};

@kubernetes:Deployment {
    name: "refund-data-service-deployment",    
    image: "index.docker.io/rajkumar/refund-data-service:0.1.0",
    buildImage: false,
    push: false,
    imagePullPolicy: "Always",
    copyFiles: [
        { 
            source: "./refund-data-service/conf/ballerina.conf", 
            target: "/home/ballerina/ballerina.conf", 
            isBallerinaConf: true 
        },
        { 
            source: "./refund-data-service/dependencies/packages/dependencies/mysql-connector-java-5.1.45-bin.jar", 
            target: "/ballerina/runtime/bre/lib/mysql-connector-java-5.1.45-bin.jar"
        }
    ]
}
@http:ServiceConfig {
    basePath: "/refund"
}
service<http:Service> refundAPI bind refundListener {

    @http:ResourceConfig {
        methods:["POST"],
        path: "/",
        body: "refund"
    }
    addRefund (endpoint outboundEp, http:Request req, Refund refund) {
        http:Response res = addRefund(req, untaint refund);
        outboundEp->respond(res) but { error e => log:printError("Error while responding", err = e) };
    }

    @http:ResourceConfig {
        methods:["POST"],
        path: "/batch/",
        body: "refunds"
    }
    addRefunds (endpoint outboundEp, http:Request req, Refunds refunds) {
        http:Response res = addRefunds(req, untaint refunds);
        outboundEp->respond(res) but { error e => log:printError("Error while responding", err = e) };
    }

    @http:ResourceConfig {
        methods:["GET"],
        path: "/"
    }
    getRefunds (endpoint outboundEp, http:Request req) {
        http:Response res = getRefunds(untaint req);
        outboundEp->respond(res) but { error e => log:printError("Error while responding", err = e) };
    }

    @http:ResourceConfig {
        methods:["PUT"],
        path: "/process-flag/",
        body: "refund"
    }
    updateProcessFlag (endpoint outboundEp, http:Request req, Refund refund) {
        http:Response res = updateProcessFlag(req, untaint refund);
        outboundEp->respond(res) but { error e => log:printError("Error while responding", err = e) };
    }

    @http:ResourceConfig {
        methods:["PUT"],
        path: "/process-flag/batch/",
        body: "refunds"
    }
    batchUpdateProcessFlag (endpoint outboundEp, http:Request req, Refunds refunds) {
        http:Response res = batchUpdateProcessFlag(req, refunds);
        outboundEp->respond(res) but { error e => log:printError("Error while responding", err = e) };
    }
}