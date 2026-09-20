#!/usr/bin/env python3
"""Safely inspect or apply the two approved yearly subscription price changes."""

from __future__ import annotations

import argparse
import copy
import json
import os
import sys
import time
from datetime import date, timedelta
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
APPLE_TERRITORY = "COL"
APPLE_TARGET_PRICE = Decimal("229900")
APPLE_KEY_ID = "DDLSNSM264"
APPLE_ISSUER_ID = "457129c5-26ac-400b-b9bc-dca88b17bd5d"
APPLE_PRIVATE_KEY = REPOSITORY_ROOT / "store" / "app-store" / "fastlane" / "AuthKey_DDLSNSM264.p8"

GOOGLE_PACKAGE_NAME = "com.sponteoai.chillscript"
GOOGLE_PRODUCT_ID = "com.chillnote.pro.yearly"
GOOGLE_BASE_PLAN_ID = "yearly"
GOOGLE_REGION = "BR"
GOOGLE_TARGET_PRICE = Decimal("349.99")
GOOGLE_API_ROOT = "https://androidpublisher.googleapis.com/androidpublisher/v3"

CONFIRMATION = "APPLE-COL-229900-GOOGLE-BR-349.99"


def load_simple_env(path: Path) -> None:
    if not path.exists():
        return
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


def configure_apple_credentials() -> None:
    os.environ.setdefault("ASC_KEY_ID", APPLE_KEY_ID)
    os.environ.setdefault("ASC_ISSUER_ID", APPLE_ISSUER_ID)
    os.environ.setdefault("ASC_PRIVATE_KEY_PATH", str(APPLE_PRIVATE_KEY))


def decimal_money(value: dict[str, Any]) -> Decimal:
    return Decimal(value.get("units", "0")) + Decimal(value.get("nanos", 0)) / Decimal(1_000_000_000)


def google_money(value: Decimal, currency: str) -> dict[str, Any]:
    units = int(value)
    nanos = int((value - Decimal(units)) * Decimal(1_000_000_000))
    return {"currencyCode": currency, "units": str(units), "nanos": nanos}


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
        data={
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": assertion,
        },
        timeout=30,
    )
    response.raise_for_status()
    return response.json()["access_token"]


def apple_price_points(client: ASCClient) -> list[dict[str, Any]]:
    payload = client.get_json(
        f"/subscriptions/{APPLE_SUBSCRIPTION_ID}/pricePoints",
        {
            "filter[territory]": APPLE_TERRITORY,
            "include": "territory",
            "limit": 8000,
        },
    )
    return payload["data"]


def apple_current_prices(client: ASCClient) -> list[dict[str, Any]]:
    payload = client.get_json(
        f"/subscriptions/{APPLE_SUBSCRIPTION_ID}/prices",
        {
            "filter[territory]": APPLE_TERRITORY,
            "include": "subscriptionPricePoint,territory",
            "limit": 200,
        },
    )
    included = {item["id"]: item for item in payload.get("included", [])}
    output: list[dict[str, Any]] = []
    for item in payload["data"]:
        point_id = item["relationships"]["subscriptionPricePoint"]["data"]["id"]
        point = included.get(point_id, {})
        output.append(
            {
                "id": item["id"],
                "startDate": item["attributes"].get("startDate"),
                "preserved": item["attributes"].get("preserved", False),
                "customerPrice": point.get("attributes", {}).get("customerPrice"),
                "proceeds": point.get("attributes", {}).get("proceeds"),
                "pricePointId": point_id,
            }
        )
    return output


def select_apple_price_point(client: ASCClient) -> dict[str, Any]:
    points = apple_price_points(client)
    exact = [point for point in points if Decimal(point["attributes"]["customerPrice"]) == APPLE_TARGET_PRICE]
    if exact:
        return exact[0]
    return min(
        points,
        key=lambda point: abs(Decimal(point["attributes"]["customerPrice"]) - APPLE_TARGET_PRICE),
    )


def apply_apple_price(client: ASCClient, price_point: dict[str, Any]) -> dict[str, Any]:
    return client.post_json(
        "/subscriptionPrices",
        {
            "data": {
                "type": "subscriptionPrices",
                "attributes": {
                    "startDate": (date.today() + timedelta(days=1)).isoformat(),
                    "preserveCurrentPrice": False,
                },
                "relationships": {
                    "subscription": {
                        "data": {"type": "subscriptions", "id": APPLE_SUBSCRIPTION_ID}
                    },
                    "subscriptionPricePoint": {
                        "data": {"type": "subscriptionPricePoints", "id": price_point["id"]}
                    },
                },
            }
        },
    )


def google_subscription(token: str) -> dict[str, Any]:
    url = (
        f"{GOOGLE_API_ROOT}/applications/{GOOGLE_PACKAGE_NAME}"
        f"/subscriptions/{GOOGLE_PRODUCT_ID}"
    )
    response = requests.get(url, headers={"Authorization": f"Bearer {token}"}, timeout=30)
    response.raise_for_status()
    return response.json()


