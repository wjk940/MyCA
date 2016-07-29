#!/bin/bash
set -e

#
# Documentation: https://jamielinux.com/docs/openssl-certificate-authority/introduction.html
#

###################################
# 		 OpenSSL
###################################
OPENSSL_VERSION="openssl-1.0.2g"
ARCH="x86_64"
OPENSSL="`cd "../Openssl/builds/${OPENSSL_VERSION}-${ARCH}/bin";pwd`/openssl"
###################################

# Root directory all CA keys and certificates.
CAHOME="${PWD}"

# needed by root CA openssl config (root-config.cnf)
export ROOTCA="${CAHOME}/rootca"

makeRootCA()
{
	SUBJECT="$1"

	echo "Using ${OPENSSL} to build CA in ${ROOTCA}"
	
	echo "Clean up before building root CA into a clean directory tree."
	rm -rf "${ROOTCA}"
	mkdir -p "${ROOTCA}"
	
	pushd . > /dev/null
	
	cd "${ROOTCA}"
	
	# Create the directory structure. The index.txt and serial files act as a
	# kind of flat file database to keep track of signed certificates.
	
	mkdir certs crl newcerts private
	chmod 700 private
	touch index.txt
	echo 1000 > serial
	cp ../Config/root-config.cnf .
	
	# Create the root key (ca.key.pem) and keep it absolutely secure. Anyone
	# in possession of the root key can issue trusted certificates. Encrypt
	# the root key with AES 256-bit encryption and a strong password.
	#
	# Use 4096 bits for all root and intermediate certificate authority keys.
	# You’ll still be able to sign server and client certificates of a shorter
	# length.
	
	echo "generate root key"
	${OPENSSL} genrsa -aes256 \
		-out private/ca.key.pem 4096
	
	chmod 400 private/ca.key.pem
	
	# Use the root key (ca.key.pem) to create a root certificate
	# (ca.cert.pem). Give the root certificate a long expiry date, such as
	# twenty years. Once the root certificate expires, all certificates signed
	# by the CA become invalid.
	
	echo "create root certificate"
	${OPENSSL} req -config root-config.cnf \
		-key private/ca.key.pem \
		-new -x509 -days 7300 -sha256 -extensions v3_ca \
		-out certs/ca.cert.pem \
		-subj "${SUBJECT}"
	
	chmod 444 certs/ca.cert.pem
	
	# Verify the root certificate
	# The output shows:
	# 
	# the Signature Algorithm used
	# the dates of certificate Validity
	# the Public-Key bit length
	# the Issuer, which is the entity that signed the certificate
	# the Subject, which refers to the certificate itself
	# The Issuer and Subject are identical as the certificate is self-signed.
	# 	Note that all root certificates are self-signed.
	# The output also shows the X509v3 extensions. We applied the v3_ca
	# 	extension, so the options from [ v3_ca ] should be reflected in the
	# 	output.
	
	echo "verify root certificate"
	${OPENSSL} x509 -noout -text -in certs/ca.cert.pem
	
	popd > /dev/null
}

