"""Normal-JWT multi-invoice/multi-stop acceptance; removes its own QA rows/files.
Credentials come from QA_CREDENTIALS_FILE; never print passwords or tokens.
"""
import base64,json,os,uuid,urllib.request,urllib.error
from pathlib import Path
cfg=dict(l.split('=',1) for l in Path('.env').read_text().splitlines() if '=' in l and not l.startswith('#'))
url=cfg['SUPABASE_URL'].strip('"\'');key=cfg['SUPABASE_ANON_KEY'].strip('"\'')
creds={c[0]:c[1:] for l in Path(os.environ['QA_CREDENTIALS_FILE']).read_text().splitlines() if l.startswith('|') and len(c:=[v.strip().strip('`') for v in l.strip('|').split('|')])==3}
actors={};results=[]
def req(path,role=None,body=None,method=None,raw=None):
 headers={'apikey':key,'Authorization':'Bearer '+(actors[role]['access_token'] if role else key),'Content-Type':'image/png' if raw is not None else 'application/json'}
 data=raw if raw is not None else json.dumps(body).encode() if body is not None else None
 request=urllib.request.Request(url+path,data=data,headers=headers,method=method or ('POST' if data is not None else 'GET'))
 try:
  with urllib.request.urlopen(request,timeout=45) as r:return r.status,json.loads(r.read() or b'null')
 except urllib.error.HTTPError as e:return e.code,json.loads(e.read())
def success(label,path,role,body=None,method=None,raw=None):
 status,data=req(path,role,body,method,raw)
 assert status in (200,201,204),(label,status,data.get('code') if isinstance(data,dict) else None)
 return data
def check(label,condition):
 assert condition,label
 results.append({'test':label,'passed':True});print('PASS:',label,flush=True)
for role in ['Administrator','Logistics Manager','Accountant','Transporter']:
 email,password=creds[role];status,auth=req('/auth/v1/token?grant_type=password',body={'email':email,'password':password})
 assert status==200,('Login failed',role,status)
 actors[role]=auth
