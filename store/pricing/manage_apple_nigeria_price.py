#!/usr/bin/env python3
"""Inspect or apply the approved Nigeria yearly subscription price change."""

from __future__ import annotations

import argparse
import os
import sys
from datetime import date, timedelta
from decimal import Decimal
from pathlib import Path
from typing import Any


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
ASC_HELPERS = REPOSITORY_ROOT / "store" / "app-store" / "asc"
sys.path.insert(0, str(ASC_HELPERS))

from asc_client import ASCClient  # noqa: E402


SUBSCRIPTION_ID = "6758434018"
TERRITORY = "NGA"
TARGET_CUSTOMER_PRICE = Decimal("86900")
KEY_ID = "DDLSNSM264"
ISSUER_ID = "457129c5-26ac-400b-b9bc-dca88b17bd5d"
PRIVATE_KEY = REPOSITORY_ROOT / "store" / "app-store" / "fastlane" / "AuthKey_DDLSNSM264.p8"
CONFIRMATION = "APPLE-NGA-86900"


def configure_credentials() -> None:
    os.environ.setdefault("ASC_KEY_ID", KEY_ID)
    os.environ.setdefault("ASC_ISSUER_ID", ISSUER_ID)
    os.environ.setdefault("ASC_PRIVATE_KEY_PATH", str(PRIVATE_KEY))


def price_points(client: ASCClient) -> list[dict[str, Any]]:
    payload = client.get_json(
        f"/subscriptions/{SUBSCRIPTION_ID}/pricePoints",
        {"filter[territory]": TERRITORY, "include": "territory", "limit": 8000},
    )
    return payload["data"]


def current_prices(client: ASCClient) -> list[dict[str, Any]]:
    payload = client.get_json(
        f"/subscriptions/{SUBSCRIPTION_ID}/prices",
        {
            "filter[territory]": TERRITORY,
            "include": "subscriptionPricePoint,territory",
            "limit": 200,
        },
    )
    included = {item["id"]: item for item in payload.get("included", [])}
    output: list[dict[str, Any]] = []
    for item in payload["data"]:
        point_id = item["relationships"]["subscriptionPricePoint"]["data"]["id"]
        point = included[point_id]
        output.append(
            {
                "startDate": item["attributes"].get("startDate"),
                "preserved": item["attributes"].get("preserved", False),
                "customerPrice": Decimal(point["attributes"]["customerPrice"]),
                "proceeds": Decimal(point["attributes"]["proceeds"]),
            }
        )
    return output


def target_point(client: ASCClient) -> dict[str, Any]:
    points = price_points(client)
    matches = [
        point
        for point in points
        if Decimal(point["attributes"]["customerPrice"]) == TARGET_CUSTOMER_PRICE
    ]
    if not matches:
        nearest = sorted(
            points,
            key=lambda point: abs(
                Decimal(point["attributes"]["customerPrice"])
                - TARGET_CUSTOMER_PRICE
            ),
        )[:5]
        options = ", ".join(
            f"{point['attributes']['customerPrice']} (proceeds {point['attributes']['proceeds']})"
            for point in nearest
        )
        raise RuntimeError(
            f"No exact Apple price point for NGN {TARGET_CUSTOMER_PRICE}; nearest: {options}"
        )
    return matches[0]


def print_state(label: str, point: dict[str, Any], prices: list[dict[str, Any]]) -> None:
    attrs = point["attributes"]
    print(
        label,
        f"target_customer_price={attrs['customerPrice']}",
        f"target_proceeds={attrs['proceeds']}",
    )
    for price in prices:
        print(
            "CURRENT",
            f"customer_price={price['customerPrice']}",
            f"proceeds={price['proceeds']}",
            f"start_date={price['startDate']}",
            f"preserved={price['preserved']}",
        )


def apply_price(client: ASCClient, point: dict[str, Any]) -> None:
    client.post_json(
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
                        "data": {"type": "subscriptions", "id": SUBSCRIPTION_ID}
                    },
                    "subscriptionPricePoint": {
                        "data": {"type": "subscriptionPricePoints", "id": point["id"]}
                    },
                },
            }
        },
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--confirm", default="")
    args = parser.parse_args()

    configure_credentials()
    client = ASCClient()
    point = target_point(client)
    before = current_prices(client)
    print_state("BEFORE", point, before)

    if not args.apply:
        print(f"DRY_RUN confirmation_required={CONFIRMATION}")
        return
    if args.confirm != CONFIRMATION:
        raise SystemExit(f"Refusing to apply without --confirm {CONFIRMATION}")

    already_scheduled = any(
        not price["preserved"] and price["customerPrice"] == TARGET_CUSTOMER_PRICE
        for price in before
    )
    if already_scheduled:
        print("SKIP already_at_target")
    else:
        apply_price(client, point)

    after = current_prices(client)
    print_state("AFTER", point, after)
    if not any(
        not price["preserved"] and price["customerPrice"] == TARGET_CUSTOMER_PRICE
        for price in after
    ):
        raise RuntimeError("Apple Nigeria target price was not visible after the update")


if __name__ == "__main__":
    main()
