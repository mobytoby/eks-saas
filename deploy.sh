echo "Generating random bucket name with prefix sb-artifacts"
BUCKET_ID=$(dd if=/dev/random bs=8 count=1 2>/dev/null | od -An -tx1 | tr -d ' \t\n')
BUCKET_NAME=sb-${ENVIRONMENT}-artifacts-${BUCKET_ID}
echo $BUCKET_NAME > bucket-name.txt
echo "SaaSBoostBucket: $BUCKET_NAME"
aws s3 mb s3://$BUCKET_NAME
if [ $? -ne 0 ]; then
  echo "Error creating S3 Bucket: $BUCKET_NAME"
  exit 2
fi

S3_BUCKET=s3://$BUCKET_NAME

echo "Copy templates folder to $S3_BUCKET"
cd templates
for yml in $(ls eks-ref-*.yaml); do
    aws s3 cp $yml s3://$BUCKET_NAME
done

echo "Deploying "