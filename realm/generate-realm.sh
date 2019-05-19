#!/bin/bash

# ARG1: Realm name
# ARG2: Hostname:port of FAPI Conformance suite server
REALM=${1:-test}
FCSS_HOST_PORT=${2:-localhost:8443}


FCSS_ALIAS=keycloak

DIR=$(cd $(dirname $0); pwd)
cd $DIR

########################################
# Generate client config function
#
# ARG1: Client ID (client1 or client2)
# ARG2: Client Authentication Type (mtls or private_key_jwt)
# ARG3: Request object signature alg
# ARG4: ID/Access Token signature alg
########################################
generateClient() {
    CLIENT_ID="$1-$2-$3-$4"
    [ "$2" = "mtls" ] && CLIENT_AUTH_TYPE="client-x509"
    [ "$2" = "private_key_jwt" ] && CLIENT_AUTH_TYPE="client-jwt"
    ROS_ALG=$3
    TOKEN_ALG=$4
    [ "$2" = "mtls" ] && X509_SUBJECTDN="\"x509.subjectdn\": \"$1\","

    PEM_BODY_FILE=../client_private_keys/pem-body_sig_${ROS_ALG}_${1}-${ROS_ALG}-pub.pem
    CLIENT_PUBLIC_KEY_PEM=`cat $PEM_BODY_FILE`
    CLIENT_PUBLIC_KEY_KID=$1-$ROS_ALG

    cat << EOS
        {
            "clientId": "$CLIENT_ID",
            "bearerOnly": false,
            "standardFlowEnabled": true,
            "implicitFlowEnabled": true,
            "directAccessGrantsEnabled": false,
            "serviceAccountsEnabled": false,
            "publicClient": false,
            "enabled": true,
            "clientAuthenticatorType": "$CLIENT_AUTH_TYPE",
            "fullScopeAllowed": true,
            "protocol": "openid-connect",
            "redirectUris": [
                "https://$FCSS_HOST_PORT/test/a/$FCSS_ALIAS/callback",
                "https://$FCSS_HOST_PORT/plans.html/test/a/$FCSS_ALIAS/callback?dummy1=lorem&dummy2=ipsum"
            ],
            "attributes": {
                $X509_SUBJECTDN
                "request.object.signature.alg": "$ROS_ALG",
                "jwt.credential.kid": "$CLIENT_PUBLIC_KEY_KID",
                "jwt.credential.public.key": "$CLIENT_PUBLIC_KEY_PEM",
                "access.token.signed.response.alg": "$TOKEN_ALG",
                "exclude.session.state.from.auth.response": "false",
                "id.token.signed.response.alg": "$TOKEN_ALG",
                "request.object.required": "request or request_uri",
                "tls.client.certificate.bound.access.tokens": "true"
            }
        }
EOS
}

echo "Generating realm json..."

# For R/W with/ MTLS client with PS256/ES256
CLIENT1_MTLS_PS256_PS256=`generateClient client1 mtls PS256 PS256`
CLIENT2_MTLS_PS256_PS256=`generateClient client2 mtls PS256 PS256`
CLIENT1_MTLS_ES256_ES256=`generateClient client1 mtls ES256 ES256`
CLIENT2_MTLS_ES256_ES256=`generateClient client2 mtls ES256 ES256`

# For R/W with Private Key client with PS256/ES256
CLIENT1_PRIVATE_KEY_JWT_PS256_PS256=`generateClient client1 private_key_jwt PS256 PS256`
CLIENT2_PRIVATE_KEY_JWT_PS256_PS256=`generateClient client2 private_key_jwt PS256 PS256`
CLIENT1_PRIVATE_KEY_JWT_ES256_ES256=`generateClient client1 private_key_jwt ES256 ES256`
CLIENT2_PRIVATE_KEY_JWT_ES256_ES256=`generateClient client2 private_key_jwt ES256 ES256`

# Workaround until keycloak supports PS256/ES256 for request object signature
CLIENT1_MTLS_RS256_PS256=`generateClient client1 mtls RS256 PS256`
CLIENT2_MTLS_RS256_PS256=`generateClient client2 mtls RS256 PS256`
CLIENT1_PRIVATE_KEY_JWT_RS256_PS256=`generateClient client1 private_key_jwt RS256 PS256`
CLIENT2_PRIVATE_KEY_JWT_RS256_PS256=`generateClient client2 private_key_jwt RS256 PS256`


cat << EOS > realm.json
{
    "realm": "$REALM",
    "enabled": true,
    "sslRequired": "external",
    "registrationAllowed": false,
    "requiredCredentials": [ "password" ],
    "users": [
        {
            "username": "john",
            "enabled": true,
            "credentials": [
                {
                    "type": "password",
                    "value": "john"
                }
            ]
        }
    ],
    "clients": [
$CLIENT1_MTLS_PS256_PS256,
$CLIENT2_MTLS_PS256_PS256,
$CLIENT1_MTLS_ES256_ES256,
$CLIENT2_MTLS_ES256_ES256,
$CLIENT1_PRIVATE_KEY_JWT_PS256_PS256,
$CLIENT2_PRIVATE_KEY_JWT_PS256_PS256,
$CLIENT1_PRIVATE_KEY_JWT_ES256_ES256,
$CLIENT2_PRIVATE_KEY_JWT_ES256_ES256,
$CLIENT1_MTLS_RS256_PS256,
$CLIENT2_MTLS_RS256_PS256,
$CLIENT1_PRIVATE_KEY_JWT_RS256_PS256,
$CLIENT2_PRIVATE_KEY_JWT_RS256_PS256
    ],
    "components": {
        "org.keycloak.keys.KeyProvider": [
            {
                "name": "aes-generated",
                "providerId": "aes-generated",
                "subComponents": {},
                "config": {
                    "priority": [
                        "100"
                    ]
                }
            },
            {
                "name": "rsa-generated",
                "providerId": "rsa-generated",
                "subComponents": {},
                "config": {
                    "priority": [
                        "100"
                    ]
                }
            },
            {
                "name": "hmac-generated",
                "providerId": "hmac-generated",
                "subComponents": {},
                "config": {
                    "priority": [
                        "100"
                    ],
                    "algorithm": [
                        "HS256"
                    ]
                }
            },
            {
                "name": "PS256",
                "providerId": "rsa-generated",
                "subComponents": {},
                "config": {
                    "keySize": [
                        "2048"
                    ],
                    "active": [
                        "true"
                    ],
                    "priority": [
                        "100"
                    ],
                    "enabled": [
                        "true"
                    ],
                    "algorithm": [
                        "PS256"
                    ]
                }
            },
            {
                "name": "ES256",
                "providerId": "ecdsa-generated",
                "subComponents": {},
                "config": {
                    "ecdsaEllipticCurveKey": [
                        "P-256"
                    ],
                    "active": [
                        "true"
                    ],
                    "priority": [
                        "100"
                    ],
                    "enabled": [
                        "true"
                    ]
                }
            }
        ]
    }
}
EOS
