import ballerina/io;
import ballerina/http;
import ballerina/config;
import ballerina/log;
import ballerina/sql;

type invoiceBatchType string|int|float;

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

    string sqlString =
    "INSERT INTO refund(ORDER_NO,TYPE,INVOICE_ID,SETTLEMENT_ID, CREDIT_MEMO_ID,COUNTRY_CODE,ITEM_IDS,REQUEST,PROCESS_FLAG,
        RETRY_COUNT,ERROR_MESSAGE) VALUES (?,?,?,?,?,?,?,?,?,?,?)";

    log:printInfo("Calling refundDB->insert for OrderNo=" + refund.orderNo);

    boolean isSuccessful;
    transaction with retries = 5, oncommit = onCommitFunction, onabort = onAbortFunction {                              

        var ret = refundDB->update(sqlString, refund.orderNo, refund.kind, refund.invoiceId, refund.settlementId, refund.creditMemoId, refund.countryCode, 
        refund.itemIds, refund.request, refund.processFlag, refund.retryCount, refund.errorMessage);

        match ret {
            int insertedRows => {
                if (insertedRows < 1) {
                    log:printError("Calling refundDB->insert for OrderNo=" + refund.orderNo + " failed", err = ());
                    isSuccessful = false;
                    abort;
                } else {
                    log:printInfo("Calling refundDB->insert OrderNo=" + refund.orderNo + " succeeded");
                    isSuccessful = true;
                }
            }
            error err => {
                log:printError("Calling refundDB->insert for OrderNo=" + refund.orderNo + " failed", err = err);
                retry;
            }
        }        
    }  

    json resJson;
    int statusCode;
    if (isSuccessful) {
        statusCode = 200;
        resJson = { "Status": "Refund is inserted to the staging database for order : " + refund.orderNo };
    } else {
        statusCode = 500;
        resJson = { "Status": "Failed to insert refund to the staging database for order : " + refund.orderNo };
    }
    
    http:Response res = new;
    res.setJsonPayload(resJson);
    res.statusCode = statusCode;
    return res;
}

public function addRefunds (http:Request req, Refunds refunds)
                    returns http:Response {

    string uniqueString;
    invoiceBatchType[][] refundBatches;
    foreach i, refund in refunds.refunds {
        invoiceBatchType[] ref = [refund.orderNo, refund.kind, refund.invoiceId, refund.settlementId, 
                refund.creditMemoId, refund.countryCode, refund.itemIds, refund.request, refund.processFlag, 
                refund.retryCount, refund.errorMessage];
        refundBatches[i] = ref;
        uniqueString = uniqueString + "," + refund.orderNo;        
    }
    
    string sqlString = "INSERT INTO refund(ORDER_NO,TYPE,INVOICE_ID,SETTLEMENT_ID, CREDIT_MEMO_ID,
        COUNTRY_CODE,ITEM_IDS,REQUEST,PROCESS_FLAG, RETRY_COUNT,ERROR_MESSAGE) VALUES (?,?,?,?,?,?,?,?,?,?,?)"; 

    log:printInfo("Calling refundDB->batchUpdate for OrderNo=" + uniqueString);

    boolean isSuccessful;
    transaction with retries = 5, oncommit = onCommitFunction, onabort = onAbortFunction {  
        var retBatch = refundDB->batchUpdate(sqlString, ...refundBatches); 
        io:println(retBatch);
        match retBatch {
            int[] counts => {
                foreach count in counts {
                    if (count < 1) {
                        log:printError("Calling refundDB->batchUpdate for OrderNo=" + uniqueString + " failed", err = ());
                        isSuccessful = false;
                        abort;
                    } else {
                        log:printInfo("Calling refundDB->batchUpdate OrderNo=" + uniqueString + " succeeded");
                        isSuccessful = true;
                    }
                }
            }
            error err => {
                log:printError("Calling refundDB->batchUpdate for OrderNo=" + uniqueString + " failed", err = err);
                retry;
            }
        }
    }        

    json resJson;
    int statusCode;
    if (isSuccessful) {
        statusCode = 200;
        resJson = { "Status": "Refunds are inserted to the staging database for order : " + uniqueString};
    } else {
        statusCode = 500;
        resJson = { "Status": "Failed to insert refunds to the staging database for order : " + uniqueString };
    }

    http:Response res = new;
    res.setJsonPayload(resJson);
    res.statusCode = statusCode;
    return res;
}

public function updateProcessFlag (http:Request req, int tid, Refund refund)
                    returns http:Response {

    log:printInfo("Calling refundDB->updateProcessFlag for TID=" + tid + ", OrderNo=" + refund.orderNo);
    string sqlString = "UPDATE refund SET PROCESS_FLAG = ?, RETRY_COUNT = ? where TRANSACTION_ID = ?";

    json resJson;
    boolean isSuccessful;
    transaction with retries = 5, oncommit = onCommitFunction, onabort = onAbortFunction {                              

        var ret = refundDB->update(sqlString, refund.processFlag, refund.retryCount, tid);

        match ret {
            int insertedRows => {
                log:printInfo("Calling refundDB->updateProcessFlag for TID=" + tid + ", OrderNo=" + refund.orderNo + " succeeded");
                isSuccessful = true;
            }
            error err => {
                log:printError("Calling refundDB->updateProcessFlag for TID=" + tid + ", OrderNo=" + refund.orderNo + " failed", err = err);
                retry;
            }
        }        
    }     

    int statusCode;
    if (isSuccessful) {
        resJson = { "Status": "ProcessFlag is updated for order : " + tid };
        statusCode = 202;
    } else {
        resJson = { "Status": "Failed to update ProcessFlag for order : " + tid };
        statusCode = 500;
    }

    http:Response res = new;
    res.setJsonPayload(resJson);
    res.statusCode = statusCode;
    return res;
}

public function getRefunds (http:Request req)
                    returns http:Response {

    string baseSql = "SELECT * FROM refund";

    map<string> params = req.getQueryParams();

    if (params.hasKey("processFlag")) {
        baseSql = baseSql + " where PROCESS_FLAG in (" + params.processFlag + ")";
    }

    if (params.hasKey("maxRetryCount")) {
        match <int> params.maxRetryCount {
            int n => {
                baseSql = baseSql + " and RETRY_COUNT <= " + n;
            }
            error err => {
                throw err;
            }
        }
    }

    baseSql = baseSql + " order by TRANSACTION_ID asc";

    if (params.hasKey("maxRecords")) {
        match <int> params.maxRecords {
            int n => {
                baseSql = baseSql + " limit " + n;
            }
            error err => {
                throw err;
            }
        }
    }

    io:println(baseSql);

    var ret = refundDB->select(baseSql, ());

    json jsonReturnValue;
    match ret {
        table dataTable => {
            jsonReturnValue = check <json>dataTable;
        }
        error err => {
            jsonReturnValue = { "Status": "Data Not Found", "Error": err.message };
        }
    }

    io:println(jsonReturnValue);
    http:Response res = new;
    res.setJsonPayload(untaint jsonReturnValue);

    return res;
}

function onCommitFunction(string transactionId) {
    log:printInfo("Transaction: " + transactionId + " committed");
}

function onAbortFunction(string transactionId) {
    log:printInfo("Transaction: " + transactionId + " aborted");
}