#!/usr/bin/env python3
"""Read-only yearly subscription pricing audit for App Store and Google Play."""

from __future__ import annotations

import argparse
import base64
import csv
import json
import os
import sys
import time
from collections import defaultdict
from datetime import date
from decimal import Decimal
from pathlib import Path
from typing import Any

import jwt
import requests


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
ASC_HELPERS = REPOSITORY_ROOT / "store" / "app-store" / "asc"
sys.path.insert(0, str(ASC_HELPERS))

from asc_client import ASCClient  # noqa: E402


APPLE_SUBSCRIPTION_ID = "6758434018"
GOOGLE_PACKAGE_NAME = "com.sponteoai.chillscript"
GOOGLE_PRODUCT_ID = "com.chillnote.pro.yearly"
TARGET_CNY = Decimal("350")
STORE_FEE_RATE = Decimal("0.15")


def decimal_money(value: dict[str, Any]) -> Decimal:
    return Decimal(value.get("units", "0")) + Decimal(value.get("nanos", 0)) / Decimal(1_000_000_000)


def paginate_asc(client: ASCClient, path: str, params: dict[str, Any]) -> list[dict[str, Any]]:
    data: list[dict[str, Any]] = []
    cursor: str | None = None
    while True:
        page_params = dict(params)
        if cursor:
            page_params["cursor"] = cursor
        payload = client.get_json(path, page_params)
        data.append(payload)
        cursor = payload.get("meta", {}).get("paging", {}).get("nextCursor")
        if not cursor:
            return data


def decode_apple_region(subscription_price_id: str) -> str:
    padded = subscription_price_id + "=" * (-len(subscription_price_id) % 4)
    payload = json.loads(base64.urlsafe_b64decode(padded))
    return payload["c"]


def load_country_names() -> dict[str, str]:
    names: dict[str, str] = {}
    path = Path("/usr/share/zoneinfo/iso3166.tab")
    if not path.exists():
        return names
    for line in path.read_text(encoding="utf-8").splitlines():
        if line and not line.startswith("#"):
            code, name = line.split("\t", 1)
            names[code] = name
    return names


def load_inforeuro_rates(year: int, month: int) -> tuple[dict[str, Decimal], str]:
    response = requests.get(
        "https://ec.europa.eu/budg/inforeuro/api/public/monthly-rates",
        params={"year": year, "month": month, "lang": "en"},
        timeout=30,
    )
    response.raise_for_status()
    entries = response.json()
    rates = {entry["isoA3Code"]: Decimal(str(entry["value"])) for entry in entries}
    rates["EUR"] = Decimal("1")
    return rates, f"European Commission InforEuro {year:04d}-{month:02d}"


def to_cny(amount: Decimal, currency: str, rates: dict[str, Decimal]) -> Decimal | None:
    currency_rate = rates.get(currency)
    cny_rate = rates.get("CNY")
    if not currency_rate or not cny_rate:
        return None
    return amount / currency_rate * cny_rate


def current_apple_prices(client: ASCClient) -> list[dict[str, Any]]:
    pages = paginate_asc(
        client,
        f"/subscriptions/{APPLE_SUBSCRIPTION_ID}/prices",
        {"limit": 200, "include": "subscriptionPricePoint,territory"},
    )
    candidates: dict[str, list[dict[str, Any]]] = defaultdict(list)
    today = date.today().isoformat()

    for page in pages:
        included = {item["id"]: item for item in page.get("included", [])}
        for item in page["data"]:
            attrs = item["attributes"]
            start_date = attrs.get("startDate")
            if start_date and start_date > today:
                continue
            point_id = item["relationships"]["subscriptionPricePoint"]["data"]["id"]
            point = included[point_id]
            territory_id = item["relationships"]["territory"]["data"]["id"]
            territory = included[territory_id]
            candidates[decode_apple_region(item["id"])].append(
                {
                    "start_date": start_date or "0000-00-00",
                    "preserved": attrs.get("preserved", False),
                    "currency": territory["attributes"]["currency"],
                    "customer_price": Decimal(point["attributes"]["customerPrice"]),
                    "net_native": Decimal(point["attributes"]["proceeds"]),
                }
            )

    current: list[dict[str, Any]] = []
    for region_code, entries in candidates.items():
        non_preserved = [entry for entry in entries if not entry["preserved"]]
        pool = non_preserved or entries
        selected = max(pool, key=lambda entry: entry["start_date"])
        selected["region_code"] = region_code
        current.append(selected)
    return sorted(current, key=lambda row: row["region_code"])


