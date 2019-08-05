openssl ec -in  34efd801cdafee38c1b3ba8fa0dfe6db02453cbb93993a802e69867aec003156_sk --noout --text
read EC key
Private-Key: (256 bit)
priv:
    5a:a1:3d:84:75:57:4d:53:f8:cc:a8:5c:e0:b7:a6:
    80:03:a4:d1:51:7d:43:6b:e4:c4:71:fa:91:ef:cd:
    7b:d2
pub:
    04:20:14:92:7c:e1:bf:dc:2f:06:fa:4a:da:ec:35: ---> 04 uncompress
    78:f6:f0:66:5a:12:66:ec:7f:8e:00:d2:e5:b3:af:
    1a:ab:62:ac:4a:3c:8a:86:0c:d7:b7:89:2d:a4:5e:
    21:47:5f:b9:7c:d3:0c:dc:39:7e:7e:fd:c2:eb:1a:
    f7:47:01:35:a0
ASN1 OID: prime256v1  --->  use..
NIST CURVE: P-256

From it you may gather that using 256 bit ECDSA key should be enough for next 10-20 years
prime256v1

openssl dsaparam -out dsaparam.pem 256
openssl gendsa -out ca-private.pem dsaparam.pem

