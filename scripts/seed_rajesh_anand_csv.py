#!/usr/bin/env python3
import csv
import hashlib
import json
import re
import secrets
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
import zipfile
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ENV_PATH = ROOT / ".env"
SEED_TAG = "Ludhiana Sec. Frt. Apr.26 Real Data"
OLD_SEED_TAG = "Rajesh Anand CSV Apr.26"
ORIGIN = "Ludhiana"

CSV_FILES = [
    ("Bunge", ROOT / "docs/Demo Data/Rajesh Anand - Bunge Apr.26.csv"),
    ("Cargill", ROOT / "docs/Demo Data/Rajesh Anand - Cargill Apr. 26.csv"),
]
XLSX_FILE = ROOT / "docs/Demo Data/Ludhiana Sec. Frt. - Apr. 26 (1).xlsx"
XLSX_SHEETS = {
    "Bunge Apr.26": "Bunge",
    "Cargill Apr. 26": "Cargill",
}


def load_env():
    env = {}
    for line in ENV_PATH.read_text().splitlines():
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        env[key.strip()] = value.strip().strip('"').strip("'")
    return env


ENV = load_env()
SUPABASE_URL = ENV["SUPABASE_URL"].rstrip("/")
ANON_KEY = ENV["SUPABASE_ANON_KEY"]
ADMIN_EMAIL = ENV.get("SEED_ADMIN_EMAIL", "admin@kaysons.demo")
ADMIN_PASSWORD = ENV.get("SEED_ADMIN_PASSWORD")
LM_EMAIL = ENV.get("SEED_LOGISTICS_MANAGER_EMAIL", "lm@kaysons.demo")
REST_URL = f"{SUPABASE_URL}/rest/v1"
AUTH_URL = f"{SUPABASE_URL}/auth/v1"