def google_access_token(credentials_path: Path) -> str:
    credentials = json.loads(credentials_path.read_text(encoding="utf-8"))
    now = int(time.time())
    token_uri = credentials.get("token_uri", "https://oauth2.googleapis.com/token")
    assertion = jwt.encode(
        {
            "iss": credentials["client_email"],
            "scope": "https://www.googleapis.com/auth/androidpublisher",
            "aud": token_uri,
            "iat": now,
            "exp": now + 3600,
        },
        credentials["private_key"],
        algorithm="RS256",
    )
    response = requests.post(
        token_uri,
        data={"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": assertion},
        timeout=30,
    )
    response.raise_for_status()
    return response.json()["access_token"]


def current_google_prices(credentials_path: Path) -> list[dict[str, Any]]:
    token = google_access_token(credentials_path)
    url = (
        "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/"
        f"{GOOGLE_PACKAGE_NAME}/subscriptions/{GOOGLE_PRODUCT_ID}"
    )
    response = requests.get(url, headers={"Authorization": f"Bearer {token}"}, timeout=30)
    response.raise_for_status()
    payload = response.json()
    base_plan = next(plan for plan in payload["basePlans"] if plan["basePlanId"] == "yearly")
    return [
        {
            "region_code": config["regionCode"],
            "currency": config["price"]["currencyCode"],
            "customer_price": decimal_money(config["price"]),
        }
        for config in base_plan["regionalConfigs"]
        if config.get("newSubscriberAvailability", False)
    ]


def build_rows(
    apple_prices: list[dict[str, Any]],
    google_prices: list[dict[str, Any]],
    rates: dict[str, Decimal],
    country_names: dict[str, str],
) -> list[dict[str, Any]]:
    output: list[dict[str, Any]] = []
    apple_ratio: dict[str, Decimal] = {}

    for row in apple_prices:
        price = row["customer_price"]
        net = row["net_native"]
        ratio = net / price
        apple_ratio[row["region_code"]] = ratio
        store_fee_rate = Decimal("0.12") if row["region_code"] == "CN" else STORE_FEE_RATE
        pre_fee = net / (Decimal("1") - store_fee_rate)
        tax_rate = max(Decimal("0"), price / pre_fee - Decimal("1"))
        net_cny = to_cny(net, row["currency"], rates)
        output.append(
            make_output_row(
                platform="Apple",
                source="App Store Connect proceeds（官方精确值）",
                region_code=row["region_code"],
                region_name=country_names.get(row["region_code"], row["region_code"]),
                currency=row["currency"],
                customer_price=price,
                tax_rate=tax_rate,
                store_fee_rate=store_fee_rate,
                net_native=net,
                net_cny=net_cny,
            )
        )

    for row in google_prices:
        ratio = apple_ratio.get(row["region_code"], Decimal("1") - STORE_FEE_RATE)
        price = row["customer_price"]
        net = price * ratio
        pre_fee = net / (Decimal("1") - STORE_FEE_RATE)
        tax_rate = max(Decimal("0"), price / pre_fee - Decimal("1"))
        net_cny = to_cny(net, row["currency"], rates)
        source = "按同地区 Apple 有效税率 + Google 15% 订阅费估算"
        if row["region_code"] not in apple_ratio:
            source = "无同地区 Apple 税率；仅按 Google 15% 订阅费估算"
        output.append(
            make_output_row(
                platform="Google",
                source=source,
                region_code=row["region_code"],
                region_name=country_names.get(row["region_code"], row["region_code"]),
                currency=row["currency"],
                customer_price=price,
                tax_rate=tax_rate,
                store_fee_rate=STORE_FEE_RATE,
                net_native=net,
                net_cny=net_cny,
            )
        )

    return sorted(output, key=lambda row: (row["platform"], row["region_code"]))


