#!/usr/bin/env bash
# BCOS v2 GitHub Action — Main Runner Script
# Compatible with composite action directory structure
set -euo pipefail

# ── Env defaults ─────────────────────────────────────────────────
REPO_PATH="${REPO_PATH:-$GITHUB_WORKSPACE}"
BCOS_REPORT="/tmp/bcos_report.json"
BCOS_ENGINE="/tmp/bcos_engine.py"
BCOS_ACTION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "trust_score=0" >> $GITHUB_OUTPUT
echo "cert_id=none" >> $GITHUB_OUTPUT
echo "tier_met=false" >> $GITHUB_OUTPUT
echo "score_breakdown=" >> $GITHUB_OUTPUT

# ── Fetch BCOS Engine ─────────────────────────────────────────────
echo "📦 Fetching BCOS Engine from Scottcjn/Rustchain..."
if [ ! -f "$BCOS_ENGINE" ]; then
  curl -sL "https://raw.githubusercontent.com/Scottcjn/Rustchain/main/tools/bcos_engine.py" \
    -o "$BCOS_ENGINE" \
    || echo "⚠️ Failed to download bcos_engine.py"
fi

# ── Install tools (best-effort — engine has fallbacks) ───────────
echo "🔧 Installing tools..."
pip install --quiet semgrep pip-audit pip-licenses cyclonedx-py osv-scanner 2>/dev/null || true

# ── Run BCOS scan ───────────────────────────────────────────────
echo "🔍 Running BCOS v2 scan (tier=$TIER, repo=$REPO_PATH)..."
cd "$REPO_PATH"

if [ -f "$BCOS_ENGINE" ]; then
  python3 "$BCOS_ENGINE" . \
    --tier "$TIER" \
    --reviewer "$REVIEWER" \
    --json \
    > "$BCOS_REPORT" 2>&1 \
    || true
fi

# Validate JSON output
if [ ! -s "$BCOS_REPORT" ] || ! python3 -c "import json; json.load(open('$BCOS_REPORT'))" 2>/dev/null; then
  echo "⚠️ BCOS engine produced no valid output — using fallback"
  python3 "$BCOS_ACTION_DIR/run_bcos.py" > "$BCOS_REPORT"
fi

# ── Extract outputs ─────────────────────────────────────────────
TRUST_SCORE=$(python3 -c "import json; print(json.load(open('$BCOS_REPORT')).get('trust_score', 0))")
CERT_ID=$(python3 -c "import json; print(json.load(open('$BCOS_REPORT')).get('cert_id', 'none'))")
TIER_MET=$(python3 -c "import json; print(str(json.load(open('$BCOS_REPORT')).get('tier_met', False)).lower())")

# URL-encode score_breakdown for GITHUB_OUTPUT
SB=$(python3 -c "import json, urllib.parse; print(urllib.parse.quote(json.dumps(json.load(open('$BCOS_REPORT')).get('score_breakdown', {}))))")

echo "trust_score=$TRUST_SCORE" >> $GITHUB_OUTPUT
echo "cert_id=$CERT_ID" >> $GITHUB_OUTPUT
echo "tier_met=$TIER_MET" >> $GITHUB_OUTPUT
echo "score_breakdown=$SB" >> $GITHUB_OUTPUT

# Extract individual component scores
LIC_SCORE=$(python3 -c "import json; print(json.load(open('$BCOS_REPORT')).get('score_breakdown', {}).get('license_compliance', 0))")
VULN_SCORE=$(python3 -c "import json; print(json.load(open('$BCOS_REPORT')).get('score_breakdown', {}).get('vulnerability_scan', 0))")
STATIC_SCORE=$(python3 -c "import json; print(json.load(open('$BCOS_REPORT')).get('score_breakdown', {}).get('static_analysis', 0))")
SBOM_SCORE=$(python3 -c "import json; print(json.load(open('$BCOS_REPORT')).get('score_breakdown', {}).get('sbom_completeness', 0))")
DEPS_SCORE=$(python3 -c "import json; print(json.load(open('$BCOS_REPORT')).get('score_breakdown', {}).get('dependency_freshness', 0))")
TEST_SCORE=$(python3 -c "import json; print(json.load(open('$BCOS_REPORT')).get('score_breakdown', {}).get('test_evidence', 0))")
REVIEW_SCORE=$(python3 -c "import json; print(json.load(open('$BCOS_REPORT')).get('score_breakdown', {}).get('review_attestation', 0))")

