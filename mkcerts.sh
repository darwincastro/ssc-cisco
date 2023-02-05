#!/bin/sh

export $(grep -v '^#' .env | xargs)

RED="\033[0;31m"
GREEN="\033[0;32m"
RESET="\033[0m"


[ $# != 2 ] && echo "Usage: $0 <collector FQDN> <device FQDN>" && exit 1

[ ! -x /usr/bin/openssl ] && echo "${RED}Openssl not found.${RESET}" && exit 1

(
cat <<EOF
[req]
distinguished_name = req_distinguished_name
prompt = no

[req_distinguished_name]
C = US
ST = California
L = San Jose
O = Cisco
OU = MDT
CN = cisco.com
EOF
) > ca.cnf

openssl genrsa -out ${1}-ca.key > /dev/null 2>&1
openssl req -x509 -new -nodes -key ${1}-ca.key -days 365 -out ${1}-ca.crt -config ca.cnf > /dev/null 2>&1
openssl genrsa -out ${2}-ca.key > /dev/null 2>&1
openssl req -x509 -new -nodes -key ${2}-ca.key -days 365 -out ${2}-ca.crt -config ca.cnf > /dev/null 2>&1

(
cat <<EOF
[req]
distinguished_name = req_distinguished_name
prompt = no
req_extensions = v3_req

[req_distinguished_name]
C = US
ST = California
L = San Jose
O = Cisco
OU = MDTG
CN = ${1}

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${1}
EOF
) > ${1}.cnf

openssl genrsa -out ${1}.key > /dev/null 2>&1
openssl req -new -key ${1}.key -out ${1}.csr -config ${1}.cnf
openssl x509 -req -in ${1}.csr -CA ${1}-ca.crt -CAkey ${1}-ca.key -CAcreateserial -days 365 -out ${1}.crt > /dev/null 2>&1

(
cat <<EOF
[req]
distinguished_name = req_distinguished_name
prompt = no

[req_distinguished_name]
C = US
ST = California
L = San Jose
O = Cisco
OU = MDTG
CN = ${2}
EOF
) > ${2}.cnf


cleanUp () {
    rm ca.cnf \
        $1.cnf \
        $2.cnf \
        $1.csr \
        $1.crt \
        $1.key \
        $1-ca.key \
        $2.csr \
        $2-ca.crt \
        $2-ca.key
}

openssl genrsa -des3 -out ${2}.key -passout ${PASS}:admin > /dev/null 2>&1
openssl req -new -key ${2}.key -out ${2}.csr -config ${2}.cnf -passin ${PASS}:admin
openssl x509 -req -in ${2}.csr -CA ${1}-ca.crt -CAkey ${1}-ca.key -CAcreateserial -days 365 -out ${2}-${1}-ca.crt > /dev/null 2>&1

cleanUp ${1} ${2}


echo "\n${GREEN}Configure the trustpoint using the following:

crypto pki import <trustpoint name 1> pem terminal password admin
 <paste contents of ${1}-ca.crt>
 <paste contents of ${2}.key>
 <paste contents of ${2}-${1}-ca.crt${RESET}\n"
