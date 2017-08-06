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

#import "ARLReceiptLoader.h"

NS_ASSUME_NONNULL_BEGIN

BOOL ARLReadReceiptFromBundle(NSBundle *bundle, ARLReceiptContents * _Nonnull * _Nullable receiptContentsOut)
{
	NSURL *receiptPath = [bundle appStoreReceiptURL];

	if (receiptPath == nil) {
		_ARLLogSetLastErrorMessage(@"-[NSBundle appStoreReceiptURL] return a nil value");

		return NO;
	}

	NSData *receiptContentsIn = [NSData dataWithContentsOfURL:receiptPath];

	if (receiptContentsIn == nil) {
		_ARLLogSetLastErrorMessage(@"-[NSData dataWithContentsOfURL:] return a nil value");

		return NO;
	}

	return ARLReadReceipt(receiptContentsIn, receiptContentsOut);
}

BOOL ARLReadReceipt(NSData *receiptContentsIn, ARLReceiptContents * _Nonnull * _Nullable receiptContentsOut)
{
	NSCParameterAssert(receiptContentsIn != nil);

	/* Reset last recorded error message */
	_ARLLogResetLastErrorMessage();

	/* Unpack contents of receipt */
	NSData *signedPayload = _ARLUnpackPayloadOfReceipt(receiptContentsIn);

	if (signedPayload == nil) {
		return NO;
	}

	/* Convert contents into an object */
	ARLReceiptContents *receipt = nil;

	@try {
		receipt = [[ARLReceiptContents alloc] initWithData:signedPayload];
	}
	@catch (NSException *exception) {
		_ARLLogException(exception);

		return NO;
	}

	/* Get digest */
	NSData *digest = _ARLDigestForReceipt(receipt);

	if (digest == nil) {
		_ARLLogSetLastErrorMessage(@"_ARLDigestForReceipt() return a nil value");

		return NO;
	}

	/* Compare digest */
	if ([digest isEqualToData:receipt.hashData] == NO) {
		_ARLLogSetLastErrorMessage(@"Digest does not match receipt contents");

		return NO;
	}

	/* Success */
	*receiptContentsOut = receipt;

	return YES;
}

NS_ASSUME_NONNULL_END