echo ""
echo "========================================"
echo "  BCOS v2 Result: Score=$TRUST_SCORE, Cert=$CERT_ID, Met=$TIER_MET"
echo "  Lic:$LIC_SCORE Vuln:$VULN_SCORE Static:$STATIC_SCORE SBOM:$SBOM_SCORE"
echo "  Deps:$DEPS_SCORE Tests:$TEST_SCORE Review:$REVIEW_SCORE"
echo "========================================"

# ── Post PR comment ─────────────────────────────────────────────
if [ -n "$GITHUB_PR_NUMBER" ] && [ "$GITHUB_PR_NUMBER" != "None" ] && [ "$GITHUB_PR_NUMBER" != "" ]; then
  echo "💬 Posting PR comment..."

  if [ "$TIER_MET" = "true" ]; then
    BADGE="![BCOS](https://img.shields.io/badge/BCOS-$CERT_ID-green?style=flat-square)"
    EMOJI="✅"
    STATUS_TEXT="PASSED"
  else
    BADGE="![BCOS](https://img.shields.io/badge/BCOS-$CERT_ID-yellow?style=flat-square)"
    EMOJI="⚠️"
    STATUS_TEXT="FAILED"
  fi

  # Escape values for JSON
  ESC_Badge=$(python3 -c "import json; print(json.dumps('$BADGE'))")
  ESC_Repo=$(python3 -c "import json; print(json.dumps('$GITHUB_REPOSITORY'))")
  ESC_PR=$(python3 -c "import json; print(json.dumps('$GITHUB_PR_NUMBER'))")

  COMMENT_BODY="## 🤖 BCOS v2 — Beacon Certified Open Source

${BADGE}

**Trust Score:** \`$TRUST_SCORE / 100\`
**Tier:** \`$TIER\`
**Result:** $EMOJI \`$STATUS_TEXT\`
**Cert ID:** \`$CERT_ID\`

### Score Breakdown

| Component | Score | Max |
|-----------|-------|-----|
| License Compliance | \`$LIC_SCORE\` | 20 |
| Vulnerability Scan | \`$VULN_SCORE\` | 25 |
| Static Analysis | \`$STATIC_SCORE\` | 20 |
| SBOM Completeness | \`$SBOM_SCORE\` | 10 |
| Dependency Freshness | \`$DEPS_SCORE\` | 5 |
| Test Evidence | \`$TEST_SCORE\` | 10 |
| Review Attestation | \`$REVIEW_SCORE\` | 10 |

**Full Report:** \`$BCOS_REPORT\`
**Verify:** https://rustchain.org/bcos/verify/$CERT_ID

---
*🤖 BCOS v2 GitHub Action — Powered by RustChain — MIT Licensed*"

  COMMENT_JSON=$(python3 -c "import json; print(json.dumps({'body': '''$COMMENT_BODY'''}))" 2>/dev/null)

  HTTP_CODE=$(curl -s -X POST \
    -H "Authorization: token $GH_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Content-Type: application/json" \
    "https://api.github.com/repos/$GITHUB_REPOSITORY/pulls/$GITHUB_PR_NUMBER/comments" \
    -d "$COMMENT_JSON" \
    -w "%{http_code}" \
    -o /tmp/bcos_comment_resp.json)

  if [ "$HTTP_CODE" = "201" ]; then
    echo "✅ PR comment posted"
  else
    echo "⚠️ PR comment HTTP $HTTP_CODE"
    python3 -c "import json; print(json.load(open('/tmp/bcos_comment_resp.json')).get('message','error'))" 2>/dev/null || true
  fi
fi

# ── Anchor attestation on push ───────────────────────────────────
if [ "$GITHUB_EVENT_NAME" = "push" ] && [[ "\$GITHUB_REF" == refs/heads/* ]]; then
  echo "🔗 Anchoring attestation to RustChain..."
  ANCHOR_RESP=$(curl -s -X POST \
    --max-time 10 \
    "${NODE_URL}/api/attest" \
    -H "Content-Type: application/json" \
    -d @"$BCOS_REPORT" \
    -w "\nHTTP:%{http_code}" 2>&1)
  ANCHOR_CODE=$(echo "$ANCHOR_RESP" | grep "HTTP:" | cut -d: -f2)
  if [ "$ANCHOR_CODE" = "200" ] || [ "$ANCHOR_CODE" = "201" ] || [ "$ANCHOR_CODE" = "202" ]; then
    echo "✅ Attestation anchored (HTTP $ANCHOR_CODE)"
  else
    echo "⚠️ Anchor returned HTTP $ANCHOR_CODE (node may be offline — non-critical)"
  fi
fi

echo "✅ BCOS GitHub Action complete"
