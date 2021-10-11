[ req ]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn

[ dn ]
C = "EE"
ST = "Harju"
L = "Tallinn"
O = "Self"
OU = "Tallinn"
CN = "localhost"

[ v3_ext ]
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment,digitalSignature
extendedKeyUsage=serverAuth,clientAuth
