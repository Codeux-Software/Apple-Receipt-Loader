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

#import "Payload.h"

NS_ASSUME_NONNULL_BEGIN

@interface ARLReceiptAttribute ()
@property (nonatomic, assign, readwrite) ARLPayloadAttributeType type;
@property (nonatomic, assign, readwrite) NSUInteger version;
@property (nonatomic, copy, readwrite) NSData *dataValue;
@property (readonly) int dataType;
@end

@implementation ARLReceiptAttribute

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}
#pragma clang diagnostic pop

- (instancetype)initAsType:(ARLPayloadAttributeType)type version:(NSUInteger)version value:(NSData *)value
{
	NSParameterAssert(value != nil);

	if ((self = [super init])) {
		self.type = type;

		self.version = version;

		self.dataValue = value;

		return self;
	}

	return nil;
}

- (int)dataType
{
	const unsigned char *dataValueBytes = self.dataValue.bytes;

	return dataValueBytes[0];
}

- (nullable NSString *)stringValue
{
	NSData *dataValue = self.dataValue;

	NSStringEncoding stringEncoding = 0;

	if (self.dataType == V_ASN1_UTF8STRING) {
		stringEncoding = NSUTF8StringEncoding;
	} else if (self.dataType == V_ASN1_IA5STRING) {
		stringEncoding = NSASCIIStringEncoding;
	}

	if (stringEncoding == 0) {
		return nil;
	}

	return [[NSString alloc] initWithBytes:(dataValue.bytes + 2)
									length:(dataValue.length - 2)
								  encoding:stringEncoding];
}

- (nullable NSDate *)dateValue
{
	NSString *dateString = self.stringValue;

	if (dateString == nil) {
		return nil;
	}

	return _ARLDateObjectFromDateString(dateString);
}

- (NSInteger)integerValue
{
	if (self.dataType != V_ASN1_INTEGER) {
		return 0;
	}

	NSInteger integerValue = 0;

	NSData *dataValue = self.dataValue;

	const unsigned char *dataValueBytes = dataValue.bytes;

	for (int i = 2; i < dataValue.length; i++) {
		integerValue = (integerValue << 8);

		integerValue += dataValueBytes[i];
	}

	return integerValue;
}

@end

NS_ASSUME_NONNULL_END
