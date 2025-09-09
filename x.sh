#!/bin/bash
set -euo pipefail
cd $(dirname "${0}")

############################## BEGIN DECLARATIONS ##############################

source "./x.vars"

function generate_root_files {
  # Private Key
  openssl genpkey -aes256 \
    -algorithm "RSA" \
    -pkeyopt "rsa_keygen_bits:4096" \
    -out "root.key" \
    -pass "pass:${PASSPHRASE_ROOT}"

  # Public Cert
  openssl req -x509 -new -nodes -sha256 \
    -key "${ROOT}.key" \
    -days "${DAYS_1_YEAR}" \
    -out "${ROOT}.crt" \
    -subj "${SUBJECT_ROOT}" \
    -passin "pass:${PASSPHRASE_ROOT}"
}

function generate_intermediate_files {
  # Private Key
  openssl genpkey -aes256 \
    -algorithm "RSA" \
    -pkeyopt "rsa_keygen_bits:4096" \
    -out "intermediate.key" \
    -pass "pass:${PASSPHRASE_INTERMEDIATE}"

  # CSR
  openssl req -new -sha256 \
    -key "${INTERMEDIATE}.key" \
    -out "${INTERMEDIATE}.csr" \
    -subj "${SUBJECT_INTERMEDIATE}" \
    -passin "pass:${PASSPHRASE_INTERMEDIATE}"

  # Extension
  echo "${EXTENSION_INTERMEDIATE}" > "${INTERMEDIATE}.ext"

  # Public Cert
  openssl x509 -req -CAcreateserial -sha256 \
    -in "${INTERMEDIATE}.csr" \
    -CA "${ROOT}.crt" \
    -CAkey "${ROOT}.key" \
    -out "${INTERMEDIATE}.crt" \
    -days "${DAYS_1_MONTH}" \
    -extfile "${INTERMEDIATE}.ext" \
    -passin "pass:${PASSPHRASE_ROOT}"
}

function generate_server_files {
  # Private Key
  openssl genpkey -aes256 \
    -algorithm "RSA" \
    -pkeyopt "rsa_keygen_bits:4096" \
    -out "${SERVER}.key" \
    -pass "pass:${PASSPHRASE_SERVER}"

  # CSR
  openssl req -new -sha256 \
    -key "${SERVER}.key" \
    -out "${SERVER}.csr" \
    -subj "${SUBJECT_SERVER}" \
    -passin "pass:${PASSPHRASE_SERVER}"

  # Extension
  echo "${EXTENSION_SERVER}" > "${SERVER}.ext"

  # Public Cert
  openssl x509 -req -CAcreateserial -sha256 \
    -in "${SERVER}.csr" \
    -CA "${INTERMEDIATE}.crt" \
    -CAkey "${INTERMEDIATE}.key" \
    -out "${SERVER}.crt" \
    -days "${DAYS_1_WEEK}" \
    -extfile "${SERVER}.ext" \
    -passin "pass:${PASSPHRASE_INTERMEDIATE}"

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
  
  SERVER="server${i}"
  CHAIN="chain${i}"
  ARCHIVED="archived${i}"

  generate_server_files
  generate_chain_file
  archive_files

  # sleep 5
done

cleanup
