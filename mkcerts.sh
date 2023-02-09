#!/bin/sh

export $(grep -v '^#' .env | xargs)

RED="\033[0;31m"
GREEN="\033[0;32m"
RESET="\033[0m"


[ $# != 1 ] && echo "Usage: $0 <device FQDN>" && exit 1

[ ! -x /usr/bin/openssl ] && echo "${RED}Openssl not found.${RESET}" && exit 1

(
cat <<EOF
[req]
distinguished_name = req_distinguished_name
prompt = no

[req_distinguished_name]
C = Country
ST = State
L = City
O = Company_Name
OU = CA
CN = example.com
EOF
) > ca.cnf

openssl genrsa -aes256 -out ${1}-ca.key > /dev/null 2>&1
openssl req -x509 -sha256 -new -nodes -key ${1}-ca.key -days 365 -out ${1}-ca.crt -config ca.cnf > /dev/null 2>&1

(
cat <<EOF
[req]
distinguished_name = req_distinguished_name
prompt = no
req_extensions = v3_req

[req_distinguished_name]
C = Country
ST = State
L = City
O = Company_Name
OU = Device
CN = ${2}

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${2}
EOF
) > ${2}.cnf

openssl req genrsa -des3 -out ${2}.key -passout ${PASS}:cisco > /dev/null 2>&1
openssl req -new -sha256 -key ${2}.key -out ${2}.csr -config ${2}.cnf -passin ${PASS}:cisco
openssl x509 -req -sha256 -in ${2}.csr -CA ${1}-ca.crt -CAkey ${1}-ca.key -CAcreateserial -days 365 -out ${2}-.crt > /dev/null 2>&1

#cleanUp () {
#   rm ca.cnf \
#        $1.cnf \
#        $2.cnf \
#        $1.csr \
#        $1.crt \
#        $1.key \
#       $1-ca.key \
#        $2.csr \
#       $2-ca.crt \
#        $2-ca.key
#}


#cleanUp ${1} ${2}


echo "\n${GREEN}Configure the trustpoint using the following:

crypto pki import <trustpoint name 1> pem terminal password cisco
 <paste contents of ${1}-ca.crt>
 <paste contents of ${2}.key>
 <paste contents of ${2}-.crt${RESET}\n"
