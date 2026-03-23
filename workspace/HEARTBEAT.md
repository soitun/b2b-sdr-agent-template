# HEARTBEAT.md — Pipeline Inspection

Only report when action is needed. Otherwise reply: HEARTBEAT_OK

## 1. New Leads Check
Read CRM for rows where created_at = today AND status = new.
Found: List them (name, country, product interest, source). Suggest ICP scoring + research + draft first-touch message.
None: Skip.

## 2. Stalled Leads Check
Read CRM for rows where status = contacted/interested/quote_sent/negotiating AND last_contact > 5 business days.
Found: List them (name, company, country, status, last contact). Suggest follow-up draft.
None: Skip.

## 3. Quote Tracking
Find rows where status = quote_sent AND last_contact > 3 business days.
Found: Suggest follow-up on quote feedback.
None: Skip.

## 4. Today's Meetings
Find rows where status = meeting_set AND next_action contains today's date.
Found: Remind to prepare materials.
None: Skip.

## 5. Nurture Check (Mondays only)
Find status = nurture AND last_contact > 14 days → Suggest nurture touch.
Find status = closed_won AND last_contact > 30 days → Suggest after-sale care.
Find status = closed_lost AND last_contact > 90 days → Suggest quarterly follow-up.

## 6. Data Quality (Weekdays, once daily)
Check rows where whatsapp is empty AND status is not closed_*.
Check rows where icp_score is empty AND status is not new.
Found: List them, suggest completion.
None: Skip.

No issues → reply only: HEARTBEAT_OK
