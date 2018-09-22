CREATE TABLE `refund` (
  `transactionId` int(11) NOT NULL AUTO_INCREMENT,
  `orderNo` varchar(100) DEFAULT NULL,
  `kind` varchar(100) DEFAULT NULL,
  `invoiceId` varchar(100) DEFAULT NULL,
  `settlementId` varchar(100) DEFAULT NULL,
  `creditMemoId` varchar(100) DEFAULT NULL,
  `countryCode` varchar(100) DEFAULT NULL,
  `itemIds` varchar(100) DEFAULT NULL,
  `request` text,
  `processFlag` varchar(100) DEFAULT NULL,
  `retryCount` int(11) DEFAULT NULL,
  `errorMessage` varchar(4000) DEFAULT NULL,
  `createdTime` timestamp NULL DEFAULT NULL,
  `lastUpdatedTime` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`transactionId`)
) ENGINE=InnoDB AUTO_INCREMENT=30 DEFAULT CHARSET=latin1
