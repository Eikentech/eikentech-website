#!/usr/bin/env bash
# Tell IndexNow search engines (Bing, Yandex, Seznam, Naver, Yep and others)
# that pages on eikentech.no have changed. Run after a change is live on the site.
#
#   bash _scripts/indexnow.sh                  # every URL in sitemap.xml, plus llms.txt
#   bash _scripts/indexnow.sh https://eikentech.no/privacy.html   # only the URLs given
#
# Google does not use IndexNow: use URL Inspection > Request indexing in Search Console.
# This folder starts with "_" so GitHub Pages does not publish it.

set -euo pipefail

HOST="eikentech.no"
KEY="2b7c0681521df0b7cf5f0491a257dbf5"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Make sure the key file is live, or the engines will reject the request.
LIVE_KEY="$(curl -fsS "https://$HOST/$KEY.txt" | tr -d '[:space:]')" || LIVE_KEY=""
if [ "$LIVE_KEY" != "$KEY" ]; then
  echo "Key file https://$HOST/$KEY.txt is not live or does not match. Deploy it first." >&2
  exit 1
fi

if [ "$#" -gt 0 ]; then
  URLS=("$@")
else
  mapfile -t URLS < <(grep -o '<loc>[^<]*</loc>' "$ROOT/sitemap.xml" | sed 's/<\/\?loc>//g')
  URLS+=("https://$HOST/sitemap.xml" "https://$HOST/llms.txt")
fi

URL_JSON="$(printf '"%s",' "${URLS[@]}")"
BODY="{\"host\":\"$HOST\",\"key\":\"$KEY\",\"keyLocation\":\"https://$HOST/$KEY.txt\",\"urlList\":[${URL_JSON%,}]}"

echo "Submitting ${#URLS[@]} URL(s):"
printf '  %s\n' "${URLS[@]}"

FAILED=0
for ENGINE in api.indexnow.org www.bing.com yandex.com search.seznam.cz searchadvisor.naver.com indexnow.yep.com; do
  CODE="$(curl -s -o /dev/null -w '%{http_code}' -X POST "https://$ENGINE/indexnow" \
    -H 'Content-Type: application/json; charset=utf-8' -d "$BODY")" || CODE="000"
  case "$CODE" in
    200|202) echo "  $ENGINE: $CODE ok" ;;
    *)       echo "  $ENGINE: $CODE FAILED"; FAILED=1 ;;
  esac
done

exit "$FAILED"
