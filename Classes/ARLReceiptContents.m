/* *********************************************************************

        Copyright (c) 2010 - 2017 Codeux Software, LLC
     Please see ACKNOWLEDGEMENT for additional information.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 * Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.
 * Neither the name of "Codeux Software, LLC", nor the names of its 
   contributors may be used to endorse or promote products derived 
   from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 SUCH DAMAGE.

 *********************************************************************** */

NS_ASSUME_NONNULL_BEGIN

@interface ARLReceiptContents ()
@property (nonatomic, copy, readwrite) NSString *bundleId;
@property (nonatomic, copy, readwrite) NSData *bundleIdData;
@property (nonatomic, copy, readwrite) NSData *opaqueData;
@property (nonatomic, copy, readwrite) NSData *hashData;
@property (nonatomic, copy, readwrite) NSDate *originalPurchaseDate;
@property (nonatomic, copy, readwrite) NSString *originalPurchaseVersion;
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, ARLInAppPurchaseContents *> *inAppPurchases;
@end

@interface ARLInAppPurchaseContents ()
@property (nonatomic, assign, readwrite) NSUInteger quantity;
@property (nonatomic, copy, readwrite) NSString *productId;
@property (nonatomic, copy, readwrite) NSString *transactionId;
@property (nonatomic, copy, readwrite) NSString *originalTransactionId;
@property (nonatomic, copy, readwrite) NSDate *purchaseDate;
@property (nonatomic, copy, readwrite) NSDate *originalPurchaseDate;
@end

#pragma mark -
#pragma mark Receipt Contents

@implementation ARLReceiptContents

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}
#pragma clang diagnostic pop

- (instancetype)initWithData:(NSData *)signedData
{
	NSParameterAssert(signedData != nil);

	if ((self = [super init])) {
		[self decodeData:signedData];

		return self;
	}

	return nil;
}

- (void)decodeData:(NSData *)signedData
{
	NSParameterAssert(signedData != nil);

	NSArray *attributes = _ARLDecodeReceiptPayload(signedData);

	if (attributes.count == 0) {
		NSAssert(NO, @"Failed to decode receipt contents");
	}

	[self populateAttributes:attributes];
}

- (void)populateAttributes:(NSArray<ARLReceiptAttribute *> *)attributes
{
	NSParameterAssert(attributes != nil);

	NSMutableArray<ARLReceiptAttribute *> *inAppPurchases = nil;

	for (ARLReceiptAttribute *attribute in attributes)
	{
		switch (attribute.type) {
			case ARLPayloadAttributeBundleIdType:
			{
				self.bundleIdData = attribute.dataValue;

				self.bundleId = attribute.stringValue;

				break;
			}
			case ARLPayloadAttributeOpaqueValueType:
			{
				self.opaqueData = attribute.dataValue;

				break;
			}
			case ARLPayloadAttributeHashType:
			{
				self.hashData = attribute.dataValue;

				break;
			}
			case ARLPayloadAttributeOriginalPurchaseDateType:
			{
				self.originalPurchaseDate = attribute.dateValue;

				break;
			}
			case ARLPayloadAttributeOriginalPurchaseVersionType:
			{
				self.originalPurchaseVersion = attribute.stringValue;

				break;
			}
			case ARLPayloadAttributeInAppPurchaseType:
			{
				if (inAppPurchases == nil) {
					inAppPurchases = [NSMutableArray array];
				}

				[inAppPurchases addObject:attribute];

				break;
			}
			default:
			{
				break;
			}
		}
	}

	if (self.bundleIdData == nil ||
		self.bundleId == nil ||
		self.opaqueData == nil ||
		self.hashData == nil ||
		self.originalPurchaseDate == nil ||
		self.originalPurchaseVersion == nil)
	{
		NSAssert(NO, @"One or more values are missing");
	}

	if (inAppPurchases) {
		[self populateInAppPurchasesWithAttributes:inAppPurchases];
	} else {
		self.inAppPurchases = @{};
	}
}

- (void)populateInAppPurchasesWithAttributes:(NSArray<ARLReceiptAttribute *> *)attributes
{
	NSParameterAssert(attributes != nil);

	NSMutableDictionary<NSString *, ARLInAppPurchaseContents *> *inAppPurchases = [NSMutableDictionary dictionary];

	for (ARLReceiptAttribute *attribute in attributes)
	{
		ARLInAppPurchaseContents *purchase =
		[[ARLInAppPurchaseContents alloc] initWithData:attribute.dataValue];

		[inAppPurchases setObject:purchase forKey:purchase.productId];
	}

	self.inAppPurchases = inAppPurchases;
}

@end

#pragma mark -
#pragma mark In-App Purchase Contents

@implementation ARLInAppPurchaseContents

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}
#pragma clang diagnostic pop

- (instancetype)initWithData:(NSData *)signedData
{
	NSParameterAssert(signedData != nil);

	if ((self = [super init])) {
		[self decodeData:signedData];

		return self;
	}

	return nil;
}

- (void)decodeData:(NSData *)signedData
{
	NSParameterAssert(signedData != nil);

	NSArray *attributes = _ARLDecodeReceiptPayload(signedData);

	if (attributes.count == 0) {
		NSAssert(NO, @"Failed to decode in-app purchase");
	}

	[self populateAttributes:attributes];
}

- (void)populateAttributes:(NSArray<ARLReceiptAttribute *> *)attributes
{
	NSParameterAssert(attributes != nil);

	for (ARLReceiptAttribute *attribute in attributes)
	{
		switch (attribute.type) {
			case ARLPayloadAttributeIAPQuantityType:
			{
				self.quantity = attribute.integerValue;

				break;
			}
			case ARLPayloadAttributeIAPProductIdType:
			{
				self.productId = attribute.stringValue;

				break;
			}
			case ARLPayloadAttributeIAPTransactionIdType:
			{
				self.transactionId = attribute.stringValue;

				break;
			}
			case ARLPayloadAttributeIAPPurchaseDateType:
			{
				self.purchaseDate = attribute.dateValue;

				break;
			}
			case ARLPayloadAttributeIAPOriginalTransactionIdType:
			{
				self.originalTransactionId = attribute.stringValue;

				break;
			}
			case ARLPayloadAttributeIAPOriginalPurchaseDateType:
			{
				self.originalPurchaseDate = attribute.dateValue;

				break;
			}
			default:
			{
				break;
			}
		}
	}

	if (self.quantity == 0 ||
		self.productId == nil ||
		self.transactionId == nil ||
		self.purchaseDate == nil ||
		self.originalTransactionId == nil ||
		self.originalPurchaseDate == nil)
	{
		NSAssert(NO, @"One or more values are missing");
	}
}

@end

NS_ASSUME_NONNULL_END
