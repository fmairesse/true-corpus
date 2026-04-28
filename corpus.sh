#!/bin/bash

mkdir -p output
set -a
source .env

# Get raw mails
if [ ! -f "output/mails-raw.txt" ]; then
	(python gmail.py \
		--email $GMAIL_USERNAME \
		--password "$GMAIL_PASSWORD" \
	 	> output/mails-raw.txt.tmp \
	&& mv output/mails-raw.txt.tmp output/mails-raw.txt
	) \
	|| (echo 'Failed to fetch GMail messages' && exit 1)
fi

# Clean raw mails:
# - links
# - email adresses
# - words with numbers
# - some BIC
# - non-alpha characters
sed -E \
	-e 's#<?https?://[^[:space:]<>]+>?# #g' \
	-e 's/[^[:space:]@]+@[^[:space:]@]+/ /g' \
	-e 's/[[:alnum:]]*[[:digit:]]+[[:alnum:]]*/ /g' \
	-e 's/PSSTFRPPLIL/ /g' \
	-e 's/CRLYFRPP/ /g' \
	-e 's/[^[:alnum:]]+/ /g' \
	-e 's/[[:space:]]+/ /g' \
	output/mails-raw.txt \
> output/mails-clean.txt

python chardict.py output/mails-clean.txt > output/mails.json
