#!/bin/bash
set -e

source ./newServerCertKeystore.sh

for tld in com net io; do

# -subj uses / as a separater, and white space is not tolerated, if you
# add white space, a parsing error (e.g., "Subject Attribute CN has no
# known NID, skipped") is displayed
# subjectAlt is in short form (key:value,key:value...)

subj="/C=US/ST=California/L=Redwood City/O=[my org]/OU=lab/\
CN=wildcard.lab.example.${tld}/emailAddress=security@example.com"
subjectAltName="DNS.1:*.lab.example.${tld}"
newServerCert "lab" "${subj}" "${subjectAltName}" "lab.example.${tld}"

for labName in pepperoni bacon sausage ham chicken mushroom onion olive; do

subj="/C=US/ST=California/L=Redwood City/O=[my org]/OU=${labName}/\
CN=*.${labName}.example.${tld}/emailAddress=security@example.com"
subjectAltName="DNS.1:*.${labName}.example.${tld}, \
	DNS.2:*.pcfsys.${labName}.example.${tld}, \
	DNS.3:*.pcfapps.${labName}.example.${tld}, \
	DNS.4:*.demo.${labName}.example.${tld}, \
	DNS.5:*.customer.${labName}.example.${tld}, \
	DNS.6:*.login.pcfsys.${labName}.example.${tld}, \
	DNS.7:*.uaa.pcfsys.${labName}.example.${tld}"
newServerCert "${labName}" "${subj}" "${subjectAltName}" "wildcard.${labName}.example.${tld}"

done
done
