import ballerina/http;
import ballerina/log;
import ballerina/mysql;
import ballerinax/docker;

@docker:Expose{}
endpoint http:Listener refundListener {
    port: 8280
};

@docker:CopyFiles {
    files: [
        { 
            source: "./refund-data-service/ballerina.conf", 
            target: "/home/ballerina/ballerina.conf", 
            isBallerinaConf: true 
        },
        { 
            source: "$env{BALLERINA_HOME}/bre/lib/mysql-connector-java-5.1.45-bin.jar", 
            target: "/ballerina/runtime/bre/lib/mysql-connector-java-5.1.45-bin.jar"
        }
    ]
}
@docker:Config {
    push:true,
    registry:"index.docker.io/$env{DOCKER_USERNAME}",
    name:"refund-data-service",
    tag:"0.1.0",
    username:"$env{DOCKER_USERNAME}",
    password:"$env{DOCKER_PASSWORD}"
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
        path: "/process-flag/{tid}",
        body: "refund"
    }
    updateProcessFlag (endpoint outboundEp, http:Request req, int tid, Refund refund) {
        http:Response res = updateProcessFlag(req, untaint tid, refund);
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