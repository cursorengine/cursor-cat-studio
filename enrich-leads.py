#!/usr/bin/env python3
"""
Cursor Cat Digital — Lead Enrichment Script
Replaces Clay ($263/mo CAD) for solo-operator use.

USAGE:
  1. Export your leads from Apollo as a CSV (or build your own from Google Maps)
  2. Run: python3 enrich-leads.py your_leads.csv
  3. Get back: enriched_leads.csv — ready to drop into Instantly or Notion CRM

WHAT IT DOES:
  - Checks if they have a working website
  - Detects website platform (WordPress, Squarespace, Wix, custom, etc.)
  - Checks if site is mobile-friendly (basic header check)
  - Pulls page title (often reveals their main keyword targeting)
  - Checks if they mention any competitors in meta tags
  - Scores each lead 1–10 (higher = more likely to need your help)
  - Outputs enriched CSV with priority column for sorting

REQUIREMENTS:
  pip install requests beautifulsoup4 --break-system-packages
"""

import csv
import sys
import time
import requests
from bs4 import BeautifulSoup
from urllib.parse import urlparse
import re

# ─── CONFIG ────────────────────────────────────────────────────────────────────

REQUEST_TIMEOUT = 8          # seconds per request
DELAY_BETWEEN_REQUESTS = 1   # seconds — be polite, don't get rate-limited
USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

# Lead score weights (adjust as needed)
SCORE_NO_WEBSITE = 4          # No website = high need
SCORE_SLOW_SITE = 2           # Site exists but likely underperforming
SCORE_NO_VIEWPORT = 2         # Not mobile-friendly
SCORE_MISSING_PHONE = 1       # No phone number visible in meta/title
SCORE_GENERIC_TITLE = 2       # Title is just the business name, not keyword-rich
SCORE_WORDPRESS = -1          # WP sites are easier to fix, slightly less urgent

# ─── HELPERS ───────────────────────────────────────────────────────────────────

def normalize_url(url):
    """Add https:// if missing."""
    if not url:
        return None
    url = url.strip()
    if not url.startswith("http"):
        url = "https://" + url
    return url


def check_website(url):
    """
    Fetch the website and extract useful signals.
    Returns a dict of findings.
    """
    result = {
        "website_live": False,
        "page_title": "",
        "platform": "Unknown",
        "mobile_friendly": False,
        "has_phone_in_meta": False,
        "title_keyword_rich": False,
        "status_code": None,
        "error": "",
    }

    if not url:
        result["error"] = "No URL provided"
        return result

    try:
        headers = {"User-Agent": USER_AGENT}
        response = requests.get(url, headers=headers, timeout=REQUEST_TIMEOUT, allow_redirects=True)
        result["status_code"] = response.status_code

        if response.status_code != 200:
            result["error"] = f"HTTP {response.status_code}"
            return result

        result["website_live"] = True
        html = response.text
        soup = BeautifulSoup(html, "html.parser")

        # Page title
        title_tag = soup.find("title")
        if title_tag:
            result["page_title"] = title_tag.get_text(strip=True)[:120]
            # Title is keyword-rich if it's more than just the business name
            # (rough heuristic: more than 3 words and contains a service/location word)
            title_words = result["page_title"].split()
            location_words = ["alberta", "calgary", "edmonton", "red deer", "airdrie",
                              "lethbridge", "plumbing", "hvac", "electrical", "roofing",
                              "landscaping", "contractor", "construction", "cleaning",
                              "repair", "installation", "services", "company"]
            title_lower = result["page_title"].lower()
            if len(title_words) > 3 and any(w in title_lower for w in location_words):
                result["title_keyword_rich"] = True

        # Mobile viewport
        viewport = soup.find("meta", {"name": re.compile("viewport", re.I)})
        if viewport:
            result["mobile_friendly"] = True

        # Phone number in meta or visible text
        phone_pattern = r'(\+?1[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}'
        meta_desc = soup.find("meta", {"name": re.compile("description", re.I)})
        meta_text = meta_desc.get("content", "") if meta_desc else ""
        body_text = soup.get_text()[:2000]  # check first 2000 chars only
        if re.search(phone_pattern, meta_text + body_text):
            result["has_phone_in_meta"] = True

        # Detect platform
        html_lower = html.lower()
        if "wp-content" in html_lower or "wordpress" in html_lower:
            result["platform"] = "WordPress"
        elif "squarespace" in html_lower:
            result["platform"] = "Squarespace"
        elif "wix.com" in html_lower or "wixsite" in html_lower:
            result["platform"] = "Wix"
        elif "weebly" in html_lower:
            result["platform"] = "Weebly"
        elif "shopify" in html_lower:
            result["platform"] = "Shopify"
        elif "webflow" in html_lower:
            result["platform"] = "Webflow"
        elif "godaddy" in html_lower:
            result["platform"] = "GoDaddy"
        elif "builderall" in html_lower:
            result["platform"] = "BuilderAll"
        else:
            result["platform"] = "Custom/Unknown"

    except requests.exceptions.ConnectionError:
        result["error"] = "Site unreachable"
    except requests.exceptions.Timeout:
        result["error"] = "Timed out"
    except Exception as e:
        result["error"] = str(e)[:60]

    return result


