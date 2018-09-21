import ballerina/log;
import ballerina/http;
import ballerina/config;
import ballerina/task;
import ballerina/runtime;
import ballerina/io;

endpoint http:Client refundDataServiceEndpoint {
    url: config:getAsString("refund.data.service.url")
};

endpoint http:Client ecommFrontendAPIEndpoint {
    url: config:getAsString("ecomm-frontend.api.url")
};

int count;
task:Timer? timer;
int interval = config:getAsInt("refund.outbound.task.interval");
int delay = config:getAsInt("refund.outbound.task.delay");
int maxRetryCount = config:getAsInt("refund.outbound.task.maxRetryCount");
int maxRecords = config:getAsInt("refund.outbound.task.maxRecords");
string apiKey = config:getAsString("ecomm-frontend.api.key");


function main(string... args) {

    (function() returns error?) onTriggerFunction = doRefundETL;

    function(error) onErrorFunction = handleError;

    log:printInfo("Starting refunds ETL");

    timer = new task:Timer(onTriggerFunction, onErrorFunction,
        interval, delay = delay);

    timer.start();
    runtime:sleep(200000);
}

function doRefundETL() returns  error? {

    log:printInfo("Calling refundDataServiceEndpoint to fetch refunds");

    var response = refundDataServiceEndpoint->get("?processFlag='N','E'&maxRecords=" + maxRecords
            + "&maxRetryCount=" + maxRetryCount);

    json refunds;
    match response {
        http:Response resp => {
            match resp.getJsonPayload() {
                json j => {refunds = j;}
                error err => {
                    log:printError("Response from refundDataEndpoint is not a json : " + err.message, err = err);
                    throw err;
                }
            }
        }
        error err => {
            log:printError("Error while calling refundDataEndpoint : " + err.message, err = err);
            throw err;
        }
    }

    log:printInfo("Got response from refundDataServiceEndpoint to fetch refunds" + refunds.toString());

    http:Request req = new;
    foreach refund in refunds {

        int tid = check <int> refund.TRANSACTION_ID;
        string orderNo = check <string> refund.ORDER_NO;
        int retryCount = check <int> refund.RETRY_COUNT;
        string kind = check <string> refund.TYPE;
       
        json jsonPayload = untaint getRefundPayload(refund);
        req.setJsonPayload(jsonPayload);
        req.setHeader("api-key", apiKey);
        string contextId = "ECOMM_" + check <string> refund.COUNTRY_CODE;
        req.setHeader("Context-Id", contextId);

        log:printInfo("Calling ecomm-frontend to process refund for : " + orderNo + 
                        ". Payload : " + jsonPayload.toString());

        response = ecommFrontendAPIEndpoint->post("/" + untaint orderNo + "/capture/async", req);

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
                            log:printInfo("Failed to process refund : for " + orderNo +
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

    return ();
}

function getRefundPayload(json refund) returns (json) {

    json refundPayload = {
        "amount": refund.AMOUNT,
        "totalAmount": refund.TOTAL_AMOUNT,
        "currency": refund.CURRENCY,
        "countryCode": refund.COUNTRY_CODE,
        "refundId": refund.refund_ID,
        "additionalProperties":{
            "trackingNumber": refund.TRACKING_NUMBER
        }
    };

    if (<string>refund["SETTLEMENT_ID"] != "") {
        refundPayload["settlementId"] = refund.SETTLEMENT_ID;
    }

    // convert string 7,8,9 to json ["7","8","9"]
    string itemIds = check <string> refund.ITEM_IDS;
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

function updateProcessFlag(int tid, int retryCount, string processFlag, string errorMessage) {

    json updaterefund = {
        "processFlag": processFlag,
        "retryCount": retryCount,
        "errorMessage": errorMessage
    };

    http:Request req = new;
    req.setJsonPayload(untaint updaterefund);

    var response = refundDataServiceEndpoint->put("/process-flag/" + untaint tid, req);

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
