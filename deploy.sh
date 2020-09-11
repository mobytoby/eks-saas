#!/usr/bin/env bash
#set -x
: "${STACK_NAME:=$1}"
: "${DOMAINNAME:=$2}"

USAGE_PROMPT="Use: $0 <STACKNAME> <DOMAINNAME>"

if [[ -z ${STACK_NAME} ]]; then
  echo "No Stack Name is provided."
  echo $USAGE_PROMPT
  exit 2
fi

if [[ -z ${DOMAINNAME} ]]; then
  echo "No Domain Name is provided."
  echo $USAGE_PROMPT
  exit 2
fi

EKS_REF_ROOT_DIR=$(pwd)

export AWS_REGION=$(aws configure list | grep region | awk '{print $2}')
if [ "X$AWS_REGION" = "X" ]; then
  echo "AWS_REGION not set, check your aws profile or set AWS_DEFAULT_REGION"
  exit 2
fi
echo "AWS Region = $AWS_REGION"

echo "Generating random bucket name with prefix sb-artifacts"
BUCKET_ID=$(dd if=/dev/random bs=8 count=1 2>/dev/null | od -An -tx1 | tr -d ' \t\n')
BUCKET_NAME=eks-ref-artifacts-${BUCKET_ID}
echo $BUCKET_NAME > bucket-name.txt
echo "EKSRefARchBucket: $BUCKET_NAME"
aws s3 mb s3://$BUCKET_NAME
if [ $? -ne 0 ]; then
  echo "Error creating S3 Bucket: $BUCKET_NAME"
  exit 2
fi

S3_BUCKET=s3://$BUCKET_NAME

export AWS_PAGER=""

echo "Copy templates folder to $S3_BUCKET"
echo "WORKING DIRECTORY: $PWD";
echo "EKS_REF_ROOT_DIR: $EKS_REF_ROOT_DIR"
cd resources/templates
for yml in $(ls eks-ref-*.yaml); do
    aws s3 cp $yml s3://$BUCKET_NAME
done

echo "Build and copy Lambda files to $S3_BUCKET"
cd "${EKS_REF_ROOT_DIR}"
echo "WORKING DIRECTORY: $PWD";
echo "EKS_REF_ROOT_DIR: $EKS_REF_ROOT_DIR"
sh ./resources/build_and_copy_lambdas.sh $BUCKET_NAME
if [ $? -ne 0 ]; then
    echo "Error! build_copy_lambdas.sh not successful"
    exit 1
fi

echo "Deploying eks-ref-arch stack"
CREATE_STACK_CMD="aws cloudformation deploy --stack-name ${STACK_NAME} \
--template-file ./resources/templates/root-stack.yaml \
--capabilities CAPABILITY_AUTO_EXPAND CAPABILITY_NAMED_IAM \
--parameter-overrides EKSRefArchBucket=$BUCKET_NAME \
                      DomainName=${DOMAINNAME} \
--disable-rollback true"
cd "${EKS_REF_ROOT_DIR}"
echo $CREATE_STACK_CMD
eval $CREATE_STACK_CMD

if [ $? -ne 0 ]; then
    echo "Error! Cloudformation failed for stack ${STACK_NAME} see AWS CloudFormation console for details."
    exit 2
fi