#!/bin/bash
set -euo pipefail
cd $(dirname "${0}")

############################## BEGIN DECLARATIONS ##############################

source "./x.vars"

function generate_root_files {
  # Private Key
  openssl genpkey \
    -algorithm "RSA" \
    -pkeyopt "rsa_keygen_bits:2048" \
    -out "${ROOT}.key"

  # Public Cert
  openssl req -x509 -new -nodes -sha256 \
    -key "${ROOT}.key" \
    -days "${DAYS_1_YEAR}" \
    -out "${ROOT}.crt" \
    -subj "${SUBJECT_ROOT}"
}

function generate_intermediate_files {
  # Private Key
  openssl genpkey \
    -algorithm "RSA" \
    -pkeyopt "rsa_keygen_bits:2048" \
    -out "${INTERMEDIATE}.key"

  # CSR
  openssl req -new -sha256 \
    -key "${INTERMEDIATE}.key" \
    -out "${INTERMEDIATE}.csr" \
    -subj "${SUBJECT_INTERMEDIATE}"

  # Extension
  echo "${EXTENSION_INTERMEDIATE}" > "${INTERMEDIATE}.ext"

  # Public Cert
  openssl x509 -req -CAcreateserial -sha256 \
    -in "${INTERMEDIATE}.csr" \
    -CA "${ROOT}.crt" \
    -CAkey "${ROOT}.key" \
    -out "${INTERMEDIATE}.crt" \
    -days "${DAYS_1_MONTH}" \
    -extfile "${INTERMEDIATE}.ext"
}

function generate_server_files {
  # Private Key
  openssl genpkey \
    -algorithm "RSA" \
    -pkeyopt "rsa_keygen_bits:2048" \
    -out "${SERVER}.key"

  # CSR
  openssl req -new -sha256 \
    -key "${SERVER}.key" \
    -out "${SERVER}.csr" \
    -subj "${SUBJECT_SERVER}"

  # Extension
  echo "${EXTENSION_SERVER}" > "${SERVER}.ext"

  # Public Cert
  openssl x509 -req -CAcreateserial -sha256 \
    -in "${SERVER}.csr" \
    -CA "${INTERMEDIATE}.crt" \
    -CAkey "${INTERMEDIATE}.key" \
    -out "${SERVER}.crt" \
    -days "${DAYS_1_WEEK}" \
    -extfile "${SERVER}.ext"

  verify_certs
}

function verify_certs {
  openssl verify \
    -CAfile "${ROOT}.crt" \
    -untrusted "${INTERMEDIATE}.crt" \
    "${SERVER}.crt"
}

function generate_chain_file {
  cat "${SERVER}.crt" "${INTERMEDIATE}.crt" "${ROOT}.crt" > "${CHAIN}.crt"
}

function archive_files {
  mkdir -p "./${ARCHIVED}"

  cp "${SERVER}.key" "./${ARCHIVED}/"
  cp "${CHAIN}.crt" "./${ARCHIVED}/"

  rm -f \
    "./${SERVER}.key" \
    "./${SERVER}.crt" \
    "./${SERVER}.csr" \
    "./${SERVER}.ext"
  
  rm -f "./${CHAIN}.crt"
}

function cleanup {
  rm -f \
    "./${ROOT}.key" \
    "./${ROOT}.crt" \
    "./${ROOT}.srl"

  rm -f \
    "./${INTERMEDIATE}.key" \
    "./${INTERMEDIATE}.crt" \
    "./${INTERMEDIATE}.csr" \
    "./${INTERMEDIATE}.ext" \
    "./${INTERMEDIATE}.srl"
}

############################### BEGIN EXECUTION ################################

generate_root_files
generate_intermediate_files

for i in {1..5}; do
  i=$(printf "%02d\n" "$i")

  # Sleep a few seconds to create distinct timestamps on the certificates
  sleep ${SLEEP_SECONDS}
  
  SERVER="server${i}"
  CHAIN="chain${i}"
  ARCHIVED="archived/${i}"

  generate_server_files
  generate_chain_file
  archive_files
done

cleanup
