# TOOLS.md — Tool Configuration

## CRM (Source of Truth)
Configure based on your CRM choice: Google Sheets, Notion, Airtable, or any REST API.

### Google Sheets Mode
Access via gws CLI:
```bash
# Read leads
gws sheets spreadsheets.values get --params '{"spreadsheetId":"{{sheets_id}}","range":"{{sheet_name}}!A:Q"}'

# Append new lead
gws sheets spreadsheets.values append --params '{"spreadsheetId":"{{sheets_id}}","range":"{{sheet_name}}!A:Q","valueInputOption":"USER_ENTERED"}' --body '{"values":[["..."]]}'
```
⚠️ Only use append and update — never overwrite entire rows.

## WhatsApp (Conversation Channel)
AI directly replies to customer inquiries — no human relay.
Channel policy: Allow all contacts.
CTWA ad leads can be replied to directly (72-hour conversation window).

## Web Research
Use built-in search to research target companies: website, LinkedIn, news.
Focus on: procurement trends in your target industry.

## Gmail (Optional)
Access via gws CLI:
```bash
gws gmail users messages list --params '{"userId":"me","maxResults":5}'
```