def score_lead(row, web_data):
    """
    Score a lead from 1–10 based on digital presence gaps.
    Higher score = more likely to need Cursor Cat's help.
    """
    score = 0
    reasons = []

    if not web_data["website_live"]:
        score += SCORE_NO_WEBSITE
        reasons.append("No working website")
    else:
        score += SCORE_SLOW_SITE  # Has a site, but may still be weak
        reasons.append("Has website (may be underperforming)")

        if not web_data["mobile_friendly"]:
            score += SCORE_NO_VIEWPORT
            reasons.append("Not mobile-friendly")

        if not web_data["title_keyword_rich"]:
            score += SCORE_GENERIC_TITLE
            reasons.append("Weak page title (not keyword-rich)")

        if web_data["platform"] == "WordPress":
            score += SCORE_WORDPRESS

        if not web_data["has_phone_in_meta"]:
            score += SCORE_MISSING_PHONE
            reasons.append("Phone not prominent")

    # GBP review count (if provided in input CSV)
    review_count = row.get("gbp_reviews", "").strip()
    if review_count.isdigit():
        count = int(review_count)
        if count < 5:
            score += 2
            reasons.append(f"Only {count} GBP reviews")
        elif count < 15:
            score += 1
            reasons.append(f"{count} GBP reviews (room to grow)")

    # Cap score at 10
    score = min(score, 10)

    # Priority label
    if score >= 7:
        priority = "🔴 HIGH"
    elif score >= 4:
        priority = "🟡 MEDIUM"
    else:
        priority = "🟢 LOW"

    return score, priority, " | ".join(reasons)


def get_outreach_angle(web_data, score):
    """Suggest a personalized outreach angle based on what was found."""
    if not web_data["website_live"]:
        return "Lead with: no website = invisible to Google. Offer Local Lead Engine."
    if not web_data["mobile_friendly"]:
        return "Lead with: their site fails on mobile — 70% of local searches are mobile."
    if not web_data["title_keyword_rich"]:
        return "Lead with: their site title doesn't target any local keywords."
    if score >= 6:
        return "Lead with: their GBP is thin and they're not in the map pack."
    return "Lead with: general digital presence gaps vs. competitors."


# ─── MAIN ──────────────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        print("\nUsage: python3 enrich-leads.py your_leads.csv\n")
        print("Your CSV should have columns like:")
        print("  first_name, last_name, company, email, phone, city, website, gbp_reviews\n")
        print("(All columns are optional except at least one identifier)\n")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = input_file.replace(".csv", "_enriched.csv")

    print(f"\n{'='*55}")
    print("  Cursor Cat Digital — Lead Enrichment Script")
    print(f"{'='*55}")
    print(f"  Input:  {input_file}")
    print(f"  Output: {output_file}")
    print(f"{'='*55}\n")

    try:
        with open(input_file, newline="", encoding="utf-8-sig") as f:
            reader = csv.DictReader(f)
            rows = list(reader)
            original_fields = reader.fieldnames or []
    except FileNotFoundError:
        print(f"Error: Could not find '{input_file}'")
        sys.exit(1)

    # New columns we're adding
    new_fields = [
        "website_live",
        "page_title",
        "platform",
        "mobile_friendly",
        "lead_score",
        "priority",
        "gap_reasons",
        "outreach_angle",
        "enrichment_error",
    ]

    all_fields = original_fields + [f for f in new_fields if f not in original_fields]
    enriched_rows = []
    total = len(rows)

    for i, row in enumerate(rows, 1):
        # Get website URL from common column names
        url = (
            row.get("website") or
            row.get("Website") or
            row.get("website_url") or
            row.get("company_website") or
            ""
        ).strip()

        url = normalize_url(url)
        company = row.get("company") or row.get("Company") or row.get("business_name") or "Unknown"

        print(f"[{i}/{total}] {company} — {url or 'No URL'}")

        # Fetch website data
        web_data = check_website(url)

        # Score the lead
        score, priority, reasons = score_lead(row, web_data)

        # Get outreach suggestion
        angle = get_outreach_angle(web_data, score)

        # Merge everything
        row.update({
            "website_live": "Yes" if web_data["website_live"] else "No",
            "page_title": web_data["page_title"],
            "platform": web_data["platform"],
            "mobile_friendly": "Yes" if web_data["mobile_friendly"] else "No",
            "lead_score": score,
            "priority": priority,
            "gap_reasons": reasons,
            "outreach_angle": angle,
            "enrichment_error": web_data["error"],
        })

        enriched_rows.append(row)

        # Be polite to servers
        if url:
            time.sleep(DELAY_BETWEEN_REQUESTS)

    # Write output
    with open(output_file, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=all_fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(enriched_rows)

    # Summary
    high = sum(1 for r in enriched_rows if "HIGH" in str(r.get("priority", "")))
    med  = sum(1 for r in enriched_rows if "MEDIUM" in str(r.get("priority", "")))
    low  = sum(1 for r in enriched_rows if "LOW" in str(r.get("priority", "")))
    no_site = sum(1 for r in enriched_rows if r.get("website_live") == "No")

    print(f"\n{'='*55}")
    print("  Done!")
    print(f"{'='*55}")
    print(f"  Total leads processed : {total}")
    print(f"  🔴 High priority       : {high}")
    print(f"  🟡 Medium priority     : {med}")
    print(f"  🟢 Low priority        : {low}")
    print(f"  No website found       : {no_site}")
    print(f"\n  Output saved to: {output_file}")
    print(f"\n  TIP: Sort by 'lead_score' descending to work your")
    print(f"  hottest prospects first.")
    print(f"{'='*55}\n")


if __name__ == "__main__":
    main()
