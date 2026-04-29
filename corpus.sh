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

## Slack
jq -r '.[].items[].messages[].blocks[]?.elements[].elements[].text?' ./input/slack.json > output/slack-raw.txt
sed -E \
	-e 's/^null$//g' \
	-e 's/[[:alnum:]]*[[:digit:]]+[[:alnum:]]*/ /g' \
	-e 's/[^[:alnum:]]+/ /g' \
	-e 's/[[:space:]]+/ /g' \
	output/slack-raw.txt \
> output/slack-clean.txt
python chardict.py output/slack-clean.txt > output/slack.json

# Jira
if [ ! -f "output/jira-raw.txt" ]; then
	python jira_fetcher.py > output/jira-raw.txt
fi
sed -E \
	-e 's/\{[^[:space:]]+\}//g' \
	-e 's/\*?\[ [^[:space:]]+ \]\*?//g' \
	-e 's/Client \(Alteia \/ GE\) ://g' \
	-e 's/Platform \(DEV \/ STAG \/ PROD\) ://g' \
	-e 's/Users role ://g' \
	-e 's/\(\?\) \*Steps to reproduce\*//g' \
	-e 's/\(x\) \*Actual result \(symptoms\)\*//g' \
	-e 's/\(\/\) \*Expected result\*//g' \
	-e 's/^\*Environment\*//g' \
	-e 's/^Client[[:space:]]*:.*$//g' \
	-e 's/^Platform[[:space:]]*:.*$//g' \
	-e 's/to_complete//g' \
	-e 's/^!.+!$//g' \
	-e 's/\[.*http.+\]//g' \
	-e 's/\[\^.+\]//g' \
	-e 's#<?https?://[^[:space:]<>]+>?# #g' \
	-e 's/^npm .+//g' \
	-e 's/^Feb  ,.*//g' \
	-e 's/[[:alnum:]]*[[:digit:]]+[[:alnum:]]*/ /g' \
	-e 's/[^[:alnum:]]+/ /g' \
	-e 's/[[:space:]]+/ /g' \
	-e '/^[[:space:]]*$/d' \
	output/jira-raw.txt \
> output/jira-clean.txt
python chardict.py output/jira-clean.txt > output/jira.json