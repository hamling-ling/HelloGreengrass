#!/bin/bash

TEMPFILE=/tmp/tempout_provision_coredevice
CERTS_DIR=greengrass-v2-certs

function CheckCommand() {
    cmd=$1
    which $cmd
    if [ ! $? ]; then
        echo command $cmd not installed
        exit 1
    fi
}

function DeleteAll() {
    PRINCIPALS=$(aws iot list-thing-principals --thing-name $THING_NAME | jq -r '.principals[]')
    for pri in $PRINCIPALS
    do
        echo principal=$pri
        aws iot detach-policy --policy-name $TES_ROLE_ALIAS_POLICY_NAME --target $pri
        if [ $? = 0 ]; then
            echo $TES_ROLE_ALIAS_POLICY_NAME detatched from principal $pri
        fi
        aws iot detach-policy --policy-name $TES_ROLE_ACCESS_NAME --target $pri
        if [ $? = 0 ]; then
            echo $TES_ROLE_ACCESS_NAME detatched from principal $pri
        fi
        aws iot detach-policy --policy-name $THING_POLICY_NAME --target $pri
        if [ $? = 0 ]; then
            echo $THING_POLICY_NAME detatched from principal $pri
        fi

        certId=$(echo $pri | sed "s/arn.*cert\///g")
        echo certId=$certId
        aws iot update-certificate --certificate-id $certId --new-status INACTIVE
        if [ $? = 0 ]; then
            echo $certId inactivated
        fi

        aws iot detach-thing-principal --thing-name $THING_NAME --principal $pri
        if [ $? = 0 ]; then
            echo $pri detatched from thing $THING_NAME
        fi
    done
    
    AccessArn=$(aws iam list-policies --query "Policies[?PolicyName=='$TES_ROLE_ACCESS_NAME'].Arn" --output text)
    echo detaching role policy $TES_ROLE_NAME
    aws iam detach-role-policy --role-name $TES_ROLE_NAME --policy-arn $AccessArn

    echo deleting policy $AccessArn
    aws iam delete-policy --policy-arn $AccessArn
    if [ $? = 0 ]; then
        echo $AccessArn deleted
    fi

    echo deleting $TES_ROLE_ALIAS_POLICY_NAME
    aws iot delete-policy --policy-name $TES_ROLE_ALIAS_POLICY_NAME #> /dev/null 2>&1
    if [ $? = 0 ]; then
        echo $TES_ROLE_ALIAS_POLICY_NAME deleted
    fi

    echo deleting $THING_POLICY_NAME
    aws iot delete-policy --policy-name $THING_POLICY_NAME #> /dev/null 2>&1
    if [ $? = 0 ]; then
        echo $THING_POLICY_NAME deleted
    fi

    echo deleting $TES_ROLE_ALIAS_NAME
    aws iot delete-role-alias --role-alias $TES_ROLE_ALIAS_NAME #> /dev/null 2>&1
    if [ $? = 0 ]; then
        echo $TES_ROLE_ALIAS_NAME deleted
    fi

    echo deleting role $TES_ROLE_NAME
    aws iam delete-role --role-name $TES_ROLE_NAME #> /dev/null 2>&1
    if [ $? = 0 ]; then
        echo $TES_ROLE_NAME deleted
    fi

    echo deleting thing-group $THING_GROUP_NAME
    aws iot delete-thing-group --thing-group-name $THING_GROUP_NAME #> /dev/null 2>&1
    if [ $? = 0 ]; then
        echo $THING_GROUP_NAME deleted
    fi

    for pri in $PRINCIPALS
    do
        echo deleting principal=$pri
        aws iot delete-certificate --certificate-id $certId
        if [ $? = 0 ]; then
            echo $certId deleted
        fi
    done

    aws iot delete-thing --thing-name $THING_NAME #> /dev/null 2>&1
    if [ $? = 0 ]; then
        echo $THING_NAME deleted
    fi

    echo you probably need to wait for a while to the deletion takes effect
}

###############################################################################
# Check input arguments
###############################################################################
Clean=False
for arg in "$*"
do
    echo "argument-$i is: $arg";
    if [ "$arg" = "clean" ]; then
        Clean=True
    fi
done
echo "Clean: $Clean";

if [ -f .env ]; then
  export $(cat .env | xargs)
else
    echo ".env not found"
    exit 1
fi

CheckCommand aws
CheckCommand jq

if [ "$Clean" = "True" ]; then
    DeleteAll
    exit 0
fi

DataEndpoint=$(aws iot describe-endpoint --endpoint-type iot:Data-ATS | jq -r '.endpointAddress')
echo DataEndpoint=$DataEndpoint

CredEndpoint=$(aws iot describe-endpoint --endpoint-type iot:CredentialProvider | jq -r '.endpointAddress')
echo CredEndpoint=$CredEndpoint

