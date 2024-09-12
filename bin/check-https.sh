#!/bin/bash -u
#
# Check that an SSL connection can be established and optionally check the certificate expiry

HOST=
PORT=443
EXPIRY=
EXPIRY_CRITICAL=
SERVER_NAME=

while getopts ":h:p:s:e:E:" opt; do
  case $opt in
	h)
	  HOST="$OPTARG"
	  ;;
	p)
	  PORT="$OPTARG"
	  ;;
	s)
	  SERVER_NAME="$OPTARG"
	  if [ -z "$HOST" ]; then
	  	HOST="$OPTARG"
	  fi
	  ;;
	e)
	  EXPIRY="$OPTARG"
	  ;;
	E)
	  EXPIRY_CRITICAL="$OPTARG"
	  ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

if [ "x$HOST" == "x" ]; then
	echo "CheckHTTPS UNKNOWN: Missing -h host option"
	exit 3
fi

if [ "x$PORT" == "x" ]; then
	echo "CheckHTTPS UNKNOWN: Missing -p port option"
	exit 3
fi

OPENSSL=/usr/bin/openssl

if [ ! -x "$OPENSSL" ]; then
	echo "CheckHTTPS UNKNOWN: Cannot find $OPENSSL"
	exit 3
fi

if [ "x$SERVER_NAME" == "x" ]; then
	OUTPUT=$($OPENSSL s_client -host "$HOST" -port "$PORT" < /dev/null 2>&1)
else
	OUTPUT=$($OPENSSL s_client -host "$HOST" -port "$PORT" -servername "$SERVER_NAME" < /dev/null 2>&1)
fi
STATUS=$?

if [ $STATUS != 0 ]; then
	echo "CheckHTTPS CRITICAL: Failed: $HOST:$PORT"
	echo $OUTPUT
	exit 2
fi

echo "CheckHTTPS OK: $HOST:$PORT"
if [ "x$EXPIRY" != "x" -o "x$EXPIRY_CRITICAL" != "x" ]; then
	NOT_AFTER=$(echo "$OUTPUT" | $OPENSSL x509 -enddate -noout | cut -d '=' -f 2)
	if [ "x$NOT_AFTER" != "x" ]; then
		NOT_AFTER_NUM=$(date +%s -d "$NOT_AFTER")
		NOW=$(date +%s)
		EXPIRY_DAYS=$((($NOT_AFTER_NUM - $NOW) / 86400))

		if [ "x$EXPIRY_CRITICAL" != "x" -a $(($EXPIRY_DAYS < ($EXPIRY_CRITICAL + 1))) == 1 ]; then
			echo "CheckHTTPS CRITICAL: Certificate expires in $EXPIRY_DAYS days: $HOST:$PORT"
			exit 2
		elif [ "x$EXPIRY" != "x" -a $(($EXPIRY_DAYS < ($EXPIRY + 1))) == 1 ]; then
			echo "CheckHTTPS WARNING: Certificate expires in $EXPIRY_DAYS days: $HOST:$PORT"
			exit 1
		else
			echo "Certificate expires in $EXPIRY_DAYS days"
		fi
	fi
fi

exit 0
