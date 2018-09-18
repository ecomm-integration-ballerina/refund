public type Refund record {
    int transactionId,
    string orderNo,
    string kind,
    string invoiceId,
    string settlementId,
    string creditMemoId,
    string itemIds,
    string countryCode,
    string request,
    string processFlag,
    int retryCount,
    string errorMessage,
    string createdTime,
    string lastUpdatedTime,
};

public type Refunds record {
    Refund[] refunds,
};