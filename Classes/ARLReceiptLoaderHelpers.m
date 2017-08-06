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

NSData * _Nullable _ARLSystemMacAddress(void);

static NSString * _Nullable _ARLLastErrorMessage = nil;

#pragma mark -
#pragma mark Public API

NSString * _Nullable ARLLastErrorMessage(void)
{
	return _ARLLastErrorMessage;
}

#pragma mark -
#pragma mark Private API

NSData * _Nullable _ARLDigestForReceipt(ARLReceiptContents *receipt)
{
	/* Fetch the user's ethernet MAC address */
	NSData *macAddress = _ARLSystemMacAddress();

	if (macAddress == nil) {
		_ARLLogSetLastErrorMessage(@"Unknown MAC address");

		return nil;
	}

	/* Declare and initialize an EVP context for OpenSSL. */
	EVP_MD_CTX evp_ctx;
	EVP_MD_CTX_init(&evp_ctx);

	/* A buffer for result of the hash computation. */
	NSMutableData *digest = [NSMutableData dataWithLength:20];

	/* Set up the EVP context to compute a SHA-1 digest. */
	EVP_DigestInit_ex(&evp_ctx, EVP_sha1(), NULL);

	/* Concatenate the pieces to be hashed.  They must be concatenated in this order. */
	EVP_DigestUpdate(&evp_ctx, macAddress.bytes, macAddress.length);
	EVP_DigestUpdate(&evp_ctx, receipt.opaqueData.bytes, receipt.opaqueData.length);
	EVP_DigestUpdate(&evp_ctx, receipt.bundleIdData.bytes, receipt.bundleIdData.length);

	/* Compute the hash, saving the result into the digest variable. */
	EVP_DigestFinal_ex(&evp_ctx, digest.mutableBytes, NULL);

	/* Return result. */
	return [digest copy];
}

NSData * _Nullable _ARLUnpackPayloadOfReceipt(NSData *receiptContents)
{
	NSCParameterAssert(receiptContents != nil);

	/* libressl values */
	PKCS7 *lb_p7 = NULL;
	X509_STORE *lb_x509store = NULL;
	X509 *lb_appleCertificate = NULL;
	BIO *lb_signedPayload = NULL;
	int lb_verifyResult = 0;

	/* Objective-C values */
	NSData *lc_appleCertificateData = nil;

	/* Prepare OpenSSL for work */
	ERR_load_PKCS7_strings();
	ERR_load_X509_strings();

	OpenSSL_add_all_digests();

	/* Load receipt contents */
	const uint8_t *receiptContentsBytes = (uint8_t *)(receiptContents.bytes);

	lb_p7 = d2i_PKCS7(NULL, &receiptContentsBytes, receiptContents.length);

	if (lb_p7 == NULL) {
		_ARLLogSetLastErrorMessage(@"d2i_PKCS7() returned a value of 'NULL'");

		goto finish;
	}

	if (PKCS7_type_is_signed(lb_p7) == 0) {
		_ARLLogSetLastErrorMessage(@"PKCS7_type_is_signed() returned a value of '0'");

		goto finish;
	}

	if (PKCS7_type_is_data(lb_p7->d.sign->contents) == 0) {
		_ARLLogSetLastErrorMessage(@"PKCS7_type_is_data() returned a value of '0'");

		goto finish;
	}

	/* Begin validation process */
	lb_x509store = X509_STORE_new();

	if (lb_x509store == NULL) {
		_ARLLogSetLastErrorMessage(@"X509_STORE_new() returned a value of 'NULL'");

		goto finish;
	}

	/* Get Apple's certificate authority */
	lc_appleCertificateData = _ARLAppleRootCertificateData();

	if (lc_appleCertificateData == nil) {
		// Log nothing here because _ARLAppleRootCertificateData() will do it for us.

		goto finish;
	}

	const uint8_t *lc_appleCertificateDataBytes = (uint8_t *)(lc_appleCertificateData.bytes);

	lb_appleCertificate = d2i_X509(NULL, &lc_appleCertificateDataBytes, lc_appleCertificateData.length);

	if (lb_appleCertificate == NULL) {
		_ARLLogSetLastErrorMessage(@"d2i_X509() returned a value of 'NULL'");

		goto finish;
	}

	/* Allocate memory buffer for output */
	lb_signedPayload = BIO_new(BIO_s_mem());

	if (lb_signedPayload == NULL) {
		_ARLLogSetLastErrorMessage(@"BIO_new() returned a value of 'NULL'");

		goto finish;
	}

	/* Perform verification */
	X509_STORE_add_cert(lb_x509store, lb_appleCertificate);

	lb_verifyResult = PKCS7_verify(lb_p7, NULL, lb_x509store, NULL, lb_signedPayload, 0);

finish:
	/* Release any resources that are non-NULL */
	if (lb_p7)
		PKCS7_free(lb_p7);

	if (lb_x509store)
		X509_STORE_free(lb_x509store);

	if (lb_appleCertificate)
		X509_free(lb_appleCertificate);

	/* Convert payload to an Objective-C type */
	NSData *lc_signedData = nil;

	if (lb_signedPayload) {
		if (lb_verifyResult == 1) {
			char *payloadBuffer;
			size_t payloadBufferLen = BIO_get_mem_data(lb_signedPayload, &payloadBuffer);

			lc_signedData = [NSData dataWithBytes:payloadBuffer length:payloadBufferLen];
		}

		BIO_free(lb_signedPayload);
	}

	return lc_signedData;
}