fids=[str(uuid.uuid4()),str(uuid.uuid4())];fid=fids[0];tid=actors['Transporter']['user']['id'];lm=actors['Logistics Manager']['user']['id'];files=[]
try:
 for f in fids:
  success('Create QA awarded freight','/rest/v1/freights','Logistics Manager',{'id':f,'created_by':lm,'origin':'QA OCT ACCEPTANCE ONLY','destination_town':'Second stop','company_name':'QA ONLY','cases':200,'weight_kg':3,'status':'awarded','winner_profile_id':tid,'accepted_freight_amount':3400,'stop_details':[{'name':'First stop','cases':100,'weight_kg':1.5},{'name':'Second stop','cases':100,'weight_kg':1.5}]})
 inv='QA-LIVE-OCT-'+fid
 payload={'p_freight_id':fid,'p_invoices':[{'invoice_number':inv,'party_name':'QA A','town':'First stop','cases':100,'weight_kg':1.5,'freight_share':1700,'e_way_bill_numbers':['QA-EWB-A1','QA-EWB-A2'],'gr_bilty_numbers':['QA-SHARED-GR']},{'invoice_number':inv+'-B','party_name':'QA B','town':'Second stop','cases':100,'weight_kg':1.5,'freight_share':1700,'e_way_bill_numbers':['QA-EWB-B1'],'gr_bilty_numbers':['QA-SHARED-GR']}],'p_charges':[{'kind':'toll','amount':100}]}
 lock=success('Lock','/rest/v1/rpc/lock_freight_invoices','Logistics Manager',payload)
 check('two invoices lock atomically',lock['invoice_count']==2 and lock['status']=='locked')
 invoices=success('Read invoices','/rest/v1/invoices?select=id,invoice_number&freight_id=eq.'+fid,'Accountant')
 docs=success('Read mapped docs','/rest/v1/invoice_documents?select=invoice_id,document_kind,document_number&invoice_id=in.('+','.join(i['id'] for i in invoices)+')','Accountant')
 check('accountant sees invoice-wise multiple e-way mappings',len(docs)==5 and sum(d['document_kind']=='e_way_bill' for d in docs)==3)
 duplicate={**payload,'p_freight_id':fids[1],'p_invoices':[{'invoice_number':inv,'town':'First stop','freight_share':3400}],'p_charges':[]}
 status,error=req('/rest/v1/rpc/lock_freight_invoices','Logistics Manager',duplicate)
 check('duplicate finalized invoice rejected',status>=400 and error.get('code')=='23505')
 invalid={**duplicate,'p_invoices':[{'invoice_number':'---','town':'First stop','freight_share':3400}]}
 status,error=req('/rest/v1/rpc/lock_freight_invoices','Logistics Manager',invalid)
 check('punctuation-only invoice rejected',status>=400 and error.get('code')=='23514')
 check('failed invoice lock rolls back all child rows',success('Rollback check','/rest/v1/invoices?select=id&freight_id=eq.'+fids[1],'Administrator')==[])
 check('transporter cannot read own goods invoices',success('Read isolation','/rest/v1/invoices?select=id&freight_id=eq.'+fid,'Transporter')==[])
 check('transporter cannot read office document mappings',success('Doc isolation','/rest/v1/invoice_documents?select=invoice_id&invoice_id=in.('+','.join(i['id'] for i in invoices)+')','Transporter')==[])
 def stop(index,**fields):
  return {'p_freight_id':fid,'p_stop_index':index,'p_data':{'destination':['First stop','Second stop'][index],'receiver_name':'QA receiver '+str(index),**fields}}
 status,error=req('/rest/v1/rpc/save_delivered_stop','Transporter',stop(0,pod_photo_path=tid+'/'+fid+'/delivered/pod/nonexistent.png'))
 check('nonexistent POD rejected',status>=400 and error.get('code')=='22023')
 png=base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=')
 for idx in range(2):
  path=tid+'/'+fid+'/delivered/pod/qa-'+str(idx)+'.png'
  success('Upload QA proof','/storage/v1/object/delivery-documents/'+path,'Transporter',raw=png)
  files.append(path)
 result=success('First stop','/rest/v1/rpc/save_delivered_stop','Transporter',stop(0,pod_photo_path=files[0],invoice_numbers=['IGNORED']))
 check('first stop retains partial status and hides invoice input',not result['complete'] and 'invoice_numbers' not in result['delivered_stops'][0])
 status,error=req('/rest/v1/freights?id=eq.'+fid,'Transporter',{'ack_status':'received','pod_file_path':files[0],'pod_received_by':tid,'pod_received_date':'2026-10-01'},method='PATCH')
 check('direct premature multi-stop acknowledgement rejected',status>=400 and error.get('code')=='22023')
 result=success('Second stop missing proof','/rest/v1/rpc/save_delivered_stop','Transporter',stop(1))
 check('delivery completion without all proofs stays POD pending',result['complete'] and not result['all_pods_received'])
 result=success('Later second proof','/rest/v1/rpc/save_delivered_stop','Transporter',stop(1,pod_photo_path=files[1]))
 check('actual uploaded proofs complete POD acknowledgement',result['all_pods_received'])
 result=success('Receiver correction','/rest/v1/rpc/save_delivered_stop','Transporter',stop(0,receiver_name='Corrected QA receiver'))
 check('receiver correction preserves both uploaded proofs',result['all_pods_received'] and len(result['delivered_stops'])==2)
 rows=success('Ledger verification','/rest/v1/admin_freight_ledger_view?select=cases,weight_kg,total_freight,ack_status&freight_id=eq.'+fid,'Accountant')
 check('live reports reconcile freight and proof',len(rows)==2 and sum(r['cases'] for r in rows)==200 and sum(r['weight_kg'] for r in rows)==3 and sum(r['total_freight'] for r in rows)==3500 and all(r['ack_status']=='received' for r in rows))
finally:
 for f in fids:
  for table in ['freight_charges','invoices']:
   success('Cleanup '+table,'/rest/v1/'+table+'?freight_id=eq.'+f,'Administrator',method='DELETE')
  success('Cleanup freight','/rest/v1/freights?id=eq.'+f,'Administrator',method='DELETE')
 if files:success('Cleanup QA uploads','/storage/v1/object/delivery-documents','Transporter',{'prefixes':files},method='DELETE')
 check('QA freight fixtures removed',success('Cleanup verification','/rest/v1/freights?select=id&id=in.('+','.join(fids)+')','Administrator')==[])
 output=Path(os.environ.get('QA_RESULTS_FILE','/tmp/kaysons-client-live-results.json'))
 output.write_text(json.dumps(results,indent=2))
