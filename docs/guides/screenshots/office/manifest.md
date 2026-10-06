# Office guide screenshots

These are rendered Flutter widgets from the current source code, captured at
390 × 844 logical pixels (780 × 1688 PNGs at 2× scale). Every image uses an
isolated in-memory sample API and a fabricated session. The `SAMPLE DATA`
ribbon is intentional. No production customer, account, invoice, or credential
data appears in these captures.

| Guide role | Guide section | English | Hindi |
| --- | --- | --- | --- |
| Administrator | Dashboard and KPI cards | `administrator-dashboard-en.png` | `administrator-dashboard-hi.png` |
| Administrator | User management | `administrator-users-en.png` | `administrator-users-hi.png` |
| Administrator | Pending user review and approval controls | `administrator-user-review-en.png` | `administrator-user-review-hi.png` |
| Administrator | Bids and date filters | `administrator-bids-en.png` | `administrator-bids-hi.png` |
| Administrator | Freight ledger, filters, rows | `administrator-ledger-en.png` | `administrator-ledger-hi.png` |
| Administrator | New ledger entry form | `administrator-ledger-entry-en.png` | `administrator-ledger-entry-hi.png` |
| Administrator | Ledger report export menu | `administrator-ledger-export-menu-en.png` | `administrator-ledger-export-menu-hi.png` |
| Administrator | Clawd overview | `administrator-clawd-en.png` | `administrator-clawd-hi.png` |
| Administrator | Notifications | `administrator-notifications-en.png` | `administrator-notifications-hi.png` |
| Administrator | Profile | `administrator-profile-en.png` | `administrator-profile-hi.png` |
| Accountant | Freight ledger, filters, rows | `accountant-ledger-en.png` | `accountant-ledger-hi.png` |
| Accountant | New ledger entry form | `accountant-ledger-entry-en.png` | `accountant-ledger-entry-hi.png` |
| Accountant | Ledger report export menu | `accountant-ledger-export-menu-en.png` | `accountant-ledger-export-menu-hi.png` |
| Accountant | Analytics | `accountant-analytics-en.png` | `accountant-analytics-hi.png` |
| Accountant | Clawd overview | `accountant-clawd-en.png` | `accountant-clawd-hi.png` |
| Accountant | Notifications | `accountant-notifications-en.png` | `accountant-notifications-hi.png` |
| Accountant | Profile | `accountant-profile-en.png` | `accountant-profile-hi.png` |

Regenerate from the repository root with:

```sh
flutter test test/office_guide_screenshots_test.dart --update-goldens --no-pub
```

The dashboard, bids, ledger, and analytics show fabricated sample values; bids
intentionally show the empty state. The Clawd screenshot shows the overview and
quick prompts, not a generated reply. The notification title and message are
sample server content and therefore remain in English in the Hindi screenshot.
The date range controls use Hindi labels in the Hindi analytics and bids captures.

These images document layout and controls. They do not establish live backend
behavior, successful submission, or native iOS rendering. CSV import, generated
export files, and report details are not captured here.
The export menu was opened without choosing a report. The upload icon is visible
on the ledger screen, but no file picker, upload, save, or approval action was
used. The Hindi entry form still displays the stored default value `Manual
Ledger` and the capacity option `Up to 1 MT` in English; those are data values
shared with backend workflow rules.
