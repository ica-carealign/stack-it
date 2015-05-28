#!/bin/bash

Usage() {
  local message=$1
  local code=$2

  if [ "${message}" != "" ]; then
    echo "${message}"
  fi

  echo
  echo "$0 -f <json file> -n <stack_name> [-d <stack description>]"
  echo "   [-u <stack-it url>] [-h] [-v]"
  echo
  echo "  -h Print this help message"
  echo "  -f JSON formatted file listing all instance data"
  echo "  -n Stack name"
  echo "  -d Stack description"
  echo "  -u StackIt URL"
  echo "  -v Enable debugging output"
  echo

  exit ${code}
}

INPUT_FILE=''
STACK_DESCRIPTION='CLI Initiated Stack'
STACK_NAME=''
STACKIT_URL='http://localhost'

DEBUG=0

while getopts "f:d:n:u:vh" OPTION
do
  case $OPTION in
    f) INPUT_FILE=$OPTARG;;
    d) STACK_DESCRIPTION=$OPTARG;;
    n) STACK_NAME=$OPTARG;;
    u) STACKIT_URL=$OPTARG;;
    v) DEBUG=1;;
    h) Usage '' 0;;
  esac
done

if [ ! -f "${INPUT_FILE}" ]; then
  Usage '-f required' 1
fi

if [ "${STACK_NAME}" == "" ]; then
  Usage '-n required' 1
fi

# Remove all whitespace...
FORMATTED_STRING=`cat ${INPUT_FILE} | tr -d '\040\011\012\015'`

# Replace the stack name inside the instance names
FORMATTED_STRING=`echo ${FORMATTED_STRING} | sed -e "s/\"CmdLineTest/\"$STACK_NAME/g"`

# Escape all double quotes...
FORMATTED_STRING=`echo ${FORMATTED_STRING} | sed -e 's/"/\\\"/g'`

# Add double quotes before all opening braces...
FORMATTED_STRING=`echo ${FORMATTED_STRING} | sed -e 's/{/"{/g'`

# Add double quotes after all closing braces...
FORMATTED_STRING=`echo ${FORMATTED_STRING} | sed -e 's/}/}"/g'`

if [ ${DEBUG} -eq 1 ]; then
  echo $FORMATTED_STRING
fi

curl --data-urlencode "StackDescription=${STACK_DESCRIPTION}" \
     --data-urlencode "StackName=${STACK_NAME}"               \
     --data-urlencode "Instances=${FORMATTED_STRING}"         \
     ${STACKIT_URL}/stack/create

exit 0
