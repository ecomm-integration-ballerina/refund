import wso2/ftp;
import ballerina/io;
import ballerina/config;
import ballerina/log;
import ballerina/mb;
import ballerina/http;

endpoint ftp:Client refundSFTPClient {
    protocol: ftp:SFTP,
    host: config:getAsString("ecomm-backend.refund.sftp.host"),
    port: config:getAsInt("ecomm-backend.refund.sftp.port"),
    secureSocket: {
        basicAuth: {
            username: config:getAsString("ecomm-backend.refund.sftp.username"),
            password: config:getAsString("ecomm-backend.refund.sftp.password")
        }
    }
};

endpoint http:Client refundDataEndpoint {
    url: config:getAsString("refund.api.url")
};

endpoint mb:SimpleQueueReceiver refundInboundQueue {
    host: config:getAsString("refund.mb.host"),
    port: config:getAsInt("refund.mb.port"),
    queueName: config:getAsString("refund.mb.queueName")
};

service<mb:Consumer> refundInboundQueueReceiver bind refundInboundQueue {

    onMessage(endpoint consumer, mb:Message message) {
        match (message.getTextMessageContent()) {
            string path => {
                log:printInfo("New refund received from refundInboundQueue : " + path);
                boolean success = handleRefund(path);

                if (success) {
                    archiveCompletedRefund(path);
                } else {
                    archiveErroredRefund(path);
                }
            }
            error e => {
                log:printError("Error occurred while reading message from refundInboundQueue", err = e);
            }
        }
    }
}

function handleRefund(string path) returns boolean {

    boolean success = false;
    var refundOrError = refundSFTPClient -> get(path);

    match refundOrError {

        io:ByteChannel channel => {
            io:CharacterChannel characters = new(channel, "utf-8");
            xml refund = check characters.readXml();
            _ = channel.close();

            json refunds = generateRefundsJson(refund);

            http:Request req = new;
            req.setJsonPayload(untaint refunds);
            var response = refundDataEndpoint->post("/batch/", req);

            match response {
                http:Response resp => {
                    match resp.getJsonPayload() {
                        json j => {
                            log:printInfo("Response from refundDataEndpoint : " + j.toString());
                            success = true;
                        }
                        error err => {
                            log:printError("Response from refundDataEndpoint is not a json : " + err.message, err = err);
                        }
                    }
                }
                error err => {
                    log:printError("Error while calling refundDataEndpoint : " + err.message, err = err);
                }
            }
        }

        error err => {
            log:printError("Error while reading files from refundSFTPClient : " + err.message, err = err);
        }
    }

    return success;
}

function generateRefundsJson(xml refundXml) returns json {

    json refunds;
        
        json refundJson = {
            "orderNo" : x.selectDescendants("ZBLCORD").getTextValue(),
            "invoiceId" : x.selectDescendants("VBELN").getTextValue(),
            "settlementId" : x.selectDescendants("ZSETTID").getTextValue(),
            "trackingNumber" : x.selectDescendants("TRACK_NUMBER").getTextValue(),
            "itemIds" : x.selectDescendants("ZBLCITEM").getTextValue(),
            "countryCode" : x.selectDescendants("LAND1").getTextValue(),
            "request" : x.selectDescendants("ZBLCORD").getTextValue(),
            "processFlag" : "N",
            "retryCount" : 0,
            "errorMessage":"None"
        };
        refunds.refunds[i] = refundJson;
    }

    return refunds;
}

function archiveCompletedRefund(string  path) {
    string archivePath = config:getAsString("ecomm-backend.refund.sftp.path") + "/archive/" + getFileName(path);
    _ = refundSFTPClient -> rename(path, archivePath);
    io:println("Archived refund path : ", archivePath);
}

function archiveErroredRefund(string path) {
    string erroredPath = config:getAsString("ecomm-backend.refund.sftp.path") + "/error/" + getFileName(path);
    _ = refundSFTPClient -> rename(path, erroredPath);
    io:println("Errored refund path : ", erroredPath);
}

function getFileName(string path) returns string {
    string[] tmp = path.split("/");
    int size = lengthof tmp;
    return tmp[size-1];
}