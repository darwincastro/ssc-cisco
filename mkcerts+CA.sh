#!/usr/bin/env bash

export "$(grep -v '^#' .env | xargs)"

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW='\033[1;33m'
CYAN="\033[1;36m"
RESET="\033[0m"

[ ! -x /usr/bin/openssl ] && echo -e "${RED}Openssl not found.${RESET}" && exit 1

echo -e "${CYAN}Generating CA key${RESET}"
openssl genrsa -out ca.key && echo -e "\n${YELLOW}Please add the CA information${RESET}"

openssl req -x509 -sha256 -new -nodes -key ca.key -days 365 -out ca.pem -config .ca.cnf \
  && echo -e "${CYAN}Generating Device key${RESET}"

openssl genrsa -des3 -out device.key -passout ${PASS}:cisco 4096 \
  && echo -e "\n${YELLOW}Please add the DEVICE information${RESET}"

openssl req -new -sha256 -key device.key -out device.csr -config .device.cnf -passin \
  ${PASS}:cisco && echo -e "${CYAN}Generating Certificate${RESET}"

echo -e "\n${YELLOW}Please copy the above device FQDN input${RESET}" && read -p 'paste here: ' fqdn

echo -e "\n${YELLOW}Please enter your DEVICE IP${RESET}" && read -p 'IP: ' addr

if [[ $addr =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo $addr > /dev/null 2>&1
else
        echo -e "${RED}Wrong Input.${RESET}"
        exit 1
fi

output="subjectAltName=DNS:${fqdn},IP:${addr}"

echo "$output" > extfile.cnf

openssl x509 -req -sha256 -in device.csr -CA ca.pem -CAkey ca.key -CAcreateserial \
 -days 365 -extfile extfile.cnf -out device.pem > /dev/null 2>&1

rm extfile.cnf \
  device.csr \
  ca.srl \


echo -e "\n${GREEN}Configure the trustpoint in your network device using the following:

crypto pki import <trustpoint name> pem terminal password cisco
 <paste contents of ca.pem>
 <paste contents of device.key>
 <paste contents of device.pem>${RESET}\n"