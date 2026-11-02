############################################
# INITIALIZE LAB PARAMETERS AND VARIABLES  #
############################################
INFRA_DIR=/home/codespace/seis745-dle-labs/infra-ec2
source ${INFRA_DIR}/lab-params.sh

EC2_INSTANCE_ID=`aws ec2 describe-instances --filters "Name=tag:Name,Values=${LAB_EC2_NAME}" "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].InstanceId | [0] | [0]' --output text`

############################################
# DELETE LAB RESOURCES                     #
############################################
aws ec2 terminate-instances --instance-ids ${EC2_INSTANCE_ID}  --no-cli-pager
aws ec2 delete-key-pair --key-name "${LAB_KEY_NAME}"  --no-cli-pager
rm -f "${LAB_KEY_FILE}"
aws ec2 delete-security-group --group-name ${LAB_EC2_NAME}-sg  --no-cli-pager