def google_base_plan(payload: dict[str, Any]) -> dict[str, Any]:
    return next(plan for plan in payload["basePlans"] if plan["basePlanId"] == GOOGLE_BASE_PLAN_ID)


def google_region_config(payload: dict[str, Any]) -> dict[str, Any]:
    plan = google_base_plan(payload)
    return next(config for config in plan["regionalConfigs"] if config["regionCode"] == GOOGLE_REGION)


def google_regions_version(token: str) -> str:
    url = f"{GOOGLE_API_ROOT}/applications/{GOOGLE_PACKAGE_NAME}/pricing:convertRegionPrices"
    response = requests.post(
        url,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        json={"price": google_money(Decimal("1.00"), "USD")},
        timeout=30,
    )
    if response.status_code >= 400:
        raise RuntimeError(
            f"Google Play region-version lookup failed: {response.status_code}\n{response.text}"
        )
    version = response.json().get("regionVersion", {}).get("version")
    if not version:
        raise RuntimeError("Google Play region-version lookup returned no version")
    return version


def apply_google_price(token: str, current: dict[str, Any]) -> dict[str, Any]:
    updated = copy.deepcopy(current)
    google_region_config(updated)["price"] = google_money(GOOGLE_TARGET_PRICE, "BRL")

    url = (
        f"{GOOGLE_API_ROOT}/applications/{GOOGLE_PACKAGE_NAME}"
        f"/subscriptions/{GOOGLE_PRODUCT_ID}"
    )
    params: dict[str, str] = {
        "updateMask": "basePlans",
        "regionsVersion.version": google_regions_version(token),
    }

    response = requests.patch(
        url,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        params=params,
        json=updated,
        timeout=30,
    )
    if response.status_code >= 400:
        raise RuntimeError(f"Google Play update failed: {response.status_code}\n{response.text}")
    return response.json()


def print_summary(apple_point: dict[str, Any], apple_current: list[dict[str, Any]], google: dict[str, Any]) -> None:
    apple_attrs = apple_point["attributes"]
    google_config = google_region_config(google)
    print(
        "APPLE",
        APPLE_TERRITORY,
        f"selected_customer_price={apple_attrs['customerPrice']}",
        f"selected_proceeds={apple_attrs['proceeds']}",
    )
    for current in apple_current:
        print(
            "APPLE_CURRENT",
            f"customer_price={current['customerPrice']}",
            f"proceeds={current['proceeds']}",
            f"start_date={current['startDate']}",
            f"preserved={current['preserved']}",
        )
    print(
        "GOOGLE",
        GOOGLE_REGION,
        f"current_customer_price={decimal_money(google_config['price'])}",
        f"availability={google_config.get('newSubscriberAvailability')}",
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--confirm", default="")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    load_simple_env(REPOSITORY_ROOT / "store" / "google-play" / ".env")
    configure_apple_credentials()

    credentials_value = os.environ.get("GOOGLE_PLAY_JSON_KEY_PATH")
    if not credentials_value:
        raise SystemExit("GOOGLE_PLAY_JSON_KEY_PATH is required")
    credentials_path = Path(credentials_value).expanduser()

    apple_client = ASCClient()
    google_token = google_access_token(credentials_path)

    apple_point = select_apple_price_point(apple_client)
    apple_before = apple_current_prices(apple_client)
    google_before = google_subscription(google_token)
    print("BEFORE")
    print_summary(apple_point, apple_before, google_before)

    if not args.apply:
        print(f"DRY_RUN confirmation_required={CONFIRMATION}")
        return
    if args.confirm != CONFIRMATION:
        raise SystemExit(f"Refusing to apply without --confirm {CONFIRMATION}")

    apple_already_target = any(
        not price["preserved"]
        and price["customerPrice"] is not None
        and Decimal(price["customerPrice"]) == APPLE_TARGET_PRICE
        for price in apple_before
    )
    if apple_already_target:
        print("APPLE_SKIP already_at_target")
    else:
        apply_apple_price(apple_client, apple_point)

    google_before_price = decimal_money(google_region_config(google_before)["price"])
    if google_before_price == GOOGLE_TARGET_PRICE:
        google_result = google_before
        print("GOOGLE_SKIP already_at_target")
    else:
        google_result = apply_google_price(google_token, google_before)
    print("APPLIED")
    print(
        "GOOGLE_RESPONSE",
        f"customer_price={decimal_money(google_region_config(google_result)['price'])}",
    )

    apple_after = apple_current_prices(apple_client)
    google_after = google_subscription(google_token)
    print("AFTER")
    print_summary(apple_point, apple_after, google_after)


if __name__ == "__main__":
    main()
