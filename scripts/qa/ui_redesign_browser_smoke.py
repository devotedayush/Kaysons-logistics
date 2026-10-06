"""Read-only UI navigation checks on phone and laptop. Never exports credentials."""
import json, os, re, subprocess, time
from pathlib import Path

CLI = '/Users/ayushmansingh/.npm-global/bin/agent-browser'
BASE = [CLI, '--session', 'kaysons-ui-redesign']
ORIGIN = os.environ.get('QA_ORIGIN', 'http://127.0.0.1:8091')
OUT = Path(os.environ.get('QA_OUTPUT_DIR', 'output/qa/ui-redesign-browser'))
OUT.mkdir(parents=True, exist_ok=True)
credentials = {}
for line in Path(os.environ['QA_CREDENTIALS_FILE']).read_text().splitlines():
    if line.startswith('|'):
        cells = [v.strip().strip('`') for v in line.strip('|').split('|')]
        if len(cells) == 3:
            credentials[cells[0]] = cells[1:]
secrets = [v for row in credentials.values() for v in row if len(v) > 5]

def redact(text):
    for value in secrets:
        text = text.replace(value, '[redacted]')
    return text

def call(*args):
    result = subprocess.run(BASE + list(args), capture_output=True, text=True, timeout=35)
    if result.returncode:
        raise RuntimeError(redact(result.stderr or result.stdout))
    return result.stdout

def snapshot():
    return redact(call('snapshot'))

def click_name(name):
    current = call('snapshot', '-i')
    match = re.search(r'- button ' + re.escape(json.dumps(name)) + r' \[ref=(\w+)\]', current)
    if not match:
        raise RuntimeError('Missing expected button: ' + name)
    call('click', '@' + match[1])

routes = {
    'Transporter': ['/home', '/bids', '/fleet', '/vehicles', '/drivers', '/profile', '/account/privacy', '/account/phone'],
    'Logistics Manager': ['/lm/home', '/lm/bids', '/lm/fleet', '/lm/ledger', '/lm/dispatch', '/lm/bid/new', '/lm/transporters', '/lm/vehicles', '/lm/notifications', '/lm/profile'],
    'Dispatch Manager': ['/dm/home', '/dm/fleet', '/dm/profile'],
    'Accountant': ['/acct/ledger', '/acct/analytics', '/acct/clawd', '/acct/notifications', '/acct/profile'],
    'Administrator': ['/admin', '/admin/users', '/admin/bids', '/admin/ledger', '/admin/analytics', '/admin/clawd', '/admin/notifications', '/admin/profile'],
}
results = []
call('reload')
time.sleep(2)
call('eval', "document.querySelector('flt-semantics-placeholder')?.click()")
for role, paths in routes.items():
    role_filter = os.environ.get("QA_ROLES", "").split(",")
    route_filter = os.environ.get("QA_ROUTES", "").split(",")
    if role_filter != [""] and role not in role_filter:
        continue
    paths = [route for route in paths if route_filter == [""] or route in route_filter]
    if not paths:
        continue
    call('set', 'viewport', '1440', '1000')
    call('eval', "window.location.hash='/login'")
    time.sleep(1)
    current = call('snapshot', '-i')
    if 'Use email and password instead' in current:
        click_name('Use email and password instead')
    email, password = credentials[role]
    call('click', 'input[type="text"]')
    call('fill', 'input[type="text"]', email)
    call('click', 'input[type="password"]')
    call('fill', 'input[type="password"]', password)
    click_name('Sign in')
    for _ in range(12):
        time.sleep(.6)
        if '/login' not in call('get', 'url'):
            break
    if '/login' in call('get', 'url'):
        raise RuntimeError('Login failed for ' + role)
    print(json.dumps({'role': role, 'login': 'passed'}), flush=True)
    for size, width, height in [('laptop', '1440', '1000'), ('phone', '390', '844')]:
        call('set', 'viewport', width, height)
        for route in paths:
            call('console', '--clear')
            call('errors', '--clear')
            call('eval', 'window.location.hash=' + json.dumps(route))
            time.sleep(1.3)
            call('wait', '--load', 'networkidle')
            time.sleep(.4)
            current = snapshot()
            for _ in range(60):
                if not re.search(r'progressbar(?:\s+\[.*?\])?\s*$', current, re.M) and len(current.splitlines()) > 6 and not re.search(r'\bLoading\b', current) and not re.search(r'button \"Refresh\"[^\n]*\[disabled\]', current) and (not route.endswith('/analytics') or 'Where the work and cost come from' in current) and (not route.endswith('/ledger') or re.search(r'\d+ records ·|No ledger rows|Ledger could not be loaded', current)):
                    break
                time.sleep(.7)
                current = snapshot()
            actual = call('get', 'url').strip()
            console = redact(call('console'))
            page_errors = redact(call('errors')).strip()
            runtime = [line for line in console.splitlines() if re.search(r'overflowed|used after being disposed|EXCEPTION CAUGHT|There is nothing to pop', line, re.I)]
            current = snapshot()
            loading = bool(re.search(r'progressbar(?:\s+\[.*?\])?\s*$', current, re.M)) or len(current.splitlines()) <= 6
            loading = loading or bool(re.search(r'\bLoading\b', current))
            loading = loading or bool(re.search(r'button \"Refresh\"[^\n]*\[disabled\]', current))
            if route.endswith('/ledger'):
                loading = loading or not bool(re.search(r'\d+ records ·|No ledger rows|Ledger could not be loaded', current))
            if route.endswith('/analytics'):
                loading = loading or 'Where the work and cost come from' not in current
            failure = bool(runtime or page_errors or loading or route not in actual or re.search(r'Could not load|Failed to load|Unable to load|Something went wrong', current, re.I))
            name = role.lower().replace(' ', '-') + '-' + size + '-' + route.strip('/').replace('/', '-')
            (OUT / (name + '.txt')).write_text(current)
            call('screenshot', str((OUT / (name + '.png')).resolve()))
            result = {'role': role, 'size': size, 'route': route, 'actual_url': actual, 'semantic_lines': len(current.splitlines()), 'unresolved_loading': loading, 'runtime_errors': runtime, 'page_errors': page_errors, 'passed': not failure}
            results.append(result)
            (OUT / 'results.json').write_text(json.dumps(results, indent=2))
            print(json.dumps(result), flush=True)
failed = [r for r in results if not r['passed']]
print(json.dumps({'checked': len(results), 'failed': len(failed)}), flush=True)
raise SystemExit(1 if failed else 0)
