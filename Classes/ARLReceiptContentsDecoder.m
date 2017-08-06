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

NSArray<ARLReceiptAttribute *> *_ARLDecodeReceiptPayload(NSData *signedPayload)
{
	NSCParameterAssert(signedPayload != nil);

	NSMutableArray<ARLReceiptAttribute *> *attributesOut = [NSMutableArray array];

	/* Decode payload */
	Payload_t *payload = NULL;

	asn_dec_rval_t payloadDecodeStatus;

	do {
		payloadDecodeStatus = asn_DEF_Payload.ber_decoder(NULL, &asn_DEF_Payload, (void **)&payload, signedPayload.bytes, signedPayload.length, 0);
	} while (payloadDecodeStatus.code == RC_WMORE);

	if (payloadDecodeStatus.code == RC_FAIL) {
		_ARLLogSetLastErrorMessage(@"Payload decode failed");

		goto finish;
	}

	/* Assign attribute values */
	for (size_t i = 0; i < payload->list.count; i++) {
		ReceiptAttribute_t *attribute = payload->list.array[i];

		OCTET_STRING_t *attributeOctet = &attribute->value;

		NSData *attributeData = [NSData dataWithBytes:attributeOctet->buf
											   length:attributeOctet->size];

		ARLReceiptAttribute *attributeObject =
		[[ARLReceiptAttribute alloc] initAsType:attribute->type
										version:attribute->version
										  value:attributeData];

		[attributesOut addObject:attributeObject];
	}

finish:
	if (payload) {
		free(payload);
	}

	return [attributesOut copy];
}

NS_ASSUME_NONNULL_END
