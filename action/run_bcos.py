#!/usr/bin/env python3
"""Fallback BCOS report generator when bcos_engine.py is unavailable."""
import json
from datetime import datetime, timezone

REPO_NAME = __import__('os').getenv('GITHUB_REPOSITORY', 'unknown')
COMMIT_SHA = __import__('os').getenv('GITHUB_SHA', 'unknown')
TIER = __import__('os').getenv('TIER', 'L1')

report = {
    "schema": "bcos-attestation/v2",
    "repo_name": REPO_NAME,
    "commit_sha": COMMIT_SHA,
    "tier": TIER,
    "trust_score": 0,
    "tier_met": False,
    "score_breakdown": {
        "license_compliance": 0,
        "vulnerability_scan": 0,
        "static_analysis": 0,
        "sbom_completeness": 0,
        "dependency_freshness": 0,
        "test_evidence": 0,
        "review_attestation": 0,
    },
    "error": "bcos_engine.py unavailable",
    "timestamp": datetime.now(timezone.utc).isoformat(),
}
print(json.dumps(report, indent=2))
