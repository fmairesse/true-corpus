#!/bin/bash
mkdir -p output
set -a
source .env

## Mail
if [ ! -f "output/mails-clean.txt" ]; then
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
fi

## Slack
if [ ! -f "output/slack-raw.txt" ]; then
	jq -r '.[].items[].messages[].blocks[]?.elements[].elements[].text?' ./input/slack.json > output/slack-raw.txt
fi
if [ ! -f "output/slack-clean.txt" ]; then
	sed -E \
		-e 's/^null$//g' \
		-e 's/[[:alnum:]]*[[:digit:]]+[[:alnum:]]*/ /g' \
		-e 's/[^[:alnum:]]+/ /g' \
		-e 's/[[:space:]]+/ /g' \
		output/slack-raw.txt \
	> output/slack-clean.txt
	python chardict.py output/slack-clean.txt > output/slack.json
fi

# Jira
if [ ! -f "output/jira-raw.txt" ]; then
	python jira_fetcher.py > output/jira-raw.txt
fi
if [ ! -f "output/jira-clean.txt" ]; then
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
fi

# Code keywords
if [ ! -f "output/code-keywords-clean.txt" ]; then
	rm -f output/code.json output/code-clean.txt
	sed -E \
		-e 's/^===.*//g' \
		input/code.txt \
	> output/code-keywords-clean.txt
	python chardict.py output/code-keywords-clean.txt > output/code-keywords.json
fi

# Prompts
if [ ! -f "output/prompts-clean.txt" ]; then
	sed -E \
		-e 's/^null$//g' \
		-e 's/[[:alnum:]]*[[:digit:]]+[[:alnum:]]*/ /g' \
		-e 's/[^[:alnum:]]+/ /g' \
		-e 's/[[:space:]]+/ /g' \
		input/prompts.txt \
	> output/prompts-clean.txt
	python chardict.py output/prompts-clean.txt > output/prompts.json
fi

cat output/mails-clean.txt \
	output/slack-clean.txt \
	output/jira-clean.txt \
	output/prompts-clean.txt \
	> output/all-clean.txt

python chardict.py output/all-clean.txt > output/all.json

# Filter ngrams
python filter_ngrams.py output/all.json 0.0099 -o output/fma.json