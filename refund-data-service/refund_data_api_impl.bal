import ballerina/io;
import ballerina/http;
import ballerina/config;
import ballerina/log;
import ballerina/sql;

type refundBatchType string|int|float;

endpoint mysql:Client refundDB {
    host: config:getAsString("refund.db.host"),
    port: config:getAsInt("refund.db.port"),
    name: config:getAsString("refund.db.name"),
    username: config:getAsString("refund.db.username"),
    password: config:getAsString("refund.db.password"),
    poolOptions: { maximumPoolSize: 5 },
    dbOptions: { useSSL: false, serverTimezone:"UTC" }
};

public function addRefund (http:Request req, Refund refund) returns http:Response {

    string sqlString = "INSERT INTO refund(orderNo,kind,invoiceId,settlementId,
        creditMemoId,countryCode,itemIds,request,processFlag,retryCount, errorMessage) 
        VALUES (?,?,?,?,?,?,?,?,?,?,?)";

    log:printInfo("Calling refundDB->insert for OrderNo=" + refund.orderNo);

    boolean isSuccessful;
    transaction with retries = 5, oncommit = onCommitFunction, onabort = onAbortFunction {                              

        var ret = refundDB->update(sqlString, refund.orderNo, refund.kind, refund.invoiceId, 
            refund.settlementId, refund.creditMemoId, refund.countryCode, refund.itemIds, 
            refund.request, refund.processFlag, refund.retryCount, refund.errorMessage);

        match ret {
            int insertedRows => {
                if (insertedRows < 1) {
                    log:printError("Calling refundDB->insert for OrderNo=" + refund.orderNo 
                        + " failed", err = ());
                    isSuccessful = false;
                    abort;
                } else {
                    log:printInfo("Calling refundDB->insert OrderNo=" + refund.orderNo + " succeeded");
                    isSuccessful = true;
                }
            }
            error err => {
                log:printError("Calling refundDB->insert for OrderNo=" + refund.orderNo 
                    + " failed", err = err);
                retry;
            }
        }        
    }  

    json resJson;
    int statusCode;
    if (isSuccessful) {
        statusCode = http:OK_200;
        resJson = { "Status": "Refund is inserted to the staging database for order : " 
                    + refund.orderNo };
    } else {
        statusCode = http:INTERNAL_SERVER_ERROR_500;
        resJson = { "Status": "Failed to insert refund to the staging database for order : " 
                    + refund.orderNo };
    }
    
    http:Response res = new;
    res.setJsonPayload(resJson);
    res.statusCode = statusCode;
    return res;
}

public function addRefunds (http:Request req, Refunds refunds)
                    returns http:Response {

    string uniqueString;
    refundBatchType[][] refundBatches;
    foreach i, refund in refunds.refunds {
        refundBatchType[] ref = [refund.orderNo, refund.kind, refund.invoiceId, refund.settlementId, 
                refund.creditMemoId, refund.countryCode, refund.itemIds, refund.request, refund.processFlag, 
                refund.retryCount, refund.errorMessage];
        refundBatches[i] = ref;
        uniqueString = uniqueString + "," + refund.orderNo;        
    }
    
    string sqlString = "INSERT INTO refund(orderNo,kind,invoiceId,settlementId,creditMemoId,
        countryCode,itemIds,request,processFlag,retryCount,errorMessage) VALUES (?,?,?,?,?,?,?,?,?,?,?)"; 

    log:printInfo("Calling refundDB->batchUpdate for OrderNo=" + uniqueString);

    boolean isSuccessful;
    transaction with retries = 5, oncommit = onCommitFunction, onabort = onAbortFunction {  
        var retBatch = refundDB->batchUpdate(sqlString, ...refundBatches); 
        io:println(retBatch);
        match retBatch {
            int[] counts => {
                foreach count in counts {
                    if (count < 1) {
                        log:printError("Calling refundDB->batchUpdate for OrderNo=" + uniqueString 
                            + " failed", err = ());
                        isSuccessful = false;
                        abort;
                    } else {
                        log:printInfo("Calling refundDB->batchUpdate OrderNo=" + uniqueString + " succeeded");
                        isSuccessful = true;
                    }
                }
            }
            error err => {
                log:printError("Calling refundDB->batchUpdate for OrderNo=" + uniqueString 
                    + " failed", err = err);
                retry;
            }
        }
    }        

    json resJson;
    int statusCode;
    if (isSuccessful) {
        statusCode = http:OK_200;
        resJson = { "Status": "Refunds are inserted to the staging database for order : " 
            + uniqueString};
    } else {
        statusCode = http:INTERNAL_SERVER_ERROR_500;
        resJson = { "Status": "Failed to insert refunds to the staging database for order : " 
            + uniqueString };
    }

    http:Response res = new;
    res.setJsonPayload(resJson);
    res.statusCode = statusCode;
    return res;
}

