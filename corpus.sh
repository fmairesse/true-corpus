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

function process_source_dirs() {
	for dir in $@; do
		pushd $dir > /dev/null
		find . \( \
			-name '*.ts' \
			-o -name '*.md' \
			-o -name '*.scss' \
			-o -name '*.html' \
			-o -name '*.py' \
			-o -name '*.kt' \
		\) -print0 \
			| xargs -0 cat \
			| grep -oE '[[:alpha:]]+'
		popd > /dev/null
	done
}

# UI Pro
if [ ! -f "output/uipro.json" ]; then
	rm -f output/uipro.json output/uipro-raw.txt
	rawfilepath="`pwd`/output/uipro-raw.txt"
	pushd ~/workspace/delair-stack/uipro/uipro
	process_source_dirs libs docs >> "$rawfilepath"
	popd
	python chardict.py output/uipro-raw.txt > output/uipro.json
fi

# analytics-service
if [ ! -f "output/analytics-service.json" ]; then
	rm -f output/analytics-service.json output/analytics-service-raw.txt
	rawfilepath="`pwd`/output/analytics-service-raw.txt"
	pushd ~/workspace/delair-stack/analytics-service
	process_source_dirs src docs >> "$rawfilepath"
	popd
	python chardict.py output/analytics-service-raw.txt > output/analytics-service.json
fi

# python scripts
if [ ! -f "output/python-scripts.json" ]; then
	rm -f output/python-scripts.json output/python-scripts-raw.txt
	rawfilepath="`pwd`/output/python-scripts-raw.txt"
	pushd ~/workspace/fabien.mairesse/python-scripts
	mv venv ../venv-python-scripts
	process_source_dirs . >> "$rawfilepath"
	mv ../venv-python-scripts ./venv
	popd
	python chardict.py output/python-scripts-raw.txt > output/python-scripts.json
fi

# kotlin
if [ ! -f "output/kotlin.json" ]; then
	rm -f output/kotlin.json output/kotlin-raw.txt
	rawfilepath="`pwd`/output/kotlin-raw.txt"
	pushd ~/workspace/delair-stack
	process_source_dirs \
		alteia-infield/app/src/main/java \
		alteia-capture/app/src/main/java \
	>> "$rawfilepath"
	popd
	python chardict.py output/kotlin-raw.txt > output/kotlin.json
fi

# Code keywords
if [ ! -f "output/code.json" ]; then
	rm -f output/code.json output/code-clean.txt
	sed -E \
		-e 's/^===.*//g' \
		input/code.txt \
	> output/code-keywords-clean.txt
	python chardict.py output/code-keywords-clean.txt > output/code-keywords.json
fi

# Bash history
if [ ! -f "output/bash.json" ]; then
	python chardict.py input/bash_history.txt > output/bash.json
fi

# Merge
## Code
python merge_json_avg.py \
	output/analytics-service.json \
	output/code-keywords.json \
	output/kotlin.json \
	output/python-scripts.json \
	output/uipro.json \
	-o output/code.json
## Tech: code + jira + bash
python merge_json_avg.py \
	output/code.json \
	output/jira.json \
	output/bash.json \
	-o output/tech.json
## Text: mails + slack
python merge_json_avg.py \
	output/mails.json \
	output/slack.json \
	-o output/text.json
## All: text + tech
python merge_json_avg.py \
	output/tech.json \
	output/text.json \
	-o output/all.json

# Filter ngrams
python filter_ngrams.py output/all.json 0.0099 -o output/fma.json