import ballerina/io;
import ballerina/http;
import ballerina/config;

endpoint mysql:Client refundDB {
    host: config:getAsString("refund.db.host"),
    port: config:getAsInt("refund.db.port"),
    name: config:getAsString("refund.db.name"),
    username: config:getAsString("refund.db.username"),
    password: config:getAsString("refund.db.password"),
    poolOptions: { maximumPoolSize: 5 },
    dbOptions: { useSSL: false, serverTimezone:"UTC" }
};

public function addRefunds (http:Request req, Refunds refunds)
                    returns http:Response {

    http:Response res = new;

    int numberOfRefunds = lengthof refunds.refunds;

    int numberOfRecordsInserted;
    error dbError;
    transaction with retries = 4, oncommit = onCommitFunction,
                     onabort = onAbortFunction {

        string sqlString =
        "INSERT INTO invoice(ORDER_NO,INVOICE_ID,SETTLEMENT_ID,COUNTRY_CODE,
            PROCESS_FLAG,ERROR_MESSAGE,RETRY_COUNT,ITEM_IDS,TRACKING_NUMBER,REQUEST) VALUES (?,?,?,?,?,?,?,?,?,?)";

        foreach inv in refunds.refunds {
            int|error result = refundDB->update(sqlString, inv.orderNo, inv.invoiceId, inv.settlementId, inv.countryCode,
                inv.processFlag, inv.errorMessage, inv.retryCount, inv.itemIds, inv.trackingNumber, inv.request);

            match result {
                int c => {numberOfRecordsInserted += c;}
                error err => { dbError = err; retry;}
            }
        }

        io:println(numberOfRefunds);
        io:println(numberOfRecordsInserted);

        if (numberOfRecordsInserted != numberOfRefunds) {
            abort;
        }

    } onretry {
        io:println("Retrying transaction");
    }

    json updateStatus;
    if (numberOfRefunds == numberOfRecordsInserted) {
        updateStatus = { "Status": "Data Inserted Successfully" };
    } else {
        updateStatus = { "Status": "Data Not Inserted", "Error": dbError.message};
    }

    res.setJsonPayload(updateStatus);
    return res;
}

public function addRefund (http:Request req, Refund refund)
                    returns http:Response {

    http:Response res = new;

    json ret = insertRefund(refund);
    res.setJsonPayload(ret);

    io:println(ret);
    return res;
}

public function updateProcessFlag (http:Request req, int tid, Refund inv)
                    returns http:Response {

    http:Response res = new;

    var ret = refundDB->update("UPDATE refund SET PROCESS_FLAG = ?, RETRY_COUNT = ? where TRANSACTION_ID = ?",
        inv.processFlag, inv.retryCount, tid);

    json updateStatus;
    match ret {
        int retInt => {
            log:printInfo("Refund is updated for tid " + tid);
            updateStatus = { "status": "refund updated successfully" };
            res.statusCode = 202;
        }
        error err => {
            log:printError("Refund is not updated for tid " + tid, err = err);
            updateStatus = { "status": "refund not updated", "error": err.message };
            res.statusCode = 400;
        }
    }

    res.setJsonPayload(updateStatus);
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

public function insertRefund(Refund refund) returns (json) {
    json updateStatus;
    string sqlString =
    "INSERT INTO refund(ORDER_NO,INVOICE_ID,SETTLEMENT_ID,COUNTRY_CODE,
        PROCESS_FLAG,ERROR_MESSAGE,RETRY_COUNT,ITEM_IDS,TRACKING_NUMBER,REQUEST) VALUES (?,?,?,?,?,?,?,?,?,?)";

    var ret = refundDB->update(sqlString, refund.orderNo, refund.invoiceId, refund.settlementId, refund.countryCode,
        refund.processFlag, refund.errorMessage, refund.retryCount, refund.itemIds, refund.trackingNumber, refund.request);

    match ret {
        int updateRowCount => {
            updateStatus = { "Status": "Data Inserted Successfully" };
        }
        error err => {
            updateStatus = { "Status": "Data Not Inserted", "Error": err.message };
        }
    }
    return updateStatus;
}

function onCommitFunction(string transactionId) {
    io:println("Transaction: " + transactionId + " committed");
}

function onAbortFunction(string transactionId) {
    io:println("Transaction: " + transactionId + " aborted");
}