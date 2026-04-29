import os

from jira import JIRA

url = os.environ.get("JIRA_URL")
token = os.environ.get("JIRA_TOKEN")
username = os.environ.get("JIRA_USERNAME")
jira = JIRA(url, basic_auth=(username, token))
next_page_token = None
while True:
	issues = jira.enhanced_search_issues(
		'reporter = currentUser() ORDER BY created DESC',
		fields=['key', 'summary', 'description', 'customfield_10302'],
		maxResults=100,
		nextPageToken = next_page_token)
	next_page_token = issues.nextPageToken
	for issue in issues:
		if issue.fields.summary:
			print(issue.fields.summary)
		if issue.fields.description:
			print(issue.fields.description)
		if issue.fields.customfield_10302:
			print(issue.fields.customfield_10302)
	if next_page_token is None:
		break