###############################################################################
# Create thing and group
###############################################################################
aws iot describe-thing --thing-name $THING_NAME > /dev/null 2>&1
if [ $? = 0 ]; then
    echo thing $THING_NAME already exists
    exit 1
fi

# 消すときは
# aws iot delete-thing --thing-name $THING_NAME
ThingArn=$(aws iot create-thing --thing-name $THING_NAME | jq -r '.thingArn')
echo ThingARN=$ThingArn

aws iot describe-thing-group --thing-group-name $THING_GROUP_NAME > /dev/null 2>&1
if [ $? = 0 ]; then
    echo thing group $THING_GROUP_NAME already exists
    exit 1
fi
ThingGroupArn=$(aws iot create-thing-group --thing-group-name $THING_GROUP_NAME | jq -r '.thingGroupArn')
echo ThingGroupArn=$ThingGroupArn

aws iot add-thing-to-thing-group --thing-name $THING_NAME --thing-group-name $THING_GROUP_NAME > /dev/null 2>&1
if [ $? != 0 ]; then
    echo failed to add thing $THING_NAME to group $THING_GROUP_NAME
    exit 1
fi
echo thing $THING_NAME attached to group $THING_GROUP_NAME

mkdir -p $CERTS_DIR
CertificateArn=$(aws iot create-keys-and-certificate --set-as-active --certificate-pem-outfile $CERTS_DIR/device.pem.crt --public-key-outfile $CERTS_DIR/public.pem.key --private-key-outfile $CERTS_DIR/private.pem.key | jq -r '.certificateArn')
echo CertificateArn=$CertificateArn

# Download Root Certificate
curl -o $CERTS_DIR/AmazonRootCA1.pem https://www.amazontrust.com/repository/AmazonRootCA1.pem

aws iot attach-thing-principal --thing-name $THING_NAME --principal $CertificateArn
if [ $? != 0 ]; then
    echo failed attach thing principal thing-name=$THING_NAME , principal=$CertificateArn
    exit 1
fi

aws iot create-policy --policy-name $THING_POLICY_NAME --policy-document file://policy_json/greengrass-v2-iot-policy.json
if [ $? != 0 ]; then
    echo failed create thing policy name=$THING_POLICY_NAME
    exit 1
fi

aws iot attach-policy --policy-name $THING_POLICY_NAME --target $CertificateArn
if [ $? != 0 ]; then
    echo failed attach thing policy name=$THING_POLICY_NAME to target $CertificateArn
    exit 1
fi

###############################################################################
# Create roles
###############################################################################
RoleArn=$(aws iam create-role --role-name $TES_ROLE_NAME --assume-role-policy-document file://policy_json/device-role-trust-policy.json | jq -r '.Role.Arn')
echo RoleArn=$RoleArn

echo aws iam create-policy --policy-name $TES_ROLE_ACCESS_NAME --policy-document file://policy_json/device-role-access-policy.json
PolicyArn=$(aws iam create-policy --policy-name $TES_ROLE_ACCESS_NAME --policy-document file://policy_json/device-role-access-policy.json | jq -r '.Policy.Arn')
echo PolicyArn=$PolicyArn
$(aws iam attach-role-policy --role-name $TES_ROLE_NAME --policy-arn $PolicyArn)
if [ $? != 0 ]; then
    echo failed attach role policy role-name=$TES_ROLE_NAME , policy-arn=$PolicyArn
    exit 1
fi

echo aws iot create-role-alias --role-alias $TES_ROLE_ALIAS_NAME --role-arn $RoleArn
RoleAliasArn=$(aws iot create-role-alias --role-alias $TES_ROLE_ALIAS_NAME --role-arn $RoleArn | jq -r '.roleAliasArn')
if [ "$RoleAliasArn" = "" ]; then
    echo failed to create role alias $TES_ROLE_ALIAS_NAME with arn $RoleArn
    exit 1
fi

REPLACED_JSON=policy_json/greengrass-v2-iot-role-alias-policy_replaced.json
sed "s#YOUR_TOKEN_EXCHANGE_ROLE_ALIAS_ARN#$RoleAliasArn#g" policy_json/greengrass-v2-iot-role-alias-policy.json > $REPLACED_JSON
aws iot create-policy --policy-name $TES_ROLE_ALIAS_POLICY_NAME --policy-document file://$REPLACED_JSON
if [ $? != 0 ]; then
    echo failed to create role alias policy $TES_ROLE_ALIAS_NAME with arn $RoleArn
    exit 1
fi

aws iot attach-policy --policy-name $TES_ROLE_ALIAS_POLICY_NAME --target $CertificateArn
if [ $? != 0 ]; then
    echo failed to attach role alias policy $TES_ROLE_ALIAS_POLICY_NAME with certificate arn $CertificateArn
    exit 1
fi
