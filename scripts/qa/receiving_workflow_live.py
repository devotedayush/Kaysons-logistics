"""Normal JWT acceptance for the receiving workflow; never prints credentials.

Creates exactly one QA freight. Writes its ID to QA_RESULTS_FILE immediately so
the caller can remove workflow children and freight through a scoped SQL cleanup
after UI checks. Byte uploads are removed with the transporter's Storage API.
"""
import base64
import json
import os
import uuid
import urllib.request
import urllib.error
from datetime import datetime, timezone
from pathlib import Path

cfg = dict(l.split('=', 1) for l in Path('.env').read_text().splitlines()
           if '=' in l and not l.startswith('#'))
url = cfg['SUPABASE_URL'].strip('"\'')
key = cfg['SUPABASE_ANON_KEY'].strip('"\'')
creds = {c[0]: c[1:] for l in Path(os.environ['QA_CREDENTIALS_FILE']).read_text().splitlines()
         if l.startswith('|') and len(c := [v.strip().strip('`') for v in l.strip('|').split('|')]) == 3}
actors = {}
results = []
fid = str(uuid.uuid4())
output = Path(os.environ.get('QA_RESULTS_FILE', '/tmp/kaysons-receiving-live-results.json'))
output.parent.mkdir(parents=True, exist_ok=True)
def persist():
    output.write_text(json.dumps({'freight_id': fid, 'results': results}, indent=2))
persist()

def req(path, role=None, body=None, method=None, raw=None):
    headers = {'apikey': key, 'Authorization': 'Bearer ' + (actors[role]['access_token'] if role else key),
               'Content-Type': 'image/png' if raw is not None else 'application/json'}
    data = raw if raw is not None else json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(url + path, data=data, headers=headers,
                                     method=method or ('POST' if data is not None else 'GET'))
    try:
        with urllib.request.urlopen(request, timeout=45) as r:
            return r.status, json.loads(r.read() or b'null')
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read())

def success(path, role, body=None, method=None, raw=None):
    status, data = req(path, role, body, method, raw)
    assert status in (200, 201, 204), (path.split('?')[0], status, data)
    return data
def check(label, condition):
    assert condition, label
    results.append({'test': label, 'passed': True})
    persist()
    print('PASS:', label, flush=True)
def rpc(name, role, **params):
    return success('/rest/v1/rpc/' + name, role, params)
def freight():
    return success('/rest/v1/freights?select=*&id=eq.' + fid, 'Logistics Manager')[0]

for role in ['Administrator', 'Logistics Manager', 'Accountant', 'Dispatch Manager', 'Transporter']:
    email, password = creds[role]
    status, auth = req('/auth/v1/token?grant_type=password', body={'email': email, 'password': password})
    assert status == 200, ('Login failed', role, status)
    actors[role] = auth
