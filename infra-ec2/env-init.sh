############################################
# INITIALIZE LAB PARAMETERS AND VARIABLES  #
############################################
INFRA_DIR=/home/codespace/seis745-dle-labs/infra-ec2
source ${INFRA_DIR}/lab-params.sh

############################################
# CREATE LAB INFRASTRUCTURE USING AWS CLI  #
############################################

# Use existing or create new S3 bucket
S3_BUCKET_NAME=`aws s3api list-buckets --query "Buckets[0].Name" --output text`
if [ "${S3_BUCKET_NAME}" == None ]; 
then
    S3_BUCKET_NAME="s3-dle-`uuidgen`"
    aws s3api create-bucket --bucket ${S3_BUCKET_NAME} --no-cli-pager
fi

# Turn input IP address into CIDR range
CIDR_SUFFIX=
if [ "${CLIENT_IP}" = "0.0.0.0" ]; then
    CIDR_SUFFIX="/0"
else
    CIDR_SUFFIX="/32"
fi

aws ec2 create-key-pair \
    --key-name "${LAB_KEY_NAME}" \
    --query 'KeyMaterial' \
    --output text > "${LAB_KEY_FILE}"

chmod 400 "${LAB_KEY_FILE}" #change permissions

aws ec2 create-security-group --group-name "${LAB_EC2_NAME}-sg" --description "Nifi lab security group" --no-cli-pager
SECURITY_GROUP_ID=`aws ec2 describe-security-groups --group-names "${LAB_EC2_NAME}-sg" --query "SecurityGroups | [0].GroupId" --output text`

aws ec2 authorize-security-group-ingress --group-id ${SECURITY_GROUP_ID} --protocol tcp --port 9443 --cidr "${CLIENT_IP}${CIDR_SUFFIX}" --no-cli-pager
aws ec2 authorize-security-group-ingress --group-id ${SECURITY_GROUP_ID} --protocol tcp --port 22 --cidr "${CODESPACE_IP}/32" --no-cli-pager

aws ec2 run-instances --image-id ami-06e46074ae430fba6 --count 1 --instance-type t2.large --key-name ${LAB_KEY_NAME} --security-group-ids ${SECURITY_GROUP_ID} --iam-instance-profile Name=LabInstanceProfile --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${LAB_EC2_NAME}}]" --output text --no-cli-pager

EC2_INSTANCE_ID=`aws ec2 describe-instances --filters "Name=tag:Name,Values=${LAB_EC2_NAME}" "Name=instance-state-name,Values=pending,running,shutting-down,stopping,stopped" --query 'Reservations[*].Instances[*].InstanceId | [0] | [0]' --output text`

aws ec2 wait instance-running --instance-ids ${EC2_INSTANCE_ID}

aws ec2 modify-instance-metadata-options \
    --instance-id ${EC2_INSTANCE_ID} \
    --http-put-response-hop-limit 2 \
    --http-endpoint enabled