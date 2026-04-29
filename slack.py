import os
from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError


def fetch_user_messages():
    """Fetch all messages written by the authenticated user and save to a text file."""
    
    # Initialize the Slack client
    token = os.environ.get("SLACK_BOT_TOKEN")
    if not token:
        raise ValueError("SLACK_BOT_TOKEN environment variable not set")
    
    client = WebClient(token=token)
    
    try:
        # Get the authenticated user's ID
        auth_response = client.auth_test()
        user_id = auth_response["user_id"]
        print(f"Fetching messages for user: {user_id}")
        
        # Get all conversations the user is part of
        messages = client.search_messages(query=f'from:{user_id}')
        conversations = client.conversations_list(limit=1000)
        
        messages = []
        
        for conversation in conversations["channels"]:
            channel_id = conversation["id"]
            channel_name = conversation["name"]
            
            try:
                # Fetch messages from the channel
                result = client.conversations_history(channel=channel_id, limit=1000)
                
                for message in result["messages"]:
                    # Filter messages written by the current user
                    if message.get("user") == user_id and "text" in message:
                        messages.append({
                            "channel": channel_name,
                            "timestamp": message.get("ts"),
                            "text": message["text"]
                        })
            except SlackApiError as e:
                print(f"Error fetching messages from {channel_name}: {e}")
        
        # Write messages to file
        with open("slack_messages.txt", "w", encoding="utf-8") as f:
            f.write(f"Messages written by {user_id}\n")
            f.write("=" * 80 + "\n\n")
            
            for msg in sorted(messages, key=lambda x: x["timestamp"]):
                f.write(f"Channel: #{msg['channel']}\n")
                f.write(f"Timestamp: {msg['timestamp']}\n")
                f.write(f"Message: {msg['text']}\n")
                f.write("-" * 80 + "\n\n")
        
        print(f"Successfully saved {len(messages)} messages to slack_messages.txt")
    
    except SlackApiError as e:
        print(f"Error connecting to Slack: {e}")


if __name__ == "__main__":
    fetch_user_messages()
