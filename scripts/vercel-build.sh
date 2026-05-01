#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.29.0}"
FLUTTER_HOME="$PWD/.vercel/flutter"

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_ANON_KEY:-}" ]; then
  echo "Missing SUPABASE_URL or SUPABASE_ANON_KEY in Vercel environment variables."
  exit 1
fi

if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  mkdir -p "$PWD/.vercel"
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_HOME"
fi

git config --global --add safe.directory "$FLUTTER_HOME"
git -C "$FLUTTER_HOME" fetch --depth 1 origin master:refs/remotes/origin/master

export PATH="$FLUTTER_HOME/bin:$PATH"

flutter config --enable-web --no-analytics
flutter --version
flutter pub get

printf "SUPABASE_URL=%s\nSUPABASE_ANON_KEY=%s\n" "$SUPABASE_URL" "$SUPABASE_ANON_KEY" > .env

flutter build web --release
