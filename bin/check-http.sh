#!/bin/bash
#
#   check-http
#
# DESCRIPTION:
#   Takes either a URL or a combination of host/path/port/ssl, and checks for
#   a 200 response (that matches a pattern, if given). Can use client certs.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2015 Karl von Randow <karl@xk72.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

set -u

URL=
PATTERN=
REDIRECTOK=
NO_SSL_CHECK=

while getopts ":u:q:rs" opt; do
  case $opt in
	u)
	  URL="$OPTARG"
	  ;;
	q)
	  PATTERN="$OPTARG"
	  ;;
	r)
	  REDIRECTOK="true"
	  ;;
	s)
	  NO_SSL_CHECK="true"
	  ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

if [ "x$URL" == "x" ]; then
	echo "CheckHTTP UNKNOWN: Missing -u url option"
	exit 3
fi

WGET=/usr/bin/wget
if [ ! -x "$WGET" ]; then
	WGET=/usr/local/bin/wget
fi
if [ ! -x "$WGET" ]; then
	echo "wget not found" >&2
	exit 1
fi

ARGS=

if [ "x$REDIRECTOK" != "xtrue" ]; then
	ARGS="$ARGS --max-redirect 0"
fi
if [ "x$NO_SSL_CHECK" != "xtrue" ]; then
	# We can get a redirect to https and it may be that we don't care about validating the certificate there, such
	# as if we're requesting an IP address or a hostname for which there isn't a valid certificate.
	ARGS="$ARGS --no-check-certificate"
fi
ARGS="$ARGS -nv -O- $URL"

ERROR_LOG=`mktemp $TMPDIR/check-http.XXXXXXXXXX.tmp`

OUTPUT=$(eval $WGET $ARGS 2>"$ERROR_LOG")
STATUS=$?

if [ $STATUS == 8 ]; then
	echo "CheckHTTP WARNING: Server error: $URL"
	cat "$ERROR_LOG"
	rm -f "$ERROR_LOG"
	exit 1
elif [ $STATUS != 0 ]; then
	echo "CheckHTTP CRITICAL: Failed to request: $URL"
	cat "$ERROR_LOG"
	rm -f "$ERROR_LOG"
	exit 2
elif [ "x$PATTERN" != "x" ]; then
	echo "$OUTPUT" | grep "$PATTERN" 2>/dev/null >/dev/null
	if [ $? != 0 ]; then
		echo "CheckHTTP CRITICAL: Pattern mismatch: $URL"
		rm -f "$ERROR_LOG"
		exit 2
	else
		echo "CheckHTTP OK: Matched pattern: $URL"
		rm -f "$ERROR_LOG"
		exit 0
	fi
else
	echo "CheckHTTP OK"
	rm -f "$ERROR_LOG"
	exit 0
fi
