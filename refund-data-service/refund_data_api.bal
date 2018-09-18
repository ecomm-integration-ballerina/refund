import ballerina/http;
import ballerina/log;
import ballerina/mysql;

endpoint http:Listener refundListener {
    host: "localhost",
    port: 8089
};

@http:ServiceConfig {
    basePath: "/refund"
}
service<http:Service> refundAPI bind refundListener {

    @http:ResourceConfig {
        methods:["POST"],
        path: "/batch/",
        body: "refunds"
    }
    addRefunds (endpoint outboundEp, http:Request req, Refunds refunds) {
        http:Response res = addRefunds(req, refunds);
        outboundEp->respond(res) but { error e => log:printError("Error while responding", err = e) };
    }

    @http:ResourceConfig {
        methods:["POST"],
        path: "/",
        body: "refund"
    }
    addRefund (endpoint outboundEp, http:Request req, Refund refund) {
        http:Response res = addRefund(req, refund);
        outboundEp->respond(res) but { error e => log:printError("Error while responding", err = e) };
    }

    @http:ResourceConfig {
        methods:["GET"],
        path: "/"
    }
    getAllRefunds (endpoint outboundEp, http:Request req) {
        http:Response res = getRefunds(untaint req);
        outboundEp->respond(res) but { error e => log:printError("Error while responding", err = e) };
    }

    @http:ResourceConfig {
        methods:["PUT"],
        path: "/process-flag/{tid}",
        body: "refund"
    }
    updateProcessFlag (endpoint outboundEp, http:Request req, int tid, Refund refund) {
        http:Response res = updateProcessFlag(req, tid, refund);
        outboundEp->respond(res) but { error e => log:printError("Error while responding", err = e) };
    }

}