def request(method, url, token=None, body=None, prefer=None):
    headers = {
        "apikey": ANON_KEY,
        "Content-Type": "application/json",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if prefer:
        headers["Prefer"] = prefer
    data = None if body is None else json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as res:
            text = res.read().decode("utf-8")
            return json.loads(text) if text else None
    except urllib.error.HTTPError as err:
        text = err.read().decode("utf-8")
        try:
            payload = json.loads(text)
        except json.JSONDecodeError:
            payload = text
        raise RuntimeError(f"{method} {url} failed: {err.code} {payload}") from err


def sign_in(email, password):
    payload = request(
        "POST",
        f"{AUTH_URL}/token?grant_type=password",
        body={"email": email, "password": password},
    )
    return payload["access_token"]


def clean(value):
    return (value or "").replace("\xa0", " ").strip()


def parse_number(value):
    text = clean(value).replace(",", "")
    if not text or text in {"-", "--"}:
        return 0.0
    text = re.sub(r"[^0-9.\-]", "", text)
    if text in {"", "-", "."}:
        return 0.0
    return float(text)


def vehicle_capacity_category(weight_mt):
    if weight_mt <= 1:
        return "Up to 1 MT"
    if weight_mt <= 3:
        return "Up to 3 MT"
    if weight_mt <= 6:
        return "3-6 MT"
    if weight_mt <= 9:
        return "6-9 MT"
    if weight_mt <= 12:
        return "9-12 MT"
    if weight_mt <= 15:
        return "12-15 MT"
    return "15+ MT"


def parse_date(value):
    text = clean(value)
    if not text:
        return None
    if re.fullmatch(r"\d+(\.\d+)?", text):
        # Excel serial date, 1899-12-30 base handles Excel's 1900 leap-year bug.
        return (datetime(1899, 12, 30) + timedelta(days=float(text))).date().isoformat()
    for fmt in ("%d/%b/%y", "%d-%m-%y", "%d/%m/%y"):
        try:
            return datetime.strptime(text, fmt).date().isoformat()
        except ValueError:
            pass
    raise ValueError(f"Unsupported date format: {value!r}")


def normalize_transport_name(value):
    text = re.sub(r"\s+", " ", clean(value)).upper()
    return text or "UNKNOWN TRANSPORTER"


def slug(value):
    text = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return text or "unknown"


def canonical_header(value):
    return re.sub(r"[^a-z0-9]+", "", clean(value).lower())


def row_from_mapping(company, row):
    bill_date = parse_date(row.get("Bill Date") or row.get("billdate"))
    party = clean(row.get("Party Name") or row.get("partyname"))
    if not bill_date or not party:
        return None
    dispatch_raw = clean(row.get("Dispatch Date") or row.get("dispatchdate"))
    dispatch_date = parse_date(dispatch_raw) if dispatch_raw else None
    ack_raw = clean(
        row.get("Acknwoledgement Status")
        or row.get("Acknowledgement Status")
        or row.get("acknwoledgementstatus")
        or row.get("acknowledgementstatus")
    ).upper()
    ack_received = ack_raw in {"RECD", "RECEIVED", "YES"}
    invoice_number = clean(
        row.get("Invoice Number")
        or row.get("INVOICE NO")
        or row.get("invoicenumber")
        or row.get("invoiceno")
    )
    eway_number = clean(
        row.get("E Waybill Number")
        or row.get("E-Waybill Number")
        or row.get("ewaybillnumber")
        or row.get("ewaynumber")
    )
    freight = parse_number(row.get("Freight") or row.get("freight"))
    extra_freight = parse_number(row.get("Extra Freight") or row.get("extrafreight"))
    labour = parse_number(row.get("Labour") or row.get("labour"))
    detention = parse_number(row.get("Detention") or row.get("detention"))
    return {
        "company_name": company,
        "party_name": party,
        "bill_date": bill_date,
        "dispatch_date": dispatch_date,
        "invoice_number": invoice_number,
        "e_way_bill_number": eway_number,
        "town": clean(row.get("Town") or row.get("town")).upper(),
        "cases": int(round(parse_number(row.get("Case") or row.get("case")))),
        "weight_kg": parse_number(row.get("Net Weight in MT") or row.get("netweightinmt")),
        "vehicle_number": clean(row.get("Vehicle Number") or row.get("vehiclenumber")),
        "vehicle_type": clean(row.get("Vehicle Type") or row.get("vehicletype")),
        "base_freight": freight,
        "extra_freight": extra_freight,
        "labour": labour,
        "detention": detention,
        "lr_number": clean(row.get("LR no.") or row.get("lrno") or row.get("lrnumber")),
        "transport_name": normalize_transport_name(
            row.get("Transport Name") or row.get("transportname")
        ),
        "remarks": clean(row.get("Remarks") or row.get("remarks")),
        "ack_status": "received" if ack_received else "pending",
        "status": "completed" if ack_received else "locked",
        "ack_received": ack_received,
    }


def read_csv_rows():
    parsed = []
    for company, path in CSV_FILES:
        with path.open(newline="", encoding="utf-8-sig") as handle:
            rows = list(csv.reader(handle))
        header_index = next(
            i for i, row in enumerate(rows) if any(clean(cell) == "Bill Date" for cell in row)
        )
        headers = [clean(cell) for cell in rows[header_index]]
        for raw in rows[header_index + 1 :]:
            if not any(clean(cell) for cell in raw):
                continue
            row = {
                headers[i] if i < len(headers) and headers[i] else f"extra_{i}": clean(cell)
                for i, cell in enumerate(raw)
            }
            item = row_from_mapping(company, row)
            if item:
                parsed.append(item)
    return parsed


def read_xlsx_rows():
    if not XLSX_FILE.exists():
        return []
    ns = {
        "a": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
        "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
    }

    def col_index(cell_ref):
        letters = "".join(re.findall(r"[A-Z]+", cell_ref))
        index = 0
        for letter in letters:
            index = index * 26 + ord(letter) - 64
        return index - 1

    parsed = []
    with zipfile.ZipFile(XLSX_FILE) as archive:
        workbook = ET.fromstring(archive.read("xl/workbook.xml"))
        rels = ET.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
        relmap = {rel.attrib["Id"]: rel.attrib["Target"] for rel in rels}
        shared_strings = []
        if "xl/sharedStrings.xml" in archive.namelist():
            root = ET.fromstring(archive.read("xl/sharedStrings.xml"))
            for item in root.findall("a:si", ns):
                shared_strings.append(
                    "".join(text.text or "" for text in item.iter(f"{{{ns['a']}}}t"))
                )

        def cell_value(cell):
            value = cell.find("a:v", ns)
            if value is None:
                return ""
            text = value.text or ""
            return shared_strings[int(text)] if cell.attrib.get("t") == "s" else text

        sheets = {}
        for sheet in workbook.find("a:sheets", ns):
            rel_id = sheet.attrib[f"{{{ns['r']}}}id"]
            target = relmap[rel_id].lstrip("/")
            sheets[sheet.attrib["name"]] = f"xl/{target}"

        for sheet_name, company in XLSX_SHEETS.items():
            sheet_path = sheets.get(sheet_name)
            if not sheet_path:
                continue
            root = ET.fromstring(archive.read(sheet_path))
            rows = []
            for row_node in root.findall(".//a:sheetData/a:row", ns):
                values = {}
                max_col = 0
                for cell in row_node.findall("a:c", ns):
                    index = col_index(cell.attrib["r"])
                    values[index] = clean(cell_value(cell))
                    max_col = max(max_col, index)
                rows.append([values.get(i, "") for i in range(max_col + 1)])

            header_index = next(
                (
                    i
                    for i, row in enumerate(rows)
                    if any(canonical_header(cell) == "billdate" for cell in row)
                ),
                None,
            )
            if header_index is None:
                continue
            headers = [clean(cell) for cell in rows[header_index]]
            canonical_headers = [canonical_header(cell) for cell in headers]
            for raw in rows[header_index + 1 :]:
                if not any(clean(cell) for cell in raw):
                    continue
                mapped = {}
                for i, cell in enumerate(raw):
                    if i >= len(headers):
                        continue
                    if headers[i]:
                        mapped[headers[i]] = clean(cell)
                    if canonical_headers[i]:
                        mapped[canonical_headers[i]] = clean(cell)
                item = row_from_mapping(company, mapped)
                if item:
                    parsed.append(item)
    return parsed


def read_real_rows():
    rows = read_xlsx_rows()
    if rows:
        return rows, "xlsx"
    return read_csv_rows(), "csv"


def merge_duplicate_invoice_rows(rows):
    grouped = {}
    order = []
    for row in rows:
        invoice = row["invoice_number"].strip()
        key = (
            row["company_name"],
            re.sub(r"[^a-z0-9]+", "", invoice.lower()) if invoice else str(uuid.uuid4()),
        )
        if key not in grouped:
            grouped[key] = {**row}
            grouped[key]["_source_rows"] = 1
            order.append(key)
            continue
        target = grouped[key]
        target["_source_rows"] += 1
        target["cases"] += row["cases"]
        target["weight_kg"] += row["weight_kg"]
        target["base_freight"] += row["base_freight"]
        target["extra_freight"] += row["extra_freight"]
        target["labour"] += row["labour"]
        target["detention"] += row["detention"]
        target["ack_received"] = target["ack_received"] and row["ack_received"]
        target["ack_status"] = "received" if target["ack_received"] else "pending"
        target["status"] = "completed" if target["ack_received"] else "locked"
        for field in ("e_way_bill_number", "vehicle_number", "vehicle_type", "lr_number", "remarks"):
            existing = [part for part in str(target.get(field, "")).split(" / ") if part]
            value = row.get(field, "")
            if value and value not in existing:
                existing.append(value)
            target[field] = " / ".join(existing)
        if not target.get("dispatch_date") and row.get("dispatch_date"):
            target["dispatch_date"] = row["dispatch_date"]
    return [grouped[key] for key in order]


def rest_select(token, table, query):
    return request("GET", f"{REST_URL}/{table}?{query}", token=token)


def rest_insert(token, table, rows):
    if not rows:
        return
    for i in range(0, len(rows), 100):
        request(
            "POST",
            f"{REST_URL}/{table}",
            token=token,
            body=rows[i : i + 100],
            prefer="return=minimal",
        )

def signup_transporter(email, name, password):
    try:
        request(
            "POST",
            f"{AUTH_URL}/signup",
            body={
                "email": email,
                "password": password,
                "data": {"full_name": name.title(), "business_name": name},
            },
        )
    except RuntimeError as exc:
        message = str(exc).lower()
        if "already" not in message and "registered" not in message and "exists" not in message:
            raise


def patch_profile(token, email, name):
    encoded = urllib.parse.quote(email, safe="")
    request(
        "PATCH",
        f"{REST_URL}/profiles?email=eq.{encoded}",
        token=token,
        body={
            "role": "transporter",
            "status": "rejected",
            "full_name": name.title(),
            "business_name": name,
        },
        prefer="return=minimal",
    )


def fetch_profile_by_email(token, email):
    encoded = urllib.parse.quote(email, safe="")
    rows = rest_select(token, "profiles", f"select=id,email,business_name,role,status&email=eq.{encoded}")
    return rows[0] if rows else None


def main():
    rows, source = read_real_rows()
    if not rows:
        raise SystemExit("No real data rows found.")
    dispatch_rows = merge_duplicate_invoice_rows(rows)

    if not ADMIN_PASSWORD:
        raise SystemExit(
            "Set SEED_ADMIN_PASSWORD in .env. The importer no longer uses a shared demo password."
        )
    admin_token = sign_in(ADMIN_EMAIL, ADMIN_PASSWORD)
    lm = fetch_profile_by_email(admin_token, LM_EMAIL) or fetch_profile_by_email(admin_token, ADMIN_EMAIL)
    if not lm:
        raise SystemExit("Could not find a demo logistics manager/admin profile for created_by.")
    created_by = lm["id"]

    transport_names = sorted({row["transport_name"] for row in dispatch_rows})
    transporters = {}
    for name in transport_names:
        email = f"seed-{slug(name)}@kaysons.demo"
        signup_transporter(email, name, secrets.token_urlsafe(32))
        for _ in range(10):
            profile = fetch_profile_by_email(admin_token, email)
            if profile:
                break
            time.sleep(0.5)
        else:
            raise SystemExit(f"Profile was not created for {email}.")
        patch_profile(admin_token, email, name)
        profile = fetch_profile_by_email(admin_token, email)
        transporters[name] = profile["id"]

    source_paths = [XLSX_FILE] if source == "xlsx" else [path for _, path in CSV_FILES]
    source_hash = hashlib.sha256()
    for path in source_paths:
        source_hash.update(path.read_bytes())
    existing_batches = rest_select(
        admin_token,
        "historical_import_batches",
        "select=id,status&source_key=eq.ludhiana-secondary-freight-2026-04",
    )
    if existing_batches and existing_batches[0]["status"] == "completed":
        raise SystemExit("This import batch is already complete; refusing to duplicate it.")
    if existing_batches:
        batch_id = existing_batches[0]["id"]
        existing_freights = rest_select(
            admin_token,
            "freights",
            "select=id&limit=1&import_batch_id=eq." + urllib.parse.quote(batch_id, safe=""),
        )
        if existing_freights:
            raise SystemExit(
                "This import batch has partial rows. Review or clear that batch before retrying."
            )
    else:
        batch_id = str(uuid.uuid4())
        rest_insert(admin_token, "historical_import_batches", [{
            "id": batch_id,
            "source_key": "ludhiana-secondary-freight-2026-04",
            "source_name": SEED_TAG,
            "source_period_start": "2026-04-01",
            "source_period_end": "2026-04-30",
            "source_sha256": source_hash.hexdigest(),
            "status": "processing",
            "created_by": created_by,
            "metadata": {"source_format": source},
        }])

    freights = []
    invoices = []
    charges = []
    for row in dispatch_rows:
        freight_id = str(uuid.uuid4())
        invoice_id = str(uuid.uuid4())
        transporter_id = transporters[row["transport_name"]]
        report_date = row["dispatch_date"] or row["bill_date"]
        delivered_stage = (
            {"delivered": {"submitted_at": f"{report_date}T12:00:00+00:00"}}
            if row["ack_received"]
            else {}
        )
        freights.append(
            {
                "id": freight_id,
                "created_by": created_by,
                "origin": ORIGIN,
                "destination_town": row["town"],
                "cases": row["cases"],
                "weight_kg": row["weight_kg"],
                "internal_calling_bid": row["base_freight"],
                "status": row["status"],
                "winner_profile_id": transporter_id,
                "vehicle_number": row["vehicle_number"] or None,
                "gr_bilty_number": row["lr_number"] or None,
                "vehicle_capacity_category": vehicle_capacity_category(row["weight_kg"]),
                "dispatched_at": f"{report_date}T09:00:00+00:00" if report_date else None,
                "locked_at": f"{report_date}T18:00:00+00:00" if report_date else None,
                "remarks": row["remarks"] or None,
                "stop_details": [],
                "import_metadata": {
                    "source_rows_merged": row.get("_source_rows", 1),
                    "source_file": source,
                },
                "record_origin": "historical_import",
                "data_completeness": "partial",
                "import_batch_id": batch_id,
                "created_at": f"{row['bill_date']}T00:00:00+00:00",
                "updated_at": f"{row['bill_date']}T00:00:00+00:00",
                "delivery_stages": delivered_stage,
                "company_name": row["company_name"],
                "party_name": row["party_name"],
                "bill_date": row["bill_date"],
                "dispatch_date": row["dispatch_date"],
                "vehicle_type": row["vehicle_type"] or None,
                "source_branch": SEED_TAG,
                "ack_status": row["ack_status"],
                "ack_received_at": f"{report_date}T12:00:00+00:00" if row["ack_received"] and report_date else None,
                "pod_received_date": report_date if row["ack_received"] else None,
                "pod_received_by": created_by if row["ack_received"] else None,
            }
        )
        invoices.append(
            {
                "id": invoice_id,
                "freight_id": freight_id,
                "invoice_number": row["invoice_number"],
                "gr_number": row["lr_number"] or None,
                "transporter_id": transporter_id,
                "town": row["town"],
                "weight_kg": row["weight_kg"],
                "cases": row["cases"],
                "base_freight": row["base_freight"],
                "freight_share": row["base_freight"],
                "validated": True,
                "e_way_bill_number": row["e_way_bill_number"] or None,
                "party_name": row["party_name"],
                "bill_date": row["bill_date"],
                "dispatch_date": row["dispatch_date"],
                "lr_number": row["lr_number"] or None,
                "vehicle_number": row["vehicle_number"] or None,
                "vehicle_type": row["vehicle_type"] or None,
                "remarks": row["remarks"] or None,
            }
        )
        for kind in ("extra_freight", "labour", "detention"):
            amount = row[kind]
            if amount:
                charges.append(
                    {
                        "freight_id": freight_id,
                        "invoice_id": invoice_id,
                        "kind": kind,
                        "amount": amount,
                        "remarks": row["remarks"] or None,
                        "added_by": created_by,
                        "approved": True,
                    }
                )

    rest_insert(admin_token, "freights", freights)
    rest_insert(admin_token, "invoices", invoices)
    rest_insert(admin_token, "freight_charges", charges)
    encoded_batch_id = urllib.parse.quote(batch_id, safe="")
    request(
        "PATCH",
        f"{REST_URL}/historical_import_batches?id=eq.{encoded_batch_id}",
        token=admin_token,
        body={
            "status": "completed",
            "row_count": len(freights),
            "completed_at": datetime.utcnow().isoformat() + "Z",
        },
        prefer="return=minimal",
    )

    summary = rest_select(
        admin_token,
        "admin_freight_ledger_view",
        "select=company_name,cases,weight_kg,total_freight,ack_status"
        "&origin=eq." + urllib.parse.quote(ORIGIN, safe="")
        + "&company_name=in.(Bunge,Cargill)",
    )
    print(
        json.dumps(
            {
                "seed_tag": SEED_TAG,
                "source": source,
                "source_rows": len(rows),
                "dispatch_rows": len(dispatch_rows),
                "merged_duplicate_invoice_rows": len(rows) - len(dispatch_rows),
                "transporters": transport_names,
                "freights_inserted": len(freights),
                "invoices_inserted": len(invoices),
                "charges_inserted": len(charges),
                "ledger_rows_visible": len(summary),
                "ack_received": sum(1 for row in summary if row.get("ack_status") == "received"),
                "ack_pending": sum(1 for row in summary if row.get("ack_status") != "received"),
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"Seed failed: {exc}", file=sys.stderr)
        raise
