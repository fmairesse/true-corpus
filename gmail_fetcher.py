"""
Read all sent emails from a Gmail account using IMAP and an app password.

Setup:
  1. Enable 2-Step Verification on your Google account:
     https://myaccount.google.com/security
  2. Generate an App Password (select app: Mail, device: Other):
     https://myaccount.google.com/apppasswords
  3. Run: python read_sent_gmail.py --email you@gmail.com --password "xxxx xxxx xxxx xxxx"

No third-party dependencies required — uses only the Python standard library.
"""

import argparse
import email
import imaplib
from email.header import decode_header
from email.message import Message
import os
import re

IMAP_HOST = "imap.gmail.com"
IMAP_PORT = 993

MAIL_SEPARATOR = "-" * 60


def decode_mime_header(value: str) -> str:
    """Decode a MIME-encoded email header string."""
    parts = decode_header(value or "")
    decoded = []
    for part, charset in parts:
        if isinstance(part, bytes):
            decoded.append(part.decode(charset or "utf-8", errors="replace"))
        else:
            decoded.append(part)
    return "".join(decoded)


def get_body(msg: email.message.Message) -> str:
    """Extract plain-text body from an email.message.Message object."""
    if msg.is_multipart():
        for part in msg.walk():
            content_type = part.get_content_type()
            disposition = str(part.get("Content-Disposition", ""))
            if content_type == "text/plain" and "attachment" not in disposition:
                payload = part.get_payload(decode=True)
                charset = part.get_content_charset() or "utf-8"
                return payload.decode(charset, errors="replace")
    else:
        payload = msg.get_payload(decode=True)
        if payload:
            charset = msg.get_content_charset() or "utf-8"
            return payload.decode(charset, errors="replace")
    return ""


def fetch_sent_emails(email_address: str, password: str, max_results: int | None) -> list[dict]:
    """Connect via IMAP, fetch sent emails, and return parsed message dicts."""
    with imaplib.IMAP4_SSL(IMAP_HOST, IMAP_PORT) as imap:
        print(f"Connecting to {email_address}…".ljust(50), end='')
        imap.login(email_address, password)
        print("✅")

        # Gmail's sent-mail folder name over IMAP
        print(f"Searching sent mails…".ljust(50), end='')
        imap.select('"[Gmail]/Sent Mail"', readonly=True)

        status, data = imap.search(None, "SINCE 01-Mar-2006")
        if status != "OK" or not data[0]:
            return []

        # UIDs are space-separated; take the last `max_results` (most recent)
        all_ids = data[0].split()
        print(f"✅ {len(all_ids)} emails")
        selected_ids = all_ids if max_results is None else all_ids[-max_results:]

        for uid in reversed(selected_ids):  # newest first
            status, msg_data = imap.fetch(uid, "(RFC822)")
            if status != "OK" or not msg_data or msg_data[0] is None:
                continue

            raw = msg_data[0][1]
            msg = email.message_from_bytes(raw)

            yield {
                "id": uid.decode(),
                "subject": decode_mime_header(msg.get("Subject", "(no subject)")),
                "to": decode_mime_header(msg.get("To", "")),
                "date": msg.get("Date", ""),
                "body": get_body(msg),
            }


def print_email(mail: dict, out) -> None:
    """Pretty-print a single email."""
    # print(f"[{index}] ID      : {mail['id']}")
    # print(f"     Date    : {mail['date']}")
    # print(f"     To      : {mail['to']}")
    # print(f"     Subject : {mail['subject']}")
    # print(f"     Body    :\n{mail['body'][:500]}")
    # if len(mail["body"]) > 500:
    #     print("     ... (truncated)")
    body: str = mail["body"]
    print_body(body, out)

def print_body(body: str, out=None):
    lines = body.splitlines()
    attachmnent_re = re.compile(r'\[\w+: .*\]')
    origin_date_re = re.compile(r'^(Le (\w+.? )?\d\d? \w+. \d{4}(,| à))|(On \w+, \w+ \d\d?, \d{4})|(On \d\d? \w+ \d{4})|(\d{4}[/-]\d{1,2}[/-]\d{1,2})|(On \d\d?/\d\d?/\d{2,4},)')
    forwarded_re = re.compile(r".*(Forwarded message|Message d'origine|Message transféré).*")
    html_re = re.compile(r'<html .*')
    code_re = re.compile(r'unsigned int lKey;')
    for line in lines:
        if  line.startswith('>') \
                or origin_date_re.match(line) \
                or attachmnent_re.match(line) \
                or forwarded_re.match(line) \
                or code_re.match(line) \
                or html_re.match(line):
            break
        line = line.strip()
        if line:
            print(line, file=out)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Read sent emails from a Gmail account.")
    parser.add_argument("--email", required=True, help="Your Gmail address")
    parser.add_argument("--password", required=True, help="Your Gmail app password")
    parser.add_argument(
        "--max-results",
        type=int,
        default=None,
        help=f"Maximum number of emails to fetch",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    try:    
        sent_emails = fetch_sent_emails(args.email, args.password, args.max_results)
    except imaplib.IMAP4.error as exc:
        print(f"IMAP error: {exc}")
        print("Check your email address and app password.")
        return

    if not sent_emails:
        print("No sent emails found.")
        return

    # print(f"\nFound {len(sent_emails)} sent email(s):\n")
    for i, mail in enumerate(sent_emails):
        if i > 0:
            print(MAIL_SEPARATOR)
        print_email(mail, None)
    print(f"Wrote {i+1} mails")


if __name__ == "__main__":
    main()
    # with open('mails-raw copy.txt') as f:
    #     mails: str = f.read()
    
    # mails = mails.split(MAIL_SEPARATOR)
    # with open('mails-raw.txt', 'w') as f:
    #     for m in mails:
    #         print(MAIL_SEPARATOR, file= f)
    #         print_body(m, f)
