"""Read-only ledger interactions after the role smoke test signs in as Admin."""
import json, re, subprocess, time
from pathlib import Path
CLI = '/Users/ayushmansingh/.npm-global/bin/agent-browser'
BASE = [CLI, '--session', 'kaysons-ui-redesign']
OUT = Path('output/qa/ledger-declutter-browser').resolve()
OUT.mkdir(parents=True, exist_ok=True)

def call(*args):
    result = subprocess.run(BASE + list(args), capture_output=True, text=True, timeout=35)
    if result.returncode:
        raise RuntimeError(result.stderr or result.stdout)
    return result.stdout

def snap():
    return call('snapshot')

def click(name, role='button'):
    current = call('snapshot', '-i')
    match = re.search(r'- '+role+' '+re.escape(json.dumps(name))+r' \[ref=(\w+)\]', current)
    if not match: raise AssertionError('Missing '+role+': '+name)
    call('click', '@'+match[1])

def wait_records():
    for _ in range(60):
        call('eval', "document.querySelector('flt-semantics-placeholder')?.click()")
        current = snap()
        if re.search(r'\d+ records ·', current): return current
        time.sleep(.5)
    raise AssertionError('Ledger records never finished loading')

def capture(name):
    (OUT/(name+'.txt')).write_text(snap())
    call('screenshot', str(OUT/(name+'.png')))

results=[]
for device,width,height in [('laptop','1440','1000'),('phone','390','844')]:
    call('set','viewport',width,height)
    call('open', 'http://127.0.0.1:8091/#/admin/ledger')
    call('reload')
    time.sleep(1)
    call('eval', "document.querySelector('flt-semantics-placeholder')?.click()")
    call('console','--clear'); call('errors','--clear')
    call('eval',"window.location.hash='/admin/ledger'")
    current=wait_records()
    click('Records')
    time.sleep(.3)
    current=snap()
    assert 'Records' in current and 'trips need proof' in current
    capture('interaction-'+device+'-records')
    click('Review')
    time.sleep(.4)
    current=snap()
    assert 'Record details' in current and 'Edit ledger entry' in current and 'Review delivery' in current
    assert 'Invoice & customer' in current and 'Trip & delivery' in current
    capture('interaction-'+device+'-details')
    click('Close details')
    time.sleep(.5)
    call('scroll','up','2000')
    time.sleep(.3)
    click('Reports')
    time.sleep(.3)
    current=snap()
    assert 'Transporter-wise summary' in current and 'Export reports' in current
    capture('interaction-'+device+'-reports')
    click('Export reports Export reports')
    time.sleep(.4)
    current=snap()
    for text in ['Invoice-wise CSV','POD pending CSV','Route-wise CSV']:
        assert text in current, 'Missing report '+text
    # Clicking the selected Reports tab after a page refresh avoids reliance
    # on Escape dismissing Flutter's semantic popup in headless Chrome.
    call('reload')
    time.sleep(1)
    call('eval', "document.querySelector('flt-semantics-placeholder')?.click()")
    wait_records()
    click('More More')
    time.sleep(.2)
    click('All columns', 'menuitem')
    time.sleep(.3)
    current=snap()
    assert 'Back to records' in current and 'Bill' in current
    capture('interaction-'+device+'-full-columns')
    click('Back to records')
    time.sleep(.2)
    click('Filters')
    time.sleep(.2)
    current=snap()
    assert 'Company' in current and 'Original POD receipt' in current
    capture('interaction-'+device+'-filters')
    click('Filters')
    time.sleep(.2)
    errors=call('errors').strip()
    runtime=[line for line in call('console').splitlines() if re.search(r'overflowed|EXCEPTION CAUGHT|used after being disposed',line,re.I)]
    assert not errors and not runtime, (errors,runtime)
    results.append({'device':device,'checks':['records','details','reports','export menu','full columns','advanced filters'],'runtime_errors':runtime,'page_errors':errors,'passed':True})
    print(json.dumps(results[-1]),flush=True)
(OUT/'interactions.json').write_text(json.dumps(results,indent=2))
