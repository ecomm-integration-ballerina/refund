import wso2/ftp;
import ballerina/io;
import ballerina/config;
import ballerina/mb;
import ballerina/log;

endpoint ftp:Listener refundSFTPListener {
    protocol: ftp:SFTP,
    host: config:getAsString("ecomm-backend.refund.sftp.host"),
    port: config:getAsInt("ecomm-backend.refund.sftp.port"),
    secureSocket: {
        basicAuth: {
            username: config:getAsString("ecomm-backend.refund.sftp.username"),
            password: config:getAsString("ecomm-backend.refund.sftp.password")
        }
    },
    path:config:getAsString("ecomm-backend.refund.sftp.path") + "/original"
};

endpoint mb:SimpleQueueSender refundInboundQueue {
    host: config:getAsString("refund.mb.host"),
    port: config:getAsInt("refund.mb.port"),
    queueName: config:getAsString("refund.mb.queueName")
};

service refundMonitor bind refundSFTPListener {

    fileResource (ftp:WatchEvent m) {

        foreach v in m.addedFiles {
            log:printInfo("New refund received, inserting into refundInboundQueue : " + v.path);
            handleRefund(v.path);
        }

        foreach v in m.deletedFiles {
            // ignore
        }
    }
}

function handleRefund(string path) {
    match (refundInboundQueue.createTextMessage(path)) {
        error e => {
            log:printError("Error occurred while creating message", err = e);
        }
        mb:Message msg => {
            refundInboundQueue->send(msg) but {
                error e => log:printError("Error occurred while sending message to refundInboundQueue", err = e)
            };
        }
    }
}