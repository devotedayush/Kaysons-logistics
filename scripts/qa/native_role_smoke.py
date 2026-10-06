#!/usr/bin/env python3
"""Read-only Android emulator smoke checks for the five Kaysons reviewer roles.

This harness uses adb/uiautomator only. It deliberately does not expose or write
credentials to artifacts. Credentials are read from QA_CREDENTIALS_FILE (a
private Role | Email | Password markdown table) and the default reviewer file
is outside the repository.

Examples:
  python3 scripts/qa/native_role_smoke.py launch
  python3 scripts/qa/native_role_smoke.py snapshot
  python3 scripts/qa/native_role_smoke.py login Accountant
  python3 scripts/qa/native_role_smoke.py smoke --role Accountant
  python3 scripts/qa/native_role_smoke.py all

The smoke pass navigates visible, read-only surfaces. It does not submit bids,
save profile changes, upload files, delete accounts, or open account deletion.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import signal
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable


PACKAGE = "com.kaysons.kaysons_logistics"
DEFAULT_DEVICE = "emulator-5554"
DEFAULT_CREDENTIALS = (
    Path.home() / "Documents/Kaysons-Logistics-Release-Backup"
    / "play-reviewer-credentials.md"
)
DEFAULT_OUTPUT = Path("/tmp/kaysons-qa/native")


@dataclass(frozen=True)
class Node:
    text: str
    desc: str
    resource_id: str
    class_name: str
    bounds: tuple[int, int, int, int]
    password: bool
    clickable: bool

    @property
    def label(self) -> str:
        return self.desc or self.text

    @property
    def center(self) -> tuple[int, int]:
        left, top, right, bottom = self.bounds
        return ((left + right) // 2, (top + bottom) // 2)


def parse_bounds(raw: str) -> tuple[int, int, int, int]:
    values = [int(value) for value in re.findall(r"\d+", raw)]
    if len(values) != 4:
        raise ValueError(f"Invalid uiautomator bounds: {raw!r}")
    return tuple(values)  # type: ignore[return-value]


def parse_nodes(xml: str) -> list[Node]:
    root = ET.fromstring(xml)
    result: list[Node] = []
    for raw in root.iter("node"):
        result.append(
            Node(
                text=raw.attrib.get("text", ""),
                desc=raw.attrib.get("content-desc", ""),
                resource_id=raw.attrib.get("resource-id", ""),
                class_name=raw.attrib.get("class", ""),
                bounds=parse_bounds(raw.attrib.get("bounds", "[0,0][0,0]")),
                password=raw.attrib.get("password", "false") == "true",
                clickable=raw.attrib.get("clickable", "false") == "true",
            )
        )
    return result


def redact(value: str) -> str:
    # Keep semantic labels and role names while hiding account identifiers from
    # text artifacts. Password values never appear in the UI dump, but this
    # also protects against an unexpected framework/debug text leak.
    value = re.sub(r"[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}", "[email redacted]", value)
    value = re.sub(r"Kay-[A-Za-z0-9!_-]+", "[password redacted]", value)
    return value


class Adb:
    def __init__(self, device: str, output: Path) -> None:
        self.device = device
        self.output = output
        configured = os.environ.get("ADB_PATH")
        self.binary = Path(configured) if configured else Path.home() / "Library/Android/sdk/platform-tools/adb"
        if not self.binary.exists():
            self.binary = Path("adb")

    def run(self, *args: str, timeout: float = 30) -> str:
        command = [str(self.binary), "-s", self.device, *args]
        process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            start_new_session=True,
        )
        try:
            stdout, stderr = process.communicate(timeout=timeout)
        except subprocess.TimeoutExpired as exc:
            # adb can leave a remote uiautomator shell child attached to the
            # local pipe after communicate() times out. Kill the process group
            # so a cold/transitioning Flutter tree cannot strand the full role
            # run behind one dump.
            os.killpg(process.pid, signal.SIGKILL)
            stdout, stderr = process.communicate()
            raise RuntimeError(f"adb {' '.join(args)} timed out after {timeout}s") from exc
        if process.returncode:
            details = stderr.strip() or stdout.strip()
            raise RuntimeError(f"adb {' '.join(args)} failed ({process.returncode}): {details}")
        return stdout

    def shell(self, *args: str, timeout: float = 30) -> str:
        return self.run("shell", *args, timeout=timeout)

    def nodes(self) -> list[Node]:
        self.shell("uiautomator", "dump", "/sdcard/kaysons-ui.xml", timeout=15)
        return parse_nodes(self.shell("cat", "/sdcard/kaysons-ui.xml", timeout=15))

    def tap(self, node: Node, wait: float = 0.35) -> None:
        x, y = node.center
        self.shell("input", "tap", str(x), str(y))
        time.sleep(wait)

    def keyevent(self, key: str) -> None:
        self.shell("input", "keyevent", key)

    def input_text(self, value: str) -> None:
        # Android input text uses %s for spaces. Passing the value as a single
        # subprocess argument avoids local shell interpolation of credentials.
        encoded = value.replace("%", "%25").replace(" ", "%s")
        self.shell("input", "text", encoded)

    def snapshot(self) -> list[Node]:
        return self.nodes()

    def dump_snapshot(self, name: str, nodes: Iterable[Node] | None = None) -> Path:
        self.output.mkdir(parents=True, exist_ok=True)
        if nodes is None:
            nodes = self.nodes()
        path = self.output / f"{name}.txt"
        lines = []
        for node in nodes:
            if not node.label or node.password:
                continue
            lines.append(
                f"{redact(node.label)}\t{node.class_name}\t{node.resource_id}\t"
                f"{node.bounds}\tclickable={node.clickable}"
            )
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        return path

    def screenshot(self, name: str) -> Path:
        self.output.mkdir(parents=True, exist_ok=True)
        path = self.output / f"{name}.png"
        command = [str(self.binary), "-s", self.device, "exec-out", "screencap", "-p"]
        last_error = ""
        for attempt in range(2):
            process = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                start_new_session=True,
            )
            try:
                stdout, stderr = process.communicate(timeout=12)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.communicate()
                last_error = "screencap timed out after 12 seconds"
                time.sleep(0.5)
                continue
            if process.returncode:
                last_error = stderr.decode(errors="replace")
                time.sleep(0.5)
                continue
            path.write_bytes(stdout)
            return path
        raise RuntimeError(f"adb screencap failed for {name}: {last_error}")

    def clear_field(self, node: Node) -> None:
        self.tap(node, wait=0.45)
        # CTRL+A works on Flutter's Android text connection. The repeated
        # deletes are a fallback for the emulator's older input method and are
        # harmless when the field is already empty.
        self.keyevent("KEYCODE_CTRL_LEFT")
        self.keyevent("KEYCODE_A")
        self.keyevent("KEYCODE_DEL")
        self.keyevent("KEYCODE_MOVE_END")
        # One shell invocation keeps the fallback fast enough that the IME and
        # Flutter activity do not time out while 96 individual adb processes
        # are started. The selected-text delete above handles normal input;
        # this sequence covers a partially filled field from a prior attempt.
        self.shell("input", "keyevent", *("KEYCODE_DEL",) * 96)
        time.sleep(0.15)


def read_credentials(path: Path) -> dict[str, tuple[str, str]]:
    if not path.exists():
        raise SystemExit(f"Credentials file does not exist: {path}")
    result: dict[str, tuple[str, str]] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.startswith("|"):
            continue
        cells = [cell.strip().strip("`") for cell in line.strip("|").split("|")]
        if len(cells) == 3 and cells[0] not in {"Role", "---"}:
            result[cells[0]] = (cells[1], cells[2])
    return result


def find_label(nodes: Iterable[Node], label: str) -> Node | None:
    exact = [node for node in nodes if node.label == label]
    if exact:
        return exact[0]
    lowered = label.casefold()
    return next((node for node in nodes if lowered in node.label.casefold()), None)


def find_edit_fields(nodes: Iterable[Node]) -> list[Node]:
    return [node for node in nodes if node.class_name == "android.widget.EditText"]


def launch(adb: Adb) -> None:
    adb.shell("am", "force-stop", PACKAGE)
    # `monkey -p ... 1` returns 251 on this API 35 image even though it starts
    # the activity (SYS_KEYS has no physical keys). Use the resolved Flutter
    # activity directly so a non-zero monkey diagnostic cannot abort the run.
    adb.shell("am", "start", "-n", f"{PACKAGE}/.MainActivity")
    # Flutter's accessibility tree is populated after the first rendered
    # frame. A fixed short sleep can return an empty tree on a cold emulator.
    deadline = time.monotonic() + 15
    stable_polls = 0
    while time.monotonic() < deadline:
        try:
            labels = {node.label for node in adb.snapshot() if node.label}
        except (RuntimeError, ET.ParseError):
            labels = set()
        targets = {
            "Login with email / mobile",
            "Sign in",
            "Home",
            "Dashboard",
            "More",
            "Ledger",
            "Freight ledger",
            "Open bids",
            "Fleet",
        }
        if any(target.casefold() in label.casefold() for label in labels for target in targets):
            stable_polls += 1
            if stable_polls >= 2:
                time.sleep(0.5)
                return
        else:
            stable_polls = 0
        time.sleep(0.5)
    raise RuntimeError("Flutter UI did not expose a launch/login label within 15 seconds")


def login(adb: Adb, role: str, credentials: dict[str, tuple[str, str]]) -> None:
    if role not in credentials:
        raise SystemExit(f"No credentials found for role {role!r}")
    email, password = credentials[role]
    launch(adb)
    nodes = adb.snapshot()
    welcome = find_label(nodes, "Login with email / mobile")
    if welcome:
        adb.tap(welcome)
        # The form semantics can lag the visible transition by a frame or two
        # on a cold Flutter engine. Poll for both EditText nodes instead of
        # assuming a fixed 800 ms transition.
        deadline = time.monotonic() + 8
        fields = []
        while time.monotonic() < deadline:
            try:
                nodes = adb.snapshot()
            except (RuntimeError, ET.ParseError):
                nodes = []
            fields = find_edit_fields(nodes)
            if len(fields) >= 2:
                break
            time.sleep(0.35)
    else:
        nodes = adb.snapshot()
        fields = find_edit_fields(nodes)
        if len(fields) < 2:
            # A previous role may still have a persisted session after an
            # install or an interrupted smoke run. Use the visible More menu
            # to sign out, then launch the form again.
            if sign_out(adb):
                launch(adb)
                nodes = adb.snapshot()
                welcome = find_label(nodes, "Login with email / mobile")
                if welcome:
                    adb.tap(welcome)
                deadline = time.monotonic() + 8
                fields = []
                while time.monotonic() < deadline:
                    try:
                        fields = find_edit_fields(adb.snapshot())
                    except (RuntimeError, ET.ParseError):
                        fields = []
                    if len(fields) >= 2:
                        break
                    time.sleep(0.35)
    if len(fields) < 2:
        raise RuntimeError(f"Expected email and password fields; found {len(fields)}")
    # Sort by vertical position because Flutter can return descendants in a
    # different order after keyboard/layout changes.
    fields = sorted(fields, key=lambda node: node.bounds[1])[:2]
    for field, value in zip(fields, (email, password)):
        adb.clear_field(field)
        adb.input_text(value)
        time.sleep(0.5)
        # Email is observable in the UI dump. Retry once if an input method
        # dropped a leading character during the tap-to-type transition.
        if not field.password:
            observed = next(
                (node.text for node in adb.snapshot() if node.class_name == "android.widget.EditText" and not node.password),
                "",
            )
            if observed != email:
                adb.clear_field(field)
                adb.input_text(email)
                time.sleep(0.6)
    # Hide the keyboard once, after both fields are filled. Pressing Back after
    # each field can pop the Flutter route when the IME has already dismissed.
    adb.keyevent("KEYCODE_BACK")
    time.sleep(0.5)
    nodes = adb.snapshot()
    button = find_label(nodes, "Sign in")
    if not button:
        raise RuntimeError("Sign in button not found after filling fields")
    adb.tap(button, wait=0.6)
    time.sleep(5.0)
    after = adb.snapshot()
    if find_label(after, "Sign in") and find_edit_fields(after):
        # A failure snapshot excludes password nodes and redacts identifiers.
        adb.dump_snapshot(f"login-failed-{role.lower().replace(' ', '-')}", after)
        raise RuntimeError(f"Login still shows the sign-in form for {role}")


ROLE_SURFACES: dict[str, list[tuple[str, str]]] = {
    "Administrator": [
        ("dashboard", "Dashboard"),
        ("users", "Users"),
        ("bids", "Bids"),
        ("ledger", "Ledger"),
        ("analytics", "Analytics"),
        ("clawd", "Clawd AI"),
        ("notifications", "Notifications"),
        ("profile", "Profile"),
        ("privacy", "Privacy"),
    ],
    "Accountant": [
        ("ledger", "Ledger"),
        ("analytics", "Analytics"),
        ("clawd", "Clawd AI"),
        ("notifications", "Notifications"),
        ("profile", "Profile"),
        ("privacy", "Privacy"),
    ],
    "Logistics Manager": [
        ("dashboard", "Dashboard"),
        ("bids", "Bids"),
        ("fleet", "Fleet"),
        ("ledger", "Ledger"),
        ("dispatch", "Dispatch Team"),
        ("notifications", "Notifications"),
        ("profile", "Profile"),
        ("privacy", "Privacy"),
    ],
    "Dispatch Manager": [
        ("dashboard", "Dashboard"),
        ("fleet", "Fleet"),
        ("profile", "Profile"),
        ("privacy", "Privacy"),
    ],
    "Transporter": [
        ("home", "Home"),
        ("bids", "Bids"),
        ("fleet", "Fleet"),
        ("vehicles", "Vehicles"),
        ("drivers", "Drivers"),
        ("profile", "Profile"),
        ("privacy", "Privacy"),
    ],
}


def safe_name(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", value.casefold()).strip("-")


def wait_for_label(adb: Adb, label: str, timeout: float = 8) -> Node | None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            node = find_label(adb.snapshot(), label)
        except (RuntimeError, ET.ParseError):
            node = None
        if node:
            return node
        time.sleep(0.35)
    return None


def capture_screen(adb: Adb, role: str, name: str) -> dict[str, object]:
    stem = f"{safe_name(role)}-{safe_name(name)}"
    try:
        nodes = adb.snapshot()
    except RuntimeError as exc:
        return {"name": name, "status": "snapshot-error", "error": redact(str(exc))}
    snapshot = adb.dump_snapshot(stem, nodes)
    try:
        screenshot = adb.screenshot(stem)
    except RuntimeError as exc:
        return {
            "name": name,
            "status": "screenshot-error",
            "snapshot": str(snapshot),
            "error": redact(str(exc)),
            "labels": [redact(node.label) for node in nodes if node.label and not node.password][:80],
        }
    return {
        "name": name,
        "status": "captured",
        "snapshot": str(snapshot),
        "screenshot": str(screenshot),
        "labels": [redact(node.label) for node in nodes if node.label and not node.password][:80],
    }


def nav_button_nodes(nodes: Iterable[Node]) -> list[Node]:
    # The compact shells reserve the final ~300 px for the persistent nav. A
    # bottom-page action can be lower on an account screen, so require a button
    # whose label is a repeated nav title (e.g. "Ledger\nLedger").
    result = []
    for node in nodes:
        if node.class_name != "android.widget.Button" or node.bounds[1] < 2100:
            continue
        if "\n" in node.label:
            result.append(node)
    return result


def first_line(label: str) -> str:
    return label.splitlines()[0].strip() if label else ""


def return_to_more(adb: Adb) -> None:
    nodes = adb.snapshot()
    if find_label(nodes, "More"):
        adb.tap(find_label(nodes, "More"))  # type: ignore[arg-type]
        time.sleep(0.7)
        return
    back = find_label(nodes, "Back")
    if back:
        adb.tap(back)
        time.sleep(0.8)
        if find_label(adb.snapshot(), "More"):
            adb.tap(find_label(adb.snapshot(), "More"))  # type: ignore[arg-type]
            time.sleep(0.7)
        return
    # Profile and a few older shells have no semantic Back button; Android
    # Back pops that route without touching sign-out or account deletion.
    adb.keyevent("KEYCODE_BACK")
    time.sleep(0.8)
    nodes = adb.snapshot()
    more = find_label(nodes, "More")
    if more:
        adb.tap(more)
        time.sleep(0.7)


def role_journey(adb: Adb, role: str, credentials: dict[str, tuple[str, str]]) -> list[dict[str, object]]:
    """Capture each visible bottom-nav and More-menu surface for one role."""
    login(adb, role, credentials)
    results: list[dict[str, object]] = [capture_screen(adb, role, "home")]
    navs = nav_button_nodes(adb.snapshot())
    # De-duplicate titles while preserving on-screen order.
    seen: set[str] = set()
    for nav in navs:
        title = first_line(nav.label)
        if not title or title in seen:
            continue
        seen.add(title)
        current = find_label(adb.snapshot(), title)
        if not current:
            results.append({"name": title, "status": "missing-nav-button"})
            continue
        adb.tap(current)
        expected_nav_label = {"Ledger": "Ledger", "Insights": "Analytics", "Home": "Home"}.get(title)
        if expected_nav_label:
            wait_for_label(adb, expected_nav_label, timeout=6)
        else:
            time.sleep(1.2)
        if title.casefold() == "more":
            results.append(capture_screen(adb, role, "more-menu"))
            menu_items: list[str] = []
            for menu_node in adb.snapshot():
                menu_title = first_line(menu_node.label)
                if menu_node.class_name != "android.widget.Button":
                    continue
                if menu_title in {"Dismiss menu", "Log out", "Logout"} or not menu_title:
                    continue
                if menu_node.bounds[1] < 1500:
                    continue
                if menu_title not in menu_items:
                    menu_items.append(menu_title)
            for item in menu_items:
                target = find_label(adb.snapshot(), item)
                if not target:
                    results.append({"name": item, "status": "missing-menu-item"})
                    continue
                adb.tap(target)
                # Profile fetches the role row after the route transition and
                # can display a spinner for a few seconds. Wait for a
                # role-appropriate semantic label before capturing it; this
                # also prevents a stale Clawd tree from being mislabeled as a
                # profile pass.
                expected = {"Profile": "profile", "Account & privacy": "Back"}.get(item, item)
                wait_for_label(adb, expected, timeout=8)
                results.append(capture_screen(adb, role, safe_name(item)))
                return_to_more(adb)
            # Leave the menu open for sign_out(), which is intentionally the
            # only mutating control exercised in this read-only role journey.
            if not find_label(adb.snapshot(), "Log out"):
                return_to_more(adb)
        else:
            results.append(capture_screen(adb, role, title))
    # Verify the visible logout affordance and capture the unauthenticated
    # landing state. No deletion request or profile save control is touched.
    if sign_out(adb):
        time.sleep(1.2)
        results.append(capture_screen(adb, role, "signed-out"))
    else:
        results.append({"name": "signed-out", "status": "logout-affordance-missing"})
    return results


def sign_out(adb: Adb) -> bool:
    try:
        nodes = adb.snapshot()
    except RuntimeError:
        return False
    for candidate in ("Sign out", "Logout", "Log out"):
        button = find_label(nodes, candidate)
        if button:
            adb.tap(button)
            time.sleep(1.5)
            # Confirm a materialization dialog only when its button is exactly
            # an ordinary confirmation action; never trigger account deletion.
            try:
                confirm = find_label(adb.snapshot(), "Sign out")
            except RuntimeError:
                confirm = None
            if confirm:
                adb.tap(confirm)
                time.sleep(1.5)
            return True
    # All current mobile shells place sign-out under More. Open that menu only
    # when the action is not already exposed; this avoids tapping a generic
    # profile label on a role page.
    more = find_label(nodes, "More")
    if more:
        adb.tap(more)
        time.sleep(0.5)
        try:
            nodes = adb.snapshot()
        except RuntimeError:
            return False
        for candidate in ("Sign out", "Logout", "Log out"):
            button = find_label(nodes, candidate)
            if button:
                adb.tap(button)
                time.sleep(1.5)
                try:
                    confirm = find_label(adb.snapshot(), "Sign out")
                except RuntimeError:
                    confirm = None
                if confirm:
                    adb.tap(confirm)
                    time.sleep(1.5)
                return True
    return False


def smoke_role(adb: Adb, role: str, credentials: dict[str, tuple[str, str]]) -> list[dict[str, object]]:
    login(adb, role, credentials)
    results: list[dict[str, object]] = []
    role_dir = adb.output / safe_name(role)
    role_dir.mkdir(parents=True, exist_ok=True)
    for surface, expected in ROLE_SURFACES[role]:
        # Native navigation is driven through the visible menu labels. This
        # catches both missing menu items and role redirects without mutating
        # any business record.
        nodes = adb.snapshot()
        target = find_label(nodes, expected)
        if not target:
            result = {"role": role, "surface": surface, "status": "missing-menu-label", "expected": expected}
            results.append(result)
            continue
        adb.tap(target)
        time.sleep(1.6)
        current = adb.snapshot()
        snap = adb.dump_snapshot(f"{safe_name(role)}-{surface}", current)
        shot = adb.screenshot(f"{safe_name(role)}-{surface}")
        labels = [redact(node.label) for node in current if node.label and not node.password]
        result = {
            "role": role,
            "surface": surface,
            "status": "captured",
            "expected": expected,
            "snapshot": str(snap),
            "screenshot": str(shot),
            "labels": labels[:40],
        }
        results.append(result)
        # A screen may use a persistent bottom nav; the next target is looked
        # up fresh each time. If a surface lacks a visible menu item, the
        # report records it instead of guessing a coordinate.
    return results


def capture_logcat(adb: Adb, name: str) -> Path:
    adb.output.mkdir(parents=True, exist_ok=True)
    path = adb.output / f"{name}-logcat.txt"
    raw = adb.run("logcat", "-d", "-v", "threadtime", "-t", "1200")
    lines = []
    for line in raw.splitlines():
        if PACKAGE not in line and "flutter" not in line.casefold():
            continue
        if re.search(r"E/|F/|EXCEPTION|FlutterError|SIGSEGV|ANR|used after being disposed|overflowed", line, re.I):
            lines.append(redact(line))
    path.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")
    return path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("launch", "snapshot", "login", "journey", "smoke", "all", "logout", "logcat"))
    parser.add_argument("role", nargs="?", choices=sorted(ROLE_SURFACES))
    parser.add_argument("--role", dest="role_flag", choices=sorted(ROLE_SURFACES))
    parser.add_argument("--device", default=os.environ.get("ANDROID_SERIAL", DEFAULT_DEVICE))
    parser.add_argument("--output", type=Path, default=Path(os.environ.get("QA_OUTPUT_DIR", str(DEFAULT_OUTPUT))))
    parser.add_argument("--credentials", type=Path, default=Path(os.environ.get("QA_CREDENTIALS_FILE", str(DEFAULT_CREDENTIALS))))
    args = parser.parse_args()
    role = args.role_flag or args.role
    adb = Adb(args.device, args.output)
    args.output.mkdir(parents=True, exist_ok=True)

    if args.command == "launch":
        launch(adb)
        path = adb.dump_snapshot("launch")
        shot = adb.screenshot("launch")
        print(json.dumps({"status": "launched", "snapshot": str(path), "screenshot": str(shot)}))
        return 0
    if args.command == "snapshot":
        path = adb.dump_snapshot("snapshot")
        print(path)
        return 0
    if args.command == "logcat":
        print(capture_logcat(adb, "current"))
        return 0
    if args.command == "logout":
        print(json.dumps({"signed_out": sign_out(adb)}))
        return 0
    if args.command in {"login", "journey", "smoke"} and not role:
        parser.error(f"{args.command} requires a role")
    credentials = read_credentials(args.credentials)
    if args.command == "login":
        login(adb, role, credentials)  # type: ignore[arg-type]
        path = adb.dump_snapshot(f"logged-in-{safe_name(role)}")
        shot = adb.screenshot(f"logged-in-{safe_name(role)}")
        print(json.dumps({"role": role, "status": "logged-in", "snapshot": str(path), "screenshot": str(shot)}))
        return 0
    if args.command == "journey":
        results = role_journey(adb, role, credentials)  # type: ignore[arg-type]
        log = capture_logcat(adb, safe_name(role))
        print(json.dumps({"role": role, "results": results, "logcat": str(log)}, indent=2))
        return 0 if all(result.get("status") == "captured" for result in results) else 1
    if args.command == "smoke":
        results = smoke_role(adb, role, credentials)  # type: ignore[arg-type]
        log = capture_logcat(adb, safe_name(role))
        print(json.dumps({"role": role, "results": results, "logcat": str(log)}, indent=2))
        return 0 if all(result["status"] == "captured" for result in results) else 1

    all_results: list[dict[str, object]] = []
    for current_role in ROLE_SURFACES:
        try:
            all_results.extend(role_journey(adb, current_role, credentials))
        except Exception as exc:  # keep the other roles useful after one failure
            all_results.append({"role": current_role, "status": "error", "error": redact(str(exc))})
        finally:
            sign_out(adb)
    log = capture_logcat(adb, "all-roles")
    report = adb.output / "native-smoke-results.json"
    report.write_text(
        json.dumps(
            {
                "generated_at": datetime.now(timezone.utc).isoformat(),
                "device": adb.device,
                "package": PACKAGE,
                "results": all_results,
                "logcat": str(log),
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(json.dumps({"report": str(report), "logcat": str(log), "checks": len(all_results)}))
    return 0 if all(result.get("status") == "captured" for result in all_results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