public function updateProcessFlag (http:Request req, Refund refund)
                    returns http:Response {

    log:printInfo("Calling refundDB->updateProcessFlag for TID=" + refund.transactionId + 
                    ", OrderNo=" + refund.orderNo);
    string sqlString = "UPDATE refund SET processFlag = ?, retryCount = ?, errorMessage = ? 
                            where transactionId = ?";

    json resJson;
    boolean isSuccessful;
    transaction with retries = 5, oncommit = onCommitFunction, onabort = onAbortFunction {                              

        var ret = refundDB->update(sqlString, refund.processFlag, refund.retryCount, 
                                    refund.errorMessage, refund.transactionId);

        match ret {
            int insertedRows => {
                log:printInfo("Calling refundDB->updateProcessFlag for TID=" + refund.transactionId + 
                                ", OrderNo=" + refund.orderNo + " succeeded");
                isSuccessful = true;
            }
            error err => {
                log:printError("Calling refundDB->updateProcessFlag for TID=" + refund.transactionId + 
                                ", OrderNo=" + refund.orderNo + " failed", err = err);
                retry;
            }
        }        
    }     

    int statusCode;
    if (isSuccessful) {
        resJson = { "Status": "ProcessFlag is updated for order : " + refund.transactionId };
        statusCode = http:ACCEPTED_202;
    } else {
        resJson = { "Status": "Failed to update ProcessFlag for order : " + refund.transactionId };
        statusCode = http:INTERNAL_SERVER_ERROR_500;
    }

    http:Response res = new;
    res.setJsonPayload(resJson);
    res.statusCode = statusCode;
    return res;
}

public function batchUpdateProcessFlag (http:Request req, Refunds refunds)
                    returns http:Response {

    refundBatchType[][] refundBatches;
    foreach i, refund in refunds.refunds {
        refundBatchType[] ref = [refund.processFlag, refund.retryCount, refund.transactionId];
        refundBatches[i] = ref;
    }
    
    string sqlString = "UPDATE refund SET processFlag = ?, retryCount = ? where transactionId = ?";

    log:printInfo("Calling refundDB->batchUpdateProcessFlag");
    
    json resJson;
    boolean isSuccessful;
    transaction with retries = 5, oncommit = onCommitFunction, onabort = onAbortFunction {                              

        var retBatch = refundDB->batchUpdate(sqlString, ... refundBatches);

        match retBatch {
            int[] counts => {
                foreach count in counts {
                    if (count < 1) {
                        log:printError("Calling refundDB->batchUpdateProcessFlag failed", err = ());
                        isSuccessful = false;
                        abort;
                    } else {
                        log:printInfo("Calling refundDB->batchUpdateProcessFlag succeeded");
                        isSuccessful = true;
                    }
                }
            }
            error err => {
                log:printError("Calling refundDB->batchUpdateProcessFlag failed", err = err);
                retry;
            }
        }      
    }     

    int statusCode;
    if (isSuccessful) {
        resJson = { "Status": "ProcessFlags updated"};
        statusCode = http:ACCEPTED_202;
    } else {
        resJson = { "Status": "ProcessFlags not updated" };
        statusCode = http:INTERNAL_SERVER_ERROR_500;
    }

    http:Response res = new;
    res.setJsonPayload(resJson);
    res.statusCode = statusCode;
    return res;
}

public function getRefunds (http:Request req)
                    returns http:Response {

    int retryCount = config:getAsInt("refund.data.service.default.retryCount");
    int resultsLimit = config:getAsInt("refund.data.service.default.resultsLimit");
    string processFlag = config:getAsString("refund.data.service.default.processFlag");

    map<string> params = req.getQueryParams();

    if (params.hasKey("processFlag")) {
        processFlag = params.processFlag;
    }

    if (params.hasKey("maxRetryCount")) {
        match <int> params.maxRetryCount {
            int n => {
                retryCount = n;
            }
            error err => {
                throw err;
            }
        }
    }

    if (params.hasKey("maxRecords")) {
        match <int> params.maxRecords {
            int n => {
                resultsLimit = n;
            }
            error err => {
                throw err;
            }
        }
    }

    string sqlString = "select * from refund where processFlag in ( ? ) 
        and retryCount <= ? order by transactionId asc limit ?";

    string[] processFlagArray = processFlag.split(",");
    sql:Parameter processFlagPara = { sqlType: sql:TYPE_VARCHAR, value: processFlagArray };

    var ret = refundDB->select(sqlString, Refund, processFlagPara, retryCount, resultsLimit);

    http:Response resp = new;
    json jsonReturnValue;
    match ret {
        table tableReturned => {
            jsonReturnValue = check <json> tableReturned;
            resp.statusCode = http:OK_200;
        }
        error err => {
            jsonReturnValue = { "Status": "Internal Server Error", "Error": err.message };
            resp.statusCode = http:INTERNAL_SERVER_ERROR_500;
        }
    }

    resp.setJsonPayload(untaint jsonReturnValue);
    return resp;
}

function onCommitFunction(string transactionId) {
    log:printInfo("Transaction: " + transactionId + " committed");
}

function onAbortFunction(string transactionId) {
    log:printInfo("Transaction: " + transactionId + " aborted");
}