"""Verify competing finalized invoice saves with normal admin auth; clean fixtures in finally.
Requires QA_CREDENTIALS_FILE with the reviewer credentials table and local .env.
"""
import json,uuid,urllib.request,urllib.error,concurrent.futures,threading,os
from pathlib import Path
cfg=dict(l.split('=',1) for l in Path('.env').read_text().splitlines() if '=' in l and not l.startswith('#'))
url=cfg['SUPABASE_URL'].strip('"\'');key=cfg['SUPABASE_ANON_KEY'].strip('"\'')
rows={c[0]:c[1:] for l in Path(os.environ['QA_CREDENTIALS_FILE']).read_text().splitlines() if l.startswith('|') and len(c:=[v.strip().strip('`') for v in l.strip('|').split('|')])==3}
email,password=rows['Administrator']
def request(path,body=None,method='POST',token=None):
 req=urllib.request.Request(url+path,data=json.dumps(body).encode() if body is not None else None,method=method,headers={'apikey':key,'Authorization':'Bearer '+(token or key),'Content-Type':'application/json'})
 try:
  with urllib.request.urlopen(req,timeout=30) as r:return r.status,json.loads(r.read() or b'null')
 except urllib.error.HTTPError as e:return e.code,json.loads(e.read())
status,auth=request('/auth/v1/token?grant_type=password',{'email':email,'password':password});assert status==200
jwt=auth['access_token'];ids=[str(uuid.uuid4()) for _ in range(2)];invoice='QA-CONCURRENT-'+str(uuid.uuid4());barrier=threading.Barrier(2)
def save(fid):
 payload={'p_freight_id':fid,'p_is_new':True,'p_freight':{'origin':'QA CONCURRENCY','destination_town':'QA ONLY','company_name':'QA ONLY','cases':1,'weight_kg':1,'ack_status':'pending'},'p_invoices':[{'id':str(uuid.uuid4()),'invoice_number':invoice,'town':'QA ONLY','cases':1,'weight_kg':1,'base_freight':100}],'p_charges':[],'p_products':[],'p_overrides':[],'p_settlement':None}
 barrier.wait();return request('/rest/v1/rpc/save_manual_ledger_entry',payload,token=jwt)
try:
 with concurrent.futures.ThreadPoolExecutor(2) as pool:results=list(pool.map(save,ids))
 assert sum(status==200 for status,_ in results)==1,[(s,d.get('code') if isinstance(d,dict) else 'saved') for s,d in results]
 assert any(isinstance(d,dict) and d.get('code')=='23505' for _,d in results), 'Expected duplicate rejection'
 print('PASS: two simultaneous normal-admin saves produce one committed freight and one duplicate rejection')
finally:
 for fid in ids:
  for table in ['freight_charges','invoices']:
   code,_=request('/rest/v1/'+table+'?freight_id=eq.'+fid,method='DELETE',token=jwt);assert code in (200,204)
  code,_=request('/rest/v1/freights?id=eq.'+fid,method='DELETE',token=jwt);assert code in (200,204)
 print('Synthetic concurrency records cleaned up')
