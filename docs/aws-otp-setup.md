# Supabase Auth OTP through Amazon SNS

This function is a Supabase Auth **Send SMS HTTP Hook**. Supabase creates and verifies the OTP; AWS SNS only delivers the text message. The function verifies Supabase's Standard Webhooks signature before it reads and forwards the phone number and OTP.

## Current AWS route

AWS account inspection found SMS tier `PRODUCTION`, with no registered sender ID or India DLT registration. Use `AWS_SMS_ROUTE=india-international` for initial delivery to Indian `+91` mobile numbers. AWS documents that SNS uses an international long-distance (ILDO) route for India by default; it can use a random numeric sender and costs more than the local route. This mode does not claim a registered Kaysons sender ID.

Use `AWS_SMS_ROUTE=india-local` only after the company has completed TRAI/DLT entity, telemarketer-chain, message-template, and AWS sender-ID registration. The function fails closed unless all three DLT values are configured. Local India routes require sending from the registered sender ID and matching the approved message template exactly.

## AWS prerequisites

1. In the AWS account, confirm Amazon SNS SMS is in `Production` in the region you will use. Keep a low monthly SMS spend limit while testing.
2. Create a dedicated IAM identity for this function. Give it only `sns:Publish`; direct SMS publishing needs `Resource: "*"` in the current SNS service authorization model. Do not attach `AmazonSNSFullAccess` or put an AWS key in Flutter/web code.
3. Create a dedicated access key for the IAM identity, then store it only as Supabase Edge Function secrets. Rotate it if it is ever exposed.
4. Configure the maximum acceptable USD price per SMS. AWS's `AWS.SNS.SMS.MaxPrice` message attribute is also set for every send; the account monthly spend limit remains the broader account guard.

For India local routing, complete TRAI/DLT registration for the Kaysons legal entity and OTP use case, register the template, register the transactional alphabetic sender ID in AWS End User Messaging SMS, and wait for its status to become `Complete`. AWS documents India local routes in `ap-south-1` (Mumbai) or `ap-south-2` (Hyderabad). Associate the entity ID and template ID with the AWS account as required by the registration flow.

## Supabase secrets

Set these as Edge Function secrets (never commit them, place them in Flutter, or put them in `supabase/functions/.env` in a tracked file):

| Secret | Required value |
| --- | --- |
| `SEND_SMS_HOOK_SECRETS` | Full Supabase-generated secret such as `v1,whsec_<base64>`; multiple rotation secrets may be separated with `|`. |
| `AWS_REGION` | Region used for SNS. For India local routes, use `ap-south-1` or `ap-south-2`. |
| `AWS_ACCESS_KEY_ID` | Dedicated IAM key with only direct SMS publish permission. |
| `AWS_SECRET_ACCESS_KEY` | Secret half of that IAM key. |
| `AWS_SESSION_TOKEN` | Optional STS session token when using temporary AWS credentials. |
| `AWS_SMS_ROUTE` | `india-international` initially, or `india-local` after DLT/AWS registration is complete. |
| `AWS_SMS_MAX_PRICE_USD` | Positive USD per-message cap. The function rejects values above `$1.00`; set a much lower business-approved cap and account spend limit. |
| `OTP_SMS_BODY_TEMPLATE` | Exact approved SMS text with exactly one `{{otp}}` placeholder, e.g. `Your Kaysons verification code is {{otp}}. Valid for 5 minutes. Do not share it.` |
| `AWS_SMS_SENDER_ID` | Local mode only: registered transactional sender ID (3–6 letters, case-sensitive). |
| `AWS_SMS_DLT_ENTITY_ID` | Local mode only: registered entity/PE ID. |
| `AWS_SMS_DLT_TEMPLATE_ID` | Local mode only: approved message template ID matching the configured message exactly. |

Example local secret setup (enter actual values through the Supabase secrets UI/CLI without committing them):

