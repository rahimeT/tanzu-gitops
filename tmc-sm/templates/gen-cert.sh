#!/bin/bash

echo gen-cert
export SUBJ="/C=TR/ST=Istanbul/L=Istanbul/O=Customer, Inc./OU=IT/CN=${DOMAIN}"
openssl genrsa -des3 -out tmc-ca.key -passout pass:1234 4096
cat > ca.conf <<-EOF
[req]
distinguished_name = req_distinguished_name
[req_distinguished_name]
C = TR
ST = Istanbul
L = Istanbul
O = Customer, Inc.
OU = IT
CN = $DOMAIN
[ca]
basicConstraints=CA:TRUE
keyUsage=critical, digitalSignature, keyCertSign, cRLSign
EOF
openssl req -x509 -new -nodes -key tmc-ca.key -sha256 -days 1024 -passin pass:1234 -subj "$SUBJ" -extensions ca -config ca.conf -out tmc-ca.crt
openssl genrsa -out server-app.key 4096
openssl req -sha512 -new \
      -subj "$SUBJ" \
      -key server-app.key \
      -out server-app.csr
cat > v3.ext <<-EOF
  authorityKeyIdentifier=keyid,issuer
  basicConstraints=CA:FALSE
  keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
  extendedKeyUsage = serverAuth
  subjectAltName = @alt_names
  [alt_names]
  DNS.1=${DOMAIN}
EOF
openssl x509 -req -sha512 -days 3650 \
      -passin pass:1234 \
      -extfile v3.ext \
      -CA tmc-ca.crt -CAkey tmc-ca.key -CAcreateserial \
      -in server-app.csr \
      -out server-app.crt
openssl rsa -in tmc-ca.key -out tmc-ca-no-pass.key -passin pass:1234
md5crt=$(openssl x509 -modulus -noout -in server-app.crt | openssl md5|awk '{print $2}')
md5key=$(openssl rsa -noout -modulus -in server-app.key | openssl md5|awk '{print $2}')
echo $md5crt
echo $md5key
if [ "$md5crt" == "$md5key" ] ;
    then
        echo "Certificates generated successfully"
        #exit 0
    else
        echo "Certificate md5's mismatch. Error."
        exit 1
fi