makeIntermediateCA()
{
	CANAME="$1"
	SUBJECT="$2"

	# Create an intermediate pair for ${CAHOME} CA
	#
	# An intermediate certificate authority (CA) is an entity that can sign
	# certificates on behalf of the root CA. The intermediate certificate is
	# signed by the root CA, which forms a chain of trust.
	#
	# The purpose of using an intermediate CA is primarily for security. The
	# root key can be kept offline and used as little as possible. If the
	# intermediate key is compromised, the root CA can revoke the intermediate
	# certificate and create a new intermediate cryptographic pair.
	
	# The intermediate CA configuration is a template. Set up the environment,
	# so the configuration is specific to CA we are using for this server.
	
	export INTERMEDIATECA="${CAHOME}/${CANAME}ca"
	export PRIVATEKEYNAME="${CANAME}.key.pem"
	export CERTIFICATENAME="${CANAME}.cert.pem"
	export CRLNAME="${CANAME}.crl.pem"
	export SUBJECTALTNAME=""
	
	echo "Using ${OPENSSL} to build CA in ${INTERMEDIATECA}"
	
	echo "Clean up before building ${CANAME} CA into a clean directory tree."
	rm -rf "${INTERMEDIATECA}"
	mkdir -p "${INTERMEDIATECA}"
	
	pushd . > /dev/null
	cd "${INTERMEDIATECA}"
	
	# Create the same directory structure used for the root CA files. It’s
	# convenient to also create a csr directory to hold certificate signing
	# requests.
	
	mkdir certs crl csr newcerts private
	chmod 700 private
	touch index.txt
	echo 1000 > serial
	cp ../Config/intermediate-config.cnf .
	
	# Add a crlnumber file to the intermediate CA directory tree. crlnumber is
	# used to keep track of certificate revocation lists.
	
	echo 1000 > crlnumber
	
	# Create the intermediate key. Encrypt the intermediate key with AES
	# 256-bit encryption and a strong password.
	
	echo "generate ${CANAME} key"
	${OPENSSL} genrsa -aes256 \
		-out private/${PRIVATEKEYNAME} 4096
	
	chmod 400 private/${PRIVATEKEYNAME}
	
	# Use the intermediate key to create a certificate signing request (CSR).
	# The details should generally match the root CA, except the Common Name
	# which must be different.
	#
	# Make sure you specify the intermediate CA configuration.
	
	echo "create ${CANAME} CSR"
	${OPENSSL} req -config intermediate-config.cnf -new -sha256 \
		-key private/${PRIVATEKEYNAME} \
		-out csr/${CANAME}.csr.pem \
		-subj "${SUBJECT}"
	
	# To create an intermediate certificate, use the root CA with the
	# v3_intermediate_ca extension to sign the intermediate CSR. The
	# intermediate certificate should be valid for a shorter period than the
	# root certificate. Ten years would be reasonable.
	
	# This time, specify the root CA configuration.
	
	echo "sign ${CANAME} CSR"
	${OPENSSL} ca -config "${ROOTCA}/root-config.cnf" -extensions v3_intermediate_ca \
		-days 3650 -notext -md sha256 \
		-in csr/${CANAME}.csr.pem \
		-out certs/${CERTIFICATENAME}
	
	chmod 444 certs/${CERTIFICATENAME}
	
	# As we did for the root certificate, check that the details of the
	# intermediate certificate are correct.
	
	echo "verify ${CANAME} certificate"
	${OPENSSL} x509 -noout -text \
		-in certs/${CERTIFICATENAME}
	
	# Verify the intermediate certificate against the root certificate. An OK
	# indicates that the chain of trust is intact.
	
	echo "verify ${CANAME} certificate against root"
	${OPENSSL} verify -CAfile "${ROOTCA}/certs/ca.cert.pem" \
		certs/${CERTIFICATENAME}
	
	# Create the certificate chain file
	#
	# When an application (eg, web browser) tries to verify a certificate
	# signed by the intermediate CA, it must also verify the intermediate
	# certificate against the root certificate. To complete the chain of
	# trust, a CA certificate chain file must be presented to the application.
	#
	# Create this file by concatenating the intermediate and root certificates
	# together. We will use this file later to verify certificates signed by
	# the intermediate CA.
	#
	# Our certificate chain file must include the root certificate because no
	# client application knows about it yet. A better option, particularly if
	# you’re administrating an intranet, is to install your root certificate
	# on every client that needs to connect. In that case, the chain file need
	# only contain your intermediate certificate.
	
	cat certs/${CERTIFICATENAME} \
		"${ROOTCA}/certs/ca.cert.pem" > certs/${CANAME}-chain.cert.pem
	chmod 444 certs/${CANAME}-chain.cert.pem
	
	popd > /dev/null
}

# -subj uses / as a separater, and white space is not tolerated, if you
# add white space, a parsing error (e.g., "Subject Attribute CN has no
# known NID, skipped") is displayed

subj="/C=US/ST=California/L=Redwood City/O=[my org]/OU=corpsec/\
CN=example.com/emailAddress=security@example.com"
makeRootCA "${subj}"

for ca in pepperoni bacon sausage ham chicken mushroom onion olive; do

	subj="/C=US/ST=California/L=Redwood City/O=[my org]/OU=${ca}/\
	CN=${ca}.example.com/emailAddress=security@example.com"

	makeIntermediateCA "${ca}" "${subj}"

done