```sh
supabase secrets set \
  SEND_SMS_HOOK_SECRETS='v1,whsec_…' \
  AWS_REGION='ap-south-1' \
  AWS_ACCESS_KEY_ID='…' \
  AWS_SECRET_ACCESS_KEY='…' \
  AWS_SMS_ROUTE='india-international' \
  AWS_SMS_MAX_PRICE_USD='0.10' \
  OTP_SMS_BODY_TEMPLATE='Your Kaysons verification code is {{otp}}. Valid for 5 minutes. Do not share it.'
```

Treat the OTP sentence as a carrier-template contract, not arbitrary copy. For India local delivery, replace the example with the exact DLT-approved template and confirm that `{{otp}}` corresponds to the carrier's registered variable. Extra punctuation, spaces, case changes, or wording can cause carrier rejection.

## Configure the Auth hook

Deploy `supabase/functions/send-sms-otp/index.ts` as function `send-sms-otp`. Disable Edge Function JWT verification for this endpoint because Auth calls it before issuing a user session; the request is authenticated by the Standard Webhooks signature instead. In **Authentication → Hooks**, create an **HTTP Send SMS Hook**, point it to:

```text
https://<project-ref>.supabase.co/functions/v1/send-sms-otp
```

Generate the hook secret there and store the complete `v1,whsec_…` value in `SEND_SMS_HOOK_SECRETS`. Do not share this secret with AWS. Confirm the dashboard hook is enabled only after function deployment and secrets are ready.

When using the CLI, deploy this function with `supabase functions deploy send-sms-otp --no-verify-jwt` (or configure the equivalent per-function setting). Do not make the endpoint callable with a valid user JWT the only access check; the handler itself verifies the signed Auth-hook payload.

The handler accepts only signed JSON requests with a six-digit OTP and an Indian mobile number beginning with `91` plus ten digits, with or without a leading `+`. It normalizes the number to E.164 (`+91…`) before sending. It returns an empty JSON object on success. It sets `Transactional` and `MaxPrice` for each message. The AWS call has a 2.2-second request timeout and one attempt to stay inside Supabase Auth's five-second total hook budget. It logs neither OTPs nor phone numbers.

In **Authentication → Rate Limits**, keep OTP-send limits low for the initial rollout and enable CAPTCHA/bot protection on the client-facing sign-in route where supported. These controls help limit SMS pumping; AWS's monthly spend limit and the per-message `MaxPrice` are separate cost safeguards.

## Access model boundary

Successful SMS verification proves control of a phone number and establishes a Supabase Auth session. It does not approve the Kaysons account or grant a role. Keep account approval and role assignment in the application's trusted admin workflow and enforce table/row access with Supabase RLS. The function deliberately does not read user metadata or decide application permissions.

## Local development

Use the current Supabase CLI to serve the function with JWT verification disabled and set local secrets in an ignored environment file. Configure the local Auth HTTP hook with the CLI's current `[auth.hook.send_sms]` settings and its secret variable. Supabase's hook documentation caps request payloads at 20 KB and uses Standard Webhooks headers (`webhook-id`, `webhook-timestamp`, `webhook-signature`). Run a signed simulation and verify that an invalid signature never calls AWS. A real SMS delivery test still requires AWS credentials, production permission, a phone you control, and the account's spend limit.

## References

- [Supabase Auth Hooks](https://supabase.com/docs/guides/auth/auth-hooks)
- [Supabase Send SMS Hook](https://supabase.com/docs/guides/auth/auth-hooks/send-sms-hook)
- [Supabase Changelog](https://supabase.com/changelog.md)
- [Amazon SNS SMS sending overview](https://docs.aws.amazon.com/sns/latest/dg/sms_sending-overview.html)
- [AWS SNS India sender-ID troubleshooting](https://repost.aws/knowledge-center/sns-failed-sender-id-messages-to-india)
- [AWS India sender ID and DLT requirements](https://docs.aws.amazon.com/sms-voice/latest/userguide/registrations-sms-senderid-india.html)
- [AWS End User Messaging SMS India Entity ID and Template ID](https://docs.aws.amazon.com/sms-voice/latest/userguide/registrations-sms-senderid-india-specify-ids.html)
