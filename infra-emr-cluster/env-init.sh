############################################
# INITIALIZE LAB PARAMETERS AND VARIABLES  #
############################################
source infra/lab-params.sh

############################################
# USE EXISTING OR CREATE NEW S3 BUCKET     #
############################################
S3_BUCKET_NAME=`aws s3api list-buckets --query "Buckets[0].Name" --output text`

if [ "${S3_BUCKET_NAME}" == None ]; 
then
    S3_BUCKET_NAME="s3-dle-`uuidgen`"
    aws s3api create-bucket --bucket ${S3_BUCKET_NAME} --no-cli-pager
fi

CIDR_SUFFIX=
if [ "${CLIENT_IP}" = "0.0.0.0" ]; then
    CIDR_SUFFIX="/0"
else
    CIDR_SUFFIX="/32"
fi

aws ec2 create-key-pair \
    --key-name "${LAB_KEY_NAME}" \
    --query 'KeyMaterial' \
    --output text >> "${LAB_KEY_FILE}"

chmod 400 "${LAB_KEY_FILE}" #change permissions

aws cloudformation deploy \
  --template-file ./infra/template.json \
  --stack-name "${LAB_STACK_NAME}" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    Name="${LAB_ENV_NAME}" \
    BucketName="${S3_BUCKET_NAME}" \
    InstanceType=m4.large \
    ClientIP="${CLIENT_IP}${CIDR_SUFFIX}" \
    CodespaceIP="${CODESPACE_IP}/32" \
    BucketName="${S3_BUCKET_NAME}" \
    InstanceCount=2 \
    KeyPairName="${LAB_KEY_NAME}" \
    ReleaseLabel="emr-7.12.0" \
    EbsRootVolumeSize=32
