#!/bin/bash
## This code is simply a modification/wrapper for the awesome idea of doing non-recursive digs against DNS servers you own
## This script allows you to 'multi-thread' the queries, so that you're querying the servers in parallel, then checking the results...
## This code was written to run on an Ubuntu box (Yuck....) with ssmtp installed
## If you want this to run on CentOS/RHEL, just replace the mail portion with the 'mail' command equivalent
## Change the default email before you run...
## Email blackhole.em@gmail.com with any questions

if [ "$#" != "2" ]; then
  echo "Wrong number of args..."
	echo "Usage is:"
	echo "$0 DNS_SERVER_FILE DOMAIN_LOOKUP_FILE"
	exit 0
fi
if [ ! -d "output" ]; then
	mkdir output
fi
DATESTAMP1=`date +%Y-%m-%d_%H%M`
SERVER_FILE="$1"
DOMAIN_FILE="$2"
EMAIL_ADDRESS="goodguy@somedomain.com"
# Go and pound away at all the DNS servers... at the same time...
cat $SERVER_FILE |while read TARGET ; do
	dig @$TARGET -f $DOMAIN_FILE +norecurse | sed '/^$/d'| sed "s/^/[+] Target Site Discovered : /g" | grep -A 1 "ANSWER SECTION" | grep -v "ANSWER SECTION" | sort -u  >> output/$DATESTAMP1.$TARGET.txt &
done
# Finished pounding?  Let's check our results to see if we found anything
while [ 1 = 1 ]; do
	DATESTAMP=`date +%Y-%m-%d_%H%M`
	sleep 5
	# Check to see that all of our NON-recursive checks have finished
	CHECK=`ps -ef |grep "\-f $DOMAIN_FILE +norecurse"|grep -v grep`
	if [ ! -n "$CHECK" ]; then
		# If they have, let's collect the results
		ls output |grep "${DATESTAMP1}"| while read SERVERFILE; do
			echo $SERVERFILE
			# If the results file has anything in it, append it to the hits file, along we the the offending DNS server
			if [ -s "output/$SERVERFILE" ]; then
				echo $SERVERFILE >> output/$DATESTAMP.hits
				cat output/$SERVERFILE >> output/$DATESTAMP.hits
			# Otherwise, delete the empty file 
			else
				rm -f "output/$SERVERFILE"
			fi
		done
		# If we have an email file, then we should send it out...
		if [ -e "output/$DATESTAMP.hits" ]; then
			echo "output/$DATESTAMP.hits" >> /tmp/log
			EMAIL="output/$DATESTAMP.email"
			echo $EMAIL >> /tmp/log
			# Add more of these 'To:' lines if you want to send it to multiple people
			echo "To: $EMAIL_ADDRESS" >> $EMAIL
            echo "Subject: DNS Watchlist hit" >> $EMAIL
            echo "" >> $EMAIL
            echo "" >> $EMAIL
            echo "DNS records for the DNS watchlist were found:" >> $EMAIL
            echo "" >> $EMAIL
            cat output/$DATESTAMP.hits >> $EMAIL
			echo "." >> $EMAIL
		    echo " " >> $EMAIL
		    /usr/sbin/ssmtp "$EMAIL_ADDRESS" < $EMAIL
		fi
		# Exit out of infinite loop....
		exit 0
	fi
done
