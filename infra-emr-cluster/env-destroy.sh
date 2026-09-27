############################################
# INITIALIZE LAB PARAMETERS AND VARIABLES  #
############################################
source ./infra/lab-params.sh

############################################
# DELETE LAB RESOURCES                     #
############################################
aws cloudformation delete-stack --stack-name "${LAB_STACK_NAME}"
aws ec2 delete-key-pair --key-name "${LAB_KEY_NAME}"
rm -f "${LAB_KEY_FILE}"
aws cloudformation wait stack-delete-complete --stack-name "${LAB_STACK_NAME}"