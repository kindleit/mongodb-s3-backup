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

ARCHIVE_TS=
MONGODB_USER=
MONGODB_PASSWORD=
AWS_ACCESS_KEY=
AWS_SECRET_KEY=
S3_BUCKET=

while getopts “a:b:k:p:s:t:u:” OPTION
do
  case $OPTION in
    a)
      ARCHIVE_TS=$OPTARG
      ;;
    b)
      S3_BUCKET=$OPTARG
      ;;
    k)
      AWS_ACCESS_KEY=$OPTARG
      ;;
    p)
      MONGODB_PASSWORD=$OPTARG
      ;;
    s)
      AWS_SECRET_KEY=$OPTARG
      ;;
    t)
      MONGODB_HOST=$OPTARG
      ;;
    u)
      MONGODB_USER=$OPTARG
      ;;
    ?)
      usage
      exit 1
    ;;
  esac
done

if [[ -z $AWS_ACCESS_KEY ]] ||
   [[ -z $AWS_SECRET_KEY ]] ||
   [[ -z $S3_BUCKET      ]] ||
   [[ -z $ARCHIVE_TS     ]]
then
  usage
  exit 1
fi

# Prepare S3 params
ARCHIVE_NAME="backup-$ARCHIVE_TS.tar.gz"
HEADER_DATE=$(date -u "+%a, %d %b %Y %T %z")
CONTENT_TYPE="application/x-compressed-tar"
STRING_TO_SIGN="GET\n\n$CONTENT_TYPE\n$HEADER_DATE\n/$S3_BUCKET/$ARCHIVE_NAME"
SIGNATURE=$(echo -e -n $STRING_TO_SIGN | openssl dgst -sha1 -binary -hmac $AWS_SECRET_KEY | openssl enc -base64)

# Untar archive backup stored in S3
curl -X GET \
     --header "Host: $S3_BUCKET.s3.amazonaws.com" \
     --header "Date: $HEADER_DATE" \
     --header "Content-Type: $CONTENT_TYPE" \
     --header "Authorization: AWS $AWS_ACCESS_KEY:$SIGNATURE" \
     https://$S3_BUCKET.s3.amazonaws.com/$ARCHIVE_NAME \
     | tar -xz

# Prepare mongorestore arguments
RESTORE_PARAMS="--drop --db bodireel --host $MONGODB_HOST"
[[ -n $MONGODB_USER     ]] && RESTORE_PARAMS="$RESTORE_PARAMS --username $MONGODB_USER"
[[ -n $MONGODB_PASSWORD ]] && RESTORE_PARAMS="$RESTORE_PARAMS --password $MONGODB_PASSWORD"

# Restore backup
mongorestore $RESTORE_PARAMS backup-$ARCHIVE_TS/bodireel

# Delete backup folder
rm -rf backup-$ARCHIVE_TS
