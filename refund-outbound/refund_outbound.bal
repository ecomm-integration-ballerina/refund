import ballerina/log;
import ballerina/http;
import ballerina/config;
import ballerina/task;
import ballerina/runtime;
import ballerina/io;

endpoint http:Client refundDataServiceEndpoint {
    url: config:getAsString("refund.data.service.url")
};

endpoint http:Client ecommFrontendRefundAPIEndpoint {
    url: config:getAsString("ecomm-frontend.refund.api.url")
};

int count;
task:Timer? timer;
int interval = config:getAsInt("refund.outbound.task.interval");
int delay = config:getAsInt("refund.outbound.task.delay");
int maxRetryCount = config:getAsInt("refund.outbound.task.maxRetryCount");
int maxRecords = config:getAsInt("refund.outbound.task.maxRecords");
string apiKey = config:getAsString("ecomm-frontend.refund.api.key");


function main(string... args) {

    (function() returns error?) onTriggerFunction = doRefundETL;

    function(error) onErrorFunction = handleError;

    log:printInfo("Starting refunds ETL"+interval);

    timer = new task:Timer(onTriggerFunction, onErrorFunction,
        interval, delay = delay);

    timer.start();
    runtime:sleep(200000);
}

function doRefundETL() returns  error? {

    log:printInfo("Calling refundDataServiceEndpoint to fetch refunds");

    var response = refundDataServiceEndpoint->get("?maxRecords=" + maxRecords
            + "&maxRetryCount=" + maxRetryCount + "&processFlag=N,E");

    match response {
        http:Response resp => {
            match resp.getJsonPayload() {
                json jsonRefundArray => {  

                    Refund[] refunds = check <Refund[]> jsonRefundArray;
                    // terminate the flow if no refunds found
                    if (lengthof refunds == 0) {
                        return;
                    }
                    // update process flag to P in DB so that next ETL won't fetch these again
                    boolean success = batchUpdateProcessFlagsToP(refunds);
                    // send refunds to Ecomm Frontend
                    if (success) {
                        processRefundsToEcommFrontend(refunds);
                    }
                }
                error err => {
                    log:printError("Response from refundDataEndpoint is not a json : " + 
                                    err.message, err = err);
                    throw err;
                }
            }
        }
        error err => {
            log:printError("Error while calling refundDataEndpoint : " + 
                            err.message, err = err);
            throw err;
        }
    }

    return ();
}

function processRefundsToEcommFrontend (Refund[] refunds) {

    http:Request req = new;
    foreach refund in refunds {

        int tid = refund.transactionId;
        string orderNo = refund.orderNo;
        int retryCount = refund.retryCount;
        string kind = refund.kind;
       
        json jsonPayload = untaint getRefundPayload(refund);
        req.setJsonPayload(jsonPayload);
        req.setHeader("api-key", apiKey);
        string contextId = "ECOMM_" + refund.countryCode;
        req.setHeader("Context-Id", contextId);

        log:printInfo("Calling ecomm-frontend to process refund for : " + orderNo + 
                        ". Payload : " + jsonPayload.toString());

        var response = ecommFrontendRefundAPIEndpoint->post("/" + untaint orderNo + "/cancel/async", req);

        match response {
            http:Response resp => {

                int httpCode = resp.statusCode;
                if (httpCode == 201) {
                    log:printInfo("Successfully processed refund for : " + orderNo + " to ecomm-frontend");
                    updateProcessFlag(tid, retryCount, "C", "sent to ecomm-frontend");
                } else {
                    match resp.getTextPayload() {
                        string payload => {
                            log:printInfo("Failed to process refund for : " + orderNo +
                                    " to ecomm-frontend. Error code : " + httpCode + ". Error message : " + payload);
                            updateProcessFlag(tid, retryCount + 1, "E", payload);
                        }
                        error err => {
                            log:printInfo("Failed to process refund for : " + orderNo +
                                    " to ecomm-frontend. Error code : " + httpCode);
                            updateProcessFlag(tid, retryCount + 1, "E", "unknown error");
                        }
                    }
                }
            }
            error err => {
                log:printError("Error while calling ecomm-frontend for refund for : " + orderNo, err = err);
                updateProcessFlag(tid, retryCount + 1, "E", "unknown error");
            }
        }
    }
}

function getRefundPayload(Refund refund) returns (json) {

    string kind = <string> refund.kind;
    json refundPayload ;
    if (kind == "CREDITMEMO") {

    } else if (kind == "REFUND") {

    } else {
        // default is CANCEL
        // refundPayload = {
        //     "requestId": refund.in,
        //     "invoiceId": refund.TOTAL_AMOUNT,
        //     "type": refund.CURRENCY,
        //     "currency": refund.COUNTRY_CODE,
        //     "countryCode": refund.refund_ID,
        //     "comments": ,
        //     "amount": ,
        //     "itemIds":
        // };
    }

    if (<string>refund["SETTLEMENT_ID"] != "") {
        refundPayload["settlementId"] = refund.settlementId;
    }

    // convert string 7,8,9 to json ["7","8","9"]
    string itemIds = refund.itemIds;
    string[] itemIdsArray = itemIds.split(",");
    json itemIdsJsonArray = check <json> itemIdsArray;
    refundPayload["itemIds"] = itemIdsJsonArray;

    return refundPayload;
}

function handleError(error e) {
    log:printError("Error in processing refunds to ecomm-frontend", err = e);
    // I don't want to stop the ETL if backend is down
    // timer.stop();
}

function batchUpdateProcessFlagsToP (Refund[] refunds) returns boolean{

    json batchUpdateProcessFlagsPayload;
    foreach i, refund in refunds {
        json updateProcessFlagPayload = {
            "transactionId": refund.transactionId,
            "retryCount": refund.retryCount,
            "processFlag": "P"           
        };
        batchUpdateProcessFlagsPayload.refunds[i] = updateProcessFlagPayload;
    }

    http:Request req = new;
    req.setJsonPayload(untaint batchUpdateProcessFlagsPayload);

    var response = refundDataServiceEndpoint->put("/process-flag/batch/", req);

    boolean success;
    match response {
        http:Response resp => {
            if (resp.statusCode == 202) {
                success = true;
            }
        }
        error err => {
            log:printError("Error while calling refundDataServiceEndpoint.batchUpdateProcessFlags", err = err);
        }
    }

    return success;
}

function updateProcessFlag(int tid, int retryCount, string processFlag, string errorMessage) {

    json updaterefund = {
        "transactionId": tid,
        "processFlag": processFlag,
        "retryCount": retryCount,
        "errorMessage": errorMessage
    };

    http:Request req = new;
    req.setJsonPayload(untaint updaterefund);

    io:println(updaterefund);
    io:println(tid);

    var response = refundDataServiceEndpoint->put("/process-flag/", req);

    io:println(response);

    match response {
        http:Response resp => {
            int httpCode = resp.statusCode;
            if (httpCode == 202) {
                if (processFlag == "E" && retryCount > maxRetryCount) {
                    notifyOperation();
                }
            }
        }
        error err => {
            log:printError("Error while calling refundDataServiceEndpoint", err = err);
        }
    }
}

function notifyOperation()  {
    // sending email alerts
    log:printInfo("Notifying operations");
}
