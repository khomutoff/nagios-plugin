#!/bin/sh
#
# This Nagios plugin was created to check SSL Certificate expiration date
# Written by Dmitriy Khomutov
# Last modified 04-2015
#
# Description:
# This Plugion connects to a specific host, it verifies that the certificate is valid
# within a threshold set by the -c/-w options.
#

#DEBUG=true

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

PROGNAME=`/bin/basename $0`
PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
REVISION="1.0.0"

print_usage() {
    echo "Usage: $PROGNAME -H hostname [-p port]"
    echo "Usage: $PROGNAME --help"
    echo "Usage: $PROGNAME --version"
}

print_help() {
    print_revision $PROGNAME $REVISION
    echo ""
    print_usage
    echo ""
    echo "Nagios plugin to check SSL Certificate expiration date"
    echo ""
    support
}

# Make sure the correct number of command line
# arguments have been supplied

if [ $# -lt 1 ]; then
    print_usage
    exit $STATE_UNKNOWN
fi
# Default settings:
exitstatus=$STATE_WARNING
warning_days=10
critical_days=1
PORT=443
while test -n "$1"; do
    case "$1" in
        -h | --help)
            print_help
            exit $STATE_OK
            ;;
        -V | --version)
            print_revision $PROGNAME $REVISION
            exit $STATE_OK
            ;;
        -H)
            CERT=$2
            shift
            ;;
        -p)
            PORT=$2
            shift
            ;;
        -w)
            warning_days=$2 # Number of days to warn about soon-to-expire certs
            shift
            ;;
        -c)
            critical_days=$2
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            print_usage
            exit $STATE_UNKNOWN
            ;;
    esac
    shift
done

output=$(echo | openssl s_client -connect ${CERT}:${PORT} 2>/dev/null |\
  sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' |\
  openssl x509 -noout -subject -dates 2>/dev/null) 

if [ "$?" -ne 0 ]; then
  echo "Error connecting to host for certificate [$CERT]"
  exit $STATE_UNKNOWN
fi

start_date=$(echo $output | sed 's/.*notBefore=\(.*\).*not.*/\1/g')
end_date=$(echo $output | sed 's/.*notAfter=\(.*\)$/\1/g')

start_epoch=$(date +%s -d "$start_date")
end_epoch=$(date +%s -d "$end_date")

epoch_now=$(date +%s)

if [ "$start_epoch" -gt "$epoch_now" ]; then
  echo "Certificate for [$CERT] is not yet valid"
  exit $STATE_UNKNOWN
fi

seconds_to_expire=$(($end_epoch - $epoch_now))
days_to_expire=$(($seconds_to_expire / 86400))


warning_seconds=$((86400 * $warning_days))

if [ "$seconds_to_expire" -lt "$warning_seconds" ]; then
  echo "Certificate [$CERT] is soon to expire ($days_to_expire days)"
  exit $STATE_WARNING
elif [ "$days_to_expire" -lt "$critical_days" ]; then
  echo "Certificate [$CERT] is expired! ($end_date)"
  exit $STATE_WARNING
else
  echo "Certificate [$CERT] $days_to_expire days to expiry ($end_date)"
  exitstatus=$STATE_OK
fi

exit $exitstatus