def make_output_row(
    *,
    platform: str,
    source: str,
    region_code: str,
    region_name: str,
    currency: str,
    customer_price: Decimal,
    tax_rate: Decimal,
    store_fee_rate: Decimal,
    net_native: Decimal,
    net_cny: Decimal | None,
) -> dict[str, Any]:
    if net_cny and net_cny > 0:
        target_price = customer_price * TARGET_CNY / net_cny
        delta = net_cny - TARGET_CNY
        status = "目标±5%"
        if net_cny < TARGET_CNY * Decimal("0.95"):
            status = "偏低"
        elif net_cny > TARGET_CNY * Decimal("1.05"):
            status = "偏高"
    else:
        target_price = None
        delta = None
        status = "缺少汇率"
    return {
        "platform": platform,
        "price_scope": "当前新订阅用户",
        "region_code": region_code,
        "region_name": region_name,
        "currency": currency,
        "customer_price": customer_price,
        "estimated_transaction_tax_rate_pct": tax_rate * Decimal("100"),
        "store_fee_rate_pct": store_fee_rate * Decimal("100"),
        "net_native": net_native,
        "net_cny": net_cny,
        "delta_to_target_cny": delta,
        "target_customer_price_native_raw": target_price,
        "status": status,
        "net_basis": source,
    }


def write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = list(rows[0])
    with path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(
                {
                    key: (f"{value:.4f}" if isinstance(value, Decimal) else value)
                    for key, value in row.items()
                }
            )


def print_summary(rows: list[dict[str, Any]], rate_source: str, output: Path) -> None:
    print(f"rate_source={rate_source}")
    print(f"csv={output}")
    for platform in ("Apple", "Google"):
        values = sorted(
            row["net_cny"] for row in rows if row["platform"] == platform and row["net_cny"] is not None
        )
        counts = defaultdict(int)
        for row in rows:
            if row["platform"] == platform:
                counts[row["status"]] += 1
        median = values[len(values) // 2]
        print(
            f"{platform}: regions={len(values)}, median_net_cny={median:.2f}, "
            f"min={values[0]:.2f}, max={values[-1]:.2f}, status={dict(counts)}"
        )

    focus = {"US", "CN", "HK", "TW", "JP", "KR", "GB", "DE", "FR", "AU", "CA", "IN", "BR", "MX", "SG"}
    for row in rows:
        if row["region_code"] in focus:
            print(
                f"{row['platform']} {row['region_code']} {row['currency']} "
                f"price={row['customer_price']} net_native={row['net_native']:.2f} "
                f"net_cny={(f'{row['net_cny']:.2f}' if row['net_cny'] is not None else 'NA')} "
                f"target_price={(f'{row['target_customer_price_native_raw']:.2f}' if row['target_customer_price_native_raw'] is not None else 'NA')}"
            )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--year", type=int, default=date.today().year)
    parser.add_argument("--month", type=int, default=date.today().month)
    parser.add_argument(
        "--output",
        type=Path,
        default=REPOSITORY_ROOT / "store" / "pricing" / "reports" / f"yearly-pricing-{date.today().isoformat()}.csv",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    google_credentials = os.environ.get("GOOGLE_PLAY_JSON_KEY_PATH")
    if not google_credentials:
        raise SystemExit("GOOGLE_PLAY_JSON_KEY_PATH is required")

    rates, rate_source = load_inforeuro_rates(args.year, args.month)
    apple = current_apple_prices(ASCClient())
    google = current_google_prices(Path(google_credentials).expanduser())
    rows = build_rows(apple, google, rates, load_country_names())
    write_csv(args.output, rows)
    print_summary(rows, rate_source, args.output)


if __name__ == "__main__":
    main()
