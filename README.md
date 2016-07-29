## MyCA
MyCA is a set of scripts and a convention for a directory structure to build a root and set of intermediate certificate authorities.

The scripts assume you will build the version of OpenSSL you want to use for your CA. Then you build your CAs. Finally, you create your certificates.

This work stands on the shoulders of others, and the scripts contain credits for the predecessor used.
## openssl-build.sh
Place this script in a directory for the version of OpenSSL you want (e.g., `Openssl-1.0.2g`). From this directory, run the script. You may need to install the XCode CLI tools if not already done.
## LocalCAs/buildca.sh
This script will create a Root CA and a list of Intermediate CAs. For the purpose of publishing the script, I chose pizza toppings for the Intermediate names.

Make sure you change the values in the `subj` to your values (e.g., `[my org]` becomes `ExampleCo`).
## LocalCAs/Config
There are different OpenSSL configurations for the Root and Intermediate CAs. Do your homework before making changes. One can do a lot with the config, so consider these a starting point for your needs.
## LocalCAs/newserverauth.sh
This script creates a set of wildcard certificates for use with [Pivotal Cloud Foundry](https://pivotal.io/platform). We assume `example` is registered in multiple top level domains, and we are running a lab in a subdomain for each of our pizza toppings.

This script will be a starting place for the layout of your certificate needs. For example, you may have a list of certificates, where each has its own Subject Alternate Names, for each of your Intermediate CAs. In this case, you will probably change the script to read the list from a file.

Once again, make sure you change the values in the `subj` to your values (e.g., `[my org]` becomes `ExampleCo`).
## LocalCAs/newServerCertKeystore.sh
The function `newServerCert` is broken out as a separate file. Environment variables in this function correspond to references in LocalCAs/Config. A key, certificate, and Java keystore are created, as well as the trust chain. All the parts one needs for setting up a server.