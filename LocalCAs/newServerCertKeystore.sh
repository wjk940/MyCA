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

newServerCert()
{
	CANAME="$1"
	SUBJECT="$2"
	COMMONNAME="$4"

	# The intermediate CA configuration is a template. Set up the environment,
	# so the configuration is specific to CA we are using for this server.

	export INTERMEDIATECA="${CAHOME}/${CANAME}ca"
	export PRIVATEKEYNAME="${CANAME}.key.pem"
	export CERTIFICATENAME="${CANAME}.cert.pem"
	export CRLNAME="${CANAME}.crl.pem"
	export SUBJECTALTNAME="$3"

	echo "Using ${OPENSSL} to build server auth in ${INTERMEDIATECA}"
	echo "CA Private Key Name = ${PRIVATEKEYNAME}"
	echo "CA Certification Name = ${CERTIFICATENAME}"
	echo "CA CRL Name = ${CRLNAME}"
	echo "Certificate Subject = ${SUBJECT}"
	echo "Certificate Subject Alt Name = ${SUBJECTALTNAME}"
	echo "Common Name portion of .pem filenames = ${COMMONNAME}"

	pushd . > /dev/null
	cd "${INTERMEDIATECA}"

	ServerKey="private/${COMMONNAME}.key.pem"
	ServerCSR="csr/${COMMONNAME}.csr.pem"
	ServerCert="certs/${COMMONNAME}.cert.pem"
	ServerCertP12="certs/${COMMONNAME}.cert.p12"
	Keystore="certs/${COMMONNAME}.keystore"

	echo "Cleanup prior .pem's for ${COMMONNAME}: ${ServerKey}, ${ServerCSR}, ${ServerCert} ${ServerCertP12} ${Keystore}"
	rm -f ${ServerKey} ${ServerCSR} ${ServerCert} ${ServerCertP12} ${Keystore}

	# Our root and intermediate pairs are 4096 bits. Since server and client
	# certificates normally expire after one year, we can safely use 2048 bits
	# instead.
	#
	# Although 4096 bits is slightly more secure than 2048 bits, it also
	# reduces TLS handshake speed and significantly increases processor load
	# during handshakes. For this reason, most websites use 2048-bit pairs. If
	# you’re creating a cryptographic pair for use with a web server (eg,
	# Apache), you’ll need to enter this password every time you restart the
	# web server. You may want to omit the -aes256 option to create a key
	# without a password.

	echo "generate ${ServerKey}"
	${OPENSSL} genrsa -out ${ServerKey} 2048

	chmod 400 ${ServerKey}

	# Use the private key to create a certificate signing request (CSR). The
	# CSR details don’t need to match the intermediate CA. For server
	# certificates, the Common Name must be a fully qualified domain name (eg,
	# www.example.com), whereas for client certificates it can be any unique
	# identifier (eg, e-mail address). Note that the Common Name cannot be the
	# same as either your root or intermediate certificate.

	echo "create ${ServerCSR}"
	${OPENSSL} req -config intermediate-config.cnf -new -sha256 \
		-extensions alt_names \
		-key ${ServerKey} \
		-out ${ServerCSR} \
		-subj "${SUBJECT}"

	# To create a certificate, use the intermediate CA to sign the CSR. If the
	# certificate is going to be used on a server, use the server_cert
	# extension. If the certificate is going to be used for user
	# authentication, use the usr_cert extension. Certificates are usually
	# given a validity of one year, though a CA will typically give a few days
	# extra for convenience.

	echo "sign ${ServerCert}"
	${OPENSSL} ca -config intermediate-config.cnf -days 375 -notext -md sha256 \
		-extensions v3_intermediate_ca \
		-extensions server_cert \
		-extensions alt_names \
		-in ${ServerCSR} \
		-out ${ServerCert}

	chmod 444 ${ServerCert}

	# Check that the details of the intermediate certificate are correct.

	echo "verify ${ServerCert}"
	${OPENSSL} x509 -noout -text \
		-in ${ServerCert}

	# Verify the server certificate against the intermediate certificate. An OK
	# indicates that the chain of trust is intact.

	echo "verify ${ServerCert} against certs/${CANAME}-chain.cert.pem"
	${OPENSSL} verify -CAfile certs/${CANAME}-chain.cert.pem \
		${ServerCert}

	# https://www.openssl.org/docs/manmaster/apps/pkcs12.html
	# ??? -CAfile or -certfile
	
	echo "Create ${ServerCertP12}"
	${OPENSSL} pkcs12 -export -in ${ServerCert} -inkey ${ServerKey} \
		-out ${ServerCertP12} -name tomcat -passout pass:changeit
#		-CAfile certs/${CANAME}-chain.cert.pem -caname root -chain

	echo "Add root from certs/${CANAME}-chain.cert.pem"
	keytool -import -noprompt -alias root -keystore ${Keystore} -storepass changeit \
		-trustcacerts -file certs/${CANAME}-chain.cert.pem

	echo "Add tomcat from ${ServerCertP12}"
	keytool -importkeystore \
		-deststorepass changeit -destkeypass changeit -destkeystore ${Keystore} \
		-srckeystore ${ServerCertP12} -srcstoretype PKCS12 -srcstorepass changeit \
		-alias tomcat

	echo "List ${Keystore}"
	keytool -list -keystore ${Keystore} -storepass changeit

	popd > /dev/null
}
