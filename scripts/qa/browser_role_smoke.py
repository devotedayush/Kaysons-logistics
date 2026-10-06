"""Read-only authenticated role smoke checks; passwords are never included in artifacts.
Requires agent-browser, a running app, and QA_CREDENTIALS_FILE pointing at the
local reviewer Role | Email | Password markdown table. Output: QA_OUTPUT_DIR.
"""
import subprocess,time,json,re,os
from pathlib import Path
base=['agent-browser','--session','kaysons-qa']
out=Path(os.environ.get('QA_OUTPUT_DIR','/tmp/kaysons-fix-qa'));out.mkdir(exist_ok=True)
creds={c[0]:c[1:] for l in Path(os.environ['QA_CREDENTIALS_FILE']).read_text().splitlines() if l.startswith('|') and len(c:=[v.strip().strip('`') for v in l.strip('|').split('|')])==3}
def cmd(*a):
 p=subprocess.run(base+list(a),capture_output=True,text=True,timeout=40)
 return p.stdout

def snap():
 s=cmd('snapshot')
 return re.sub(r'(textbox "Password"[^\n]*):.*',r'\1: [redacted]',s)
routes={'Administrator':['/admin','/admin/users','/admin/bids','/admin/ledger','/admin/analytics','/admin/clawd','/admin/notifications','/admin/profile','/account/privacy'], 'Accountant':['/acct/ledger','/acct/analytics','/acct/clawd','/acct/notifications','/acct/profile','/account/privacy'], 'Logistics Manager':['/lm/home','/lm/bids','/lm/fleet','/lm/ledger','/lm/dispatch','/lm/bid/new','/lm/notifications','/lm/profile','/account/privacy'], 'Dispatch Manager':['/dm/home','/dm/fleet','/dm/profile','/account/privacy'], 'Transporter':['/home','/bids','/fleet','/vehicles','/drivers','/profile','/account/privacy']}
role_filter=os.environ.get('QA_ROLES','').split(',')
route_filter=os.environ.get('QA_ROUTES','').split(',')
results=[]
for role,paths in routes.items():
 if role_filter != [''] and role not in role_filter: continue
 paths=[p for p in paths if route_filter == [''] or p in route_filter]
 if not paths: continue
 cmd('eval',"window.location.hash='/login'");time.sleep(.8)
 email,password=creds[role]
 cmd('click','input[type="text"]');cmd('fill','input[type="text"]',email);cmd('click','input[type="password"]');cmd('fill','input[type="password"]',password)
 cmd('find','role','button','click','--name','Sign in');time.sleep(5)
 loginurl=cmd('get','url').strip()
 if '/login' in loginurl:
  time.sleep(3);loginurl=cmd('get','url').strip()
 print(role,'login',loginurl,flush=True)
 if '/login' in loginurl:
  print('LOGIN FAILED',snap(),flush=True);continue
 for size in ['desktop','phone']:
  cmd('set','viewport',*(['1440','1000'] if size=='desktop' else ['390','844']))
  for route in paths:
   cmd('console','--clear')
   cmd('eval','window.location.hash='+json.dumps(route));time.sleep(3)
   s=snap()
   for attempt in range(15):
    if not re.search(r'progressbar(?:\s+\[.*?\])?\s*$|\bLoading\b',s,re.I): break
    time.sleep(2);s=snap()
   loading=bool(re.search(r'progressbar(?:\s+\[.*?\])?\s*$|\bLoading\b',s,re.I))
   name=role.lower().replace(' ','-')+'-'+size+'-'+route.strip('/').replace('/','-')
   (out/(name+'.txt')).write_text(s)
   cmd('screenshot',str(out/(name+'.png')))
   errors=[x.strip() for x in s.splitlines() if re.search(r'error|exception|failed|desktop|available on',x,re.I)]
   console=cmd('console')
   runtime_errors=[line for line in console.splitlines() if re.search(r'overflowed|used after being disposed|EXCEPTION CAUGHT|There is nothing to pop',line,re.I)]
   result={'unresolved_loading':loading,'runtime_errors':runtime_errors,'role':role,'size':size,'route':route,'actual_url':cmd('get','url').strip(),'semantic_lines':len(s.splitlines()),'signals':errors[:6], 'load_failed': 'Could not load the dashboard' in s}
   results.append(result);(out/'smoke-results.json').write_text(json.dumps(results,indent=2));print(json.dumps(result),flush=True)
(out/'smoke-results.json').write_text(json.dumps(results,indent=2))

failed=[r for r in results if r['runtime_errors'] or r['unresolved_loading'] or r['load_failed'] or '/login' in r['actual_url']]
print(json.dumps({'routes_checked':len(results),'runtime_failures':len(failed)}))
raise SystemExit(1 if failed else 0)
