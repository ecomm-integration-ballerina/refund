import ballerina/io;
import ballerina/http;
import ballerina/config;
import ballerina/log;

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

    http:Response res = new;

    string sqlString =
    "INSERT INTO refund(ORDER_NO,TYPE,INVOICE_ID,SETTLEMENT_ID, CREDIT_MEMO_ID,COUNTRY_CODE,ITEM_IDS,REQUEST,PROCESS_FLAG,
        RETRY_COUNT,ERROR_MESSAGE,CREATED_TIME,LAST_UPDATED_TIME) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)";

    log:printInfo("Calling refundDB->insert for OrderNo=" + refund.orderNo);

    json resJson;
    boolean isSuccessful;
    transaction with retries = 5, oncommit = onCommitFunction, onabort = onAbortFunction {                              

        var ret = refundDB->update(sqlString, refund.orderNo, refund.kind, refund.invoiceId, refund.creditMemoId, refund.countryCode, 
        refund.itemIds, refund.request, refund.processFlag, refund.retryCount, refund.errorMessage, refund.createdTime, refund.lastUpdatedTime);

        match ret {
            int insertedRows => {
                log:printInfo("Calling refundDB->insert OrderNo=" + refund.orderNo + " succeeded");
                isSuccessful = true;
            }
            error err => {
                log:printError("Calling refundDB->insert for OrderNo=" + refund.orderNo + " failed", err = err);
                retry;
            }
        }        
    }     

    if (isSuccessful) {
        resJson = { "Status": "Refund is inserted to the staging database for order : " + refund.orderNo };
    } else {
        resJson = { "Status": "Failed to insert refund to the staging database for order : " + refund.orderNo };
    }
    
    res.setJsonPayload(resJson);
    return res;
}

public function addRefunds (http:Request req, Refunds refunds)
                    returns http:Response {

                        return new;

    // http:Response res = new;

    // int numberOfRefunds = lengthof refunds.refunds;

    // int numberOfRecordsInserted;
    // error dbError;
    // transaction with retries = 4, oncommit = onCommitFunction,
    //                  onabort = onAbortFunction {

    //     string sqlString =
    //     "INSERT INTO invoice(ORDER_NO,INVOICE_ID,SETTLEMENT_ID,COUNTRY_CODE,
    //         PROCESS_FLAG,ERROR_MESSAGE,RETRY_COUNT,ITEM_IDS,TRACKING_NUMBER,REQUEST) VALUES (?,?,?,?,?,?,?,?,?,?)";

    //     foreach inv in refunds.refunds {
    //         int|error result = refundDB->update(sqlString, inv.orderNo, inv.invoiceId, inv.settlementId, inv.countryCode,
    //             inv.processFlag, inv.errorMessage, inv.retryCount, inv.itemIds, inv.trackingNumber, inv.request);

    //         match result {
    //             int c => {numberOfRecordsInserted += c;}
    //             error err => { dbError = err; retry;}
    //         }
    //     }

    //     io:println(numberOfRefunds);
    //     io:println(numberOfRecordsInserted);

    //     if (numberOfRecordsInserted != numberOfRefunds) {
    //         abort;
    //     }

    // } onretry {
    //     io:println("Retrying transaction");
    // }

    // json updateStatus;
    // if (numberOfRefunds == numberOfRecordsInserted) {
    //     updateStatus = { "Status": "Data Inserted Successfully" };
    // } else {
    //     updateStatus = { "Status": "Data Not Inserted", "Error": dbError.message};
    // }

    // res.setJsonPayload(updateStatus);
    // return res;
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

    http:Response res = new;
    if (isSuccessful) {
        resJson = { "Status": "ProcessFlag is updated for order : " + tid };
        res.statusCode = 202;
    } else {
        resJson = { "Status": "Failed to update ProcessFlag for order : " + tid };
        res.statusCode = 400;
    }

    res.setJsonPayload(resJson);
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