NSData * _Nullable _ARLAppleRootCertificateData(void)
{
	SecKeychainRef systemKeychainRef = NULL;

	CFMutableDictionaryRef searchAttributesRef = NULL;

	SecCertificateRef certificateRef = NULL;

	CFDataRef certificateDataRef = NULL;

	/* Open the system keychain */
	OSStatus status = SecKeychainOpen("/System/Library/Keychains/SystemRootCertificates.keychain", &systemKeychainRef);

	if (status != noErr) {
		_ARLLogSecurityFrameworkError(status);

		goto finish;
	}

	/* Build list of attributes for matching certificate. */
	CFMutableArrayRef searchListRef = CFArrayCreateMutable(kCFAllocatorDefault, 1, &kCFTypeArrayCallBacks);

	CFArrayAppendValue(searchListRef, systemKeychainRef);

	searchAttributesRef =
	CFDictionaryCreateMutable(kCFAllocatorDefault, 5, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

	CFDictionaryAddValue(searchAttributesRef, kSecClass, kSecClassCertificate);
	CFDictionaryAddValue(searchAttributesRef, kSecMatchSearchList, searchListRef);
	CFDictionaryAddValue(searchAttributesRef, kSecAttrLabel, CFSTR("Apple Root CA"));
	CFDictionaryAddValue(searchAttributesRef, kSecReturnRef, kCFBooleanTrue);
	CFDictionaryAddValue(searchAttributesRef, kSecMatchTrustedOnly, kCFBooleanTrue);

	CFRelease(searchListRef);

	/* Perform search */
	status = SecItemCopyMatching(searchAttributesRef, (CFTypeRef *)&certificateRef);

	if (status != noErr) {
		_ARLLogSecurityFrameworkError(status);

		goto finish;
	}

	if (certificateRef == NULL) {
		_ARLLogSetLastErrorMessage(@"Missing root certificate");

		goto finish;
	}

	/* Convert certificate into data so it can be passed around */
	certificateDataRef = SecCertificateCopyData(certificateRef);

	if (certificateDataRef == NULL) {
		_ARLLogSetLastErrorMessage(@"Failed to copy root certificate data");

		goto finish;
	}

finish:
	/* Release any resources that are non-NULL */
	if (systemKeychainRef)
		CFRelease(systemKeychainRef);

	if (searchAttributesRef)
		CFRelease(searchAttributesRef);

	if (certificateRef)
		CFRelease(certificateRef);

	/* Convert certificate data to an Objective-C type */
	NSData *certificateData = nil;

	if (certificateDataRef) {
		certificateData =
		[NSData dataWithBytes:CFDataGetBytePtr(certificateDataRef)
					   length:CFDataGetLength(certificateDataRef)];

		CFRelease(certificateDataRef);
	}

	return certificateData;
}

NSData * _Nullable _ARLSystemMacAddress(void)
{
	CFDataRef macAddressRef = nil;

	/* Mach port used to initiate communication with IOKit. */
	mach_port_t masterPort;

	kern_return_t machPortResult = IOMasterPort(MACH_PORT_NULL, &masterPort);

	if (machPortResult != KERN_SUCCESS) {
		return nil;
	}

	/* Create a matching dictionary */
	CFMutableDictionaryRef matchingDict = IOBSDNameMatching(masterPort, 0, "en0");

	if (matchingDict == NULL) {
		return nil;
	}

	/* Look up registered bjects that match a matching dictionary. */
	io_iterator_t iterator;

	kern_return_t getMatchResult = IOServiceGetMatchingServices(masterPort, matchingDict, &iterator);

	if (getMatchResult != KERN_SUCCESS) {
		return nil;
	}

	/* Iterate over services */
	io_object_t service;

	while ((service = IOIteratorNext(iterator)) > 0) {
		io_object_t parentService;

		kern_return_t kernResult = IORegistryEntryGetParentEntry(service, kIOServicePlane, &parentService);

		if (kernResult == KERN_SUCCESS) {
			if (macAddressRef) {
				CFRelease(macAddressRef);
			}

			macAddressRef = (CFDataRef)IORegistryEntryCreateCFProperty(parentService, CFSTR("IOMACAddress"), kCFAllocatorDefault, 0);

			IOObjectRelease(parentService);
		}

		IOObjectRelease(service);
	}

	IOObjectRelease(iterator);

	/* If we have a MAC address, convert it into a formatted string. */
	if (macAddressRef) {
		NSData *macAddress = (__bridge NSData *)macAddressRef;

		CFRelease(macAddressRef);

		return macAddress;
	}

	return nil;
}

NSDate * _Nullable _ARLDateObjectFromDateString(NSString *dateString)
{
	NSDateFormatter *dateFormatter = nil;

	if (dateFormatter == nil) {
		dateFormatter = [NSDateFormatter new];

		dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];

		dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];

		dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
	}

	return [dateFormatter dateFromString:dateString];
}

#pragma mark -
#pragma mark Error Log

void _ARLLogResetLastErrorMessage(void)
{
	_ARLLastErrorMessage = nil;
}

void _ARLLogSetLastErrorMessage(NSString *errorMessage)
{
	NSCParameterAssert(errorMessage != nil);

	_ARLLastErrorMessage = [errorMessage copy];
}

void _ARLLogException(NSException *exception)
{
	NSString *errorMessage = [NSString stringWithFormat:@"Exception: %@", exception.reason];

	_ARLLogSetLastErrorMessage(errorMessage);
}

void _ARLLogSecurityFrameworkError(OSStatus error)
{
	CFStringRef errorString = SecCopyErrorMessageString(error, NULL);

	NSString *errorMessage = [NSString stringWithFormat:@"Security Framework: %d (%@)", error, errorString];

	_ARLLogSetLastErrorMessage(errorMessage);

	CFRelease(errorString);
}