lm = actors['Logistics Manager']['user']['id']
tid = actors['Transporter']['user']['id']
proof = tid + '/' + fid + '/receiving/qa-proof.png'
uploaded = False
try:
    success('/rest/v1/freights', 'Logistics Manager', {
        'id': fid, 'created_by': lm, 'origin': 'QA OCT04 RECEIVING ONLY',
        'destination_town': 'Point C', 'company_name': 'QA ONLY', 'cases': 50,
        'weight_kg': 2.5, 'status': 'awarded', 'winner_profile_id': tid,
        'accepted_freight_amount': 3400, 'stops': ['Point B'],
        'stop_details': [{'name': 'Point B', 'cases': 30, 'weight_kg': 1.5},
                         {'name': 'Point C', 'cases': 20, 'weight_kg': 1}],
    })
    check('future award initializes receiving workflow', freight()['delivery_workflow_version'] == 1)
    rpc('save_delivery_plan', 'Logistics Manager', p_freight_id=fid, p_receivers=[
        {'stop_index': 0, 'town': 'Point B', 'party_name': 'QA Customer B1', 'planned_cases': 20,
         'planned_weight_mt': 1, 'lr_numbers': ['QA-LR-1'], 'e_way_bill_numbers': ['QA-EWB-1', 'QA-EWB-2']},
        {'stop_index': 0, 'town': 'Point B', 'party_name': 'QA Customer B2', 'planned_cases': 10, 'planned_weight_mt': .5},
        {'stop_index': 1, 'town': 'Point C', 'party_name': 'QA Customer C', 'planned_cases': 20, 'planned_weight_mt': 1},
    ])
    receivers = success('/rest/v1/freight_delivery_receivers?select=*&freight_id=eq.' + fid + '&order=stop_index,party_name', 'Transporter')
    check('same-town customers remain separate and references remain grouped',
          len(receivers) == 3 and len(receivers[0]['e_way_bill_numbers']) == 2)
    status, _ = req('/rest/v1/freight_delivery_receivers?id=eq.' + receivers[0]['id'], 'Transporter',
                    {'pod_review_status': 'accepted'}, method='PATCH')
    check('direct receiver-table tampering denied', status >= 400)
    status, _ = req('/rest/v1/rpc/add_journey_update', 'Transporter', {'p_freight_id': fid, 'p_data': {'location': 'Point A'}})
    check('trip reporting before dispatch denied', status >= 400)
    success('/rest/v1/freights?id=eq.' + fid, 'Transporter', {
        'status': 'dispatched', 'vehicle_number': 'QA01AA1234', 'driver_name': 'QA Driver',
        'driver_phone': '9999999999', 'dispatched_at': datetime.now(timezone.utc).isoformat(),
        'delivery_stages': {'dispatched': {'lorry_number': 'QA01AA1234', 'driver_name': 'QA Driver',
                                         'driver_phone': '9999999999', 'submitted_at': datetime.now(timezone.utc).isoformat()}},
    }, method='PATCH')
    rpc('lock_freight_invoices', 'Logistics Manager', p_freight_id=fid, p_invoices=[
        {'invoice_number': 'QA-OCT04-' + fid + '-B', 'party_name': 'QA B', 'town': 'Point B',
         'cases': 30, 'weight_kg': 1.5, 'freight_share': 2040},
        {'invoice_number': 'QA-OCT04-' + fid + '-C', 'party_name': 'QA C', 'town': 'Point C',
         'cases': 20, 'weight_kg': 1, 'freight_share': 1360},
    ], p_charges=[])
    check('transporter cannot read goods invoice values',
          success('/rest/v1/invoices?select=*&freight_id=eq.' + fid, 'Transporter') == [])
    png = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=')
    success('/storage/v1/object/delivery-documents/' + proof, 'Transporter', raw=png)
    uploaded = True
    for i, receiver in enumerate(receivers):
        data = {'recipient_name': 'QA Receiver ' + str(i), 'delivered_at': datetime.now(timezone.utc).isoformat(),
                'outcome': 'full', 'proof_paths': [] if i == 0 else [proof]}
        if i == 1:
            data.update(outcome='partial', cases_received=8, cases_rejected=2, discrepancy_reason='Two cases refused')
        rpc('save_delivery_report', 'Transporter', p_receiver_id=receiver['id'], p_data=data)
    check('reported deliveries and uploaded proof keep acknowledgement pending', freight()['ack_status'] == 'pending')
    status, _ = req('/rest/v1/rpc/review_delivery_pod', 'Accountant',
                    {'p_receiver_id': receivers[0]['id'], 'p_decision': 'accepted'})
    check('office cannot accept missing POD', status >= 400)
    status, _ = req('/rest/v1/rpc/review_delivery_pod', 'Accountant',
                    {'p_receiver_id': receivers[1]['id'], 'p_decision': 'accepted'})
    check('office cannot accept partial delivery', status >= 400)
    status, _ = req('/rest/v1/rpc/review_delivery_pod', 'Dispatch Manager',
                    {'p_receiver_id': receivers[2]['id'], 'p_decision': 'accepted'})
    check('dispatch manager cannot review POD', status >= 400)
    rpc('add_journey_update', 'Transporter', p_freight_id=fid, p_data={
        'location': 'Point B', 'next_destination': 'Point C', 'delay_reason': 'Traffic near unloading point',
        'contractors': [{'name': 'QA Carrier 1', 'from': 'QA OCT04 RECEIVING ONLY', 'to': 'Point B'},
                        {'name': 'QA Carrier 2', 'from': 'Point B', 'to': 'Point C'}], 'photo_paths': [proof],
    })
    rpc('submit_freight_expense', 'Transporter', p_freight_id=fid, p_data={
        'kind': 'point_charge', 'amount': 120, 'reason': 'Extra unloading point',
        'receiver_id': receivers[1]['id'], 'receipt_paths': [proof],
    })
    claims = success('/rest/v1/freight_expense_claims?select=*&freight_id=eq.' + fid, 'Accountant')
    rpc('review_freight_expense', 'Accountant', p_claim_id=claims[0]['id'], p_decision='approved')
    rpc('review_freight_expense', 'Accountant', p_claim_id=claims[0]['id'], p_decision='approved')
    charges = success('/rest/v1/freight_charges?select=*&freight_id=eq.' + fid, 'Accountant')
    check('expense approval retries create only one canonical charge', len(charges) == 1 and charges[0]['amount'] == 120)
    check('accepted base freight remains unchanged', freight()['accepted_freight_amount'] == 3400)
    signed = success('/storage/v1/object/sign/delivery-documents/' + proof, 'Accountant', {'expiresIn': 60})
    check('accountant can open private transporter proof', bool(signed.get('signedURL')))
    rpc('save_delivery_report', 'Transporter', p_receiver_id=receivers[0]['id'], p_data={'proof_paths': [proof]})
    rpc('save_delivery_report', 'Transporter', p_receiver_id=receivers[1]['id'], p_data={'outcome': 'full'})
    # Keep these reports pending for browser review. Set QA_COMPLETE=1 to test
    # acceptance immediately; browser run uses the office's real Accept buttons.
    if os.environ.get('QA_COMPLETE') == '1':
        for receiver in receivers:
            rpc('review_delivery_pod', 'Accountant', p_receiver_id=receiver['id'], p_decision='accepted')
        check('all accepted customers complete the trip', freight()['status'] == 'completed' and freight()['ack_status'] == 'received')
    rows = success('/rest/v1/admin_freight_ledger_view?select=cases,weight_kg,total_freight&freight_id=eq.' + fid, 'Accountant')
    check('shared trip freight and approved expenses reconcile without double counting',
          sum(r['cases'] for r in rows) == 50 and sum(r['weight_kg'] for r in rows) == 2.5 and sum(r['total_freight'] for r in rows) == 3520)
finally:
    # File retained only while browser QA is explicitly requested.
    if uploaded and os.environ.get('QA_KEEP_FOR_BROWSER') != '1':
        success('/storage/v1/object/delivery-documents', 'Transporter', {'prefixes': [proof]}, method='DELETE')
    persist()
    print('Fixture manifest:', str(output), flush=True)
