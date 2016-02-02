#!/bin/bash
#
# Argument = -t host -u user -p password -k key -s secret -b bucket
#
# To Do - Add logging of output.
# To Do - Abstract bucket region to options

set -e

export PATH="$PATH:/usr/local/bin"

usage()
{
cat << EOF
usage: $0 options

This script restores the current mongo database from a tar from an Amazon S3 bucket.

OPTIONS:
   -h      Show this message
   -a      Timestamp of backup file
   -t      Mongodb host
   -u      Mongodb user
   -p      Mongodb password
   -k      AWS Access Key
   -s      AWS Secret Key
   -b      Amazon S3 bucket name
EOF
}

MONGODB_USER=
MONGODB_PASSWORD=
AWS_ACCESS_KEY=
AWS_SECRET_KEY=
S3_BUCKET=

while getopts “ht:u:p:k:s:b:t:a:” OPTION
do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    a)
      TIMESTAMP=$OPTARG
      ;;
    u)
      MONGODB_USER=$OPTARG
      ;;
    p)
      MONGODB_PASSWORD=$OPTARG
      ;;
    k)
      AWS_ACCESS_KEY=$OPTARG
      ;;
    s)
      AWS_SECRET_KEY=$OPTARG
      ;;
    t)
      MONGODB_HOST=$OPTARG
      ;;
    b)
      S3_BUCKET=$OPTARG
      ;;
    ?)
      usage
      exit
    ;;
  esac
done

if [[ -z $AWS_ACCESS_KEY ]] ||
   [[ -z $AWS_SECRET_KEY ]] ||
   [[ -z $S3_BUCKET ]] ||
   [[ -z $TIMESTAMP ]]
then
  usage
  exit 1
fi

# Get the directory the script is being run from
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo $DIR
# Store the current date in YYYY-mm-DD-HHMMSS
FILE_NAME="backup-$TIMESTAMP"
ARCHIVE_NAME="$FILE_NAME.tar.gz"

HEADER_DATE=$(date -u "+%a, %d %b %Y %T %z")
CONTENT_TYPE="application/x-compressed-tar"
STRING_TO_SIGN="GET\n\n$CONTENT_TYPE\n$HEADER_DATE\n/$S3_BUCKET/$ARCHIVE_NAME"
SIGNATURE=$(echo -e -n $STRING_TO_SIGN | openssl dgst -sha1 -binary -hmac $AWS_SECRET_KEY | openssl enc -base64)

curl -X GET \
     --header "Host: $S3_BUCKET.s3.amazonaws.com" \
     --header "Date: $HEADER_DATE" \
     --header "Content-Type: $CONTENT_TYPE" \
     --header "Authorization: AWS $AWS_ACCESS_KEY:$SIGNATURE" \
     https://$S3_BUCKET.s3.amazonaws.com/$ARCHIVE_NAME \
     | tar -xz

mongorestore --host "$MONGODB_HOST" --username "$MONGODB_USER" --password "$MONGODB_PASSWORD"  --drop --db bodireel backup-$TIMESTAMP/bodireel

rm -rf backup-$TIMESTAMP
