#!/usr/bin/env python3
"""Load sample online store data into Firestore using Firebase Admin SDK."""

from __future__ import annotations

import sys
import os
from typing import Iterable, Mapping

import firebase_admin
from firebase_admin import credentials, firestore


# Use env var if provided, else default to your local JSON path
SERVICE_ACCOUNT_PATH = os.environ.get(
    "SERVICE_ACCOUNT_PATH",
    "/Users/kaanzengel/Desktop/CS308_Project/Backend/my-firebase-sa.json",
)


def ensure_app() -> firestore.Client:
    """Initialise the Firebase app and return a Firestore client."""

    if not firebase_admin._apps:  # type: ignore[attr-defined]
        cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
        firebase_admin.initialize_app(cred)
    return firestore.client()


def upload_collection(
    db: firestore.Client,
    collection_name: str,
    records: Iterable[Mapping[str, object]],
    id_field: str,
) -> None:
    """Upload records to the given collection using the id_field as the doc id."""

    docs = list(records)
    for record in docs:
        record_id = record[id_field]
        doc_ref = db.collection(collection_name).document(str(record_id))
        doc_ref.set(dict(record))
    print(f"Uploaded {len(docs)} documents to collection '{collection_name}'.")


### I ADDED THE ROLE ADMIN TO THE USER TABLE

def main() -> None:
    db = ensure_app()

    users = [
        {
            "user_id": 1,
            "name": "Ali Yılmaz",
            "email": "ali@example.com",
            "password": "hashed_pass_1",
            "address": "Istanbul, TR",
            "role": "customer",
        },
        {
            "user_id": 2,
            "name": "Ayşe Demir",
            "email": "ayse@example.com",
            "password": "hashed_pass_2",
            "address": "Ankara, TR",
            "role": "customer",
        },
        {
            "user_id": 3,
            "name": "Mehmet Kaya",
            "email": "mehmet@example.com",
            "password": "hashed_pass_3",
            "address": "Izmir, TR",
            "role": "customer",
        },
        {
            "user_id": 4,
            "name": "Zeynep Koç",
            "email": "zeynep@example.com",
            "password": "hashed_pass_4",
            "address": "Bursa, TR",
            "role": "customer",
        },
        {
            "user_id": 5,
            "name": "Eren Şahin",
            "email": "eren@example.com",
            "password": "hashed_pass_5",
            "address": "Antalya, TR",
            "role": "customer",
        },
        {
            "user_id": 6,
            "name": "Elif Acar",
            "email": "elif@example.com",
            "password": "hashed_pass_6",
            "address": "Eskişehir, TR",
            "role": "customer",
        },
        {
            "user_id": 7,
            "name": "Can Arslan",
            "email": "can@example.com",
            "password": "hashed_pass_7",
            "address": "Adana, TR",
            "role": "customer",
        },
        {
            "user_id": 8,
            "name": "Naz Aydın",
            "email": "naz@example.com",
            "password": "hashed_pass_8",
            "address": "Samsun, TR",
            "role": "customer",
        },
        {
            "user_id": 9,
            "name": "Mert Yıldız",
            "email": "mert@example.com",
            "password": "hashed_pass_9",
            "address": "Kocaeli, TR",
            "role": "customer",
        },
        {
            "user_id": 10,
            "name": "Deniz Güneş",
            "email": "deniz@example.com",
            "password": "hashed_pass_10",
            "address": "Muğla, TR",
            "role": "customer",
        },
        {
            "user_id": 11,
            "name": "Admin Bir",
            "email": "admin1@example.com",
            "password": "hashed_pass_admin_1",
            "address": "Istanbul, TR",
            "role": "admin",
        },
        {
            "user_id": 12,
            "name": "Admin İki",
            "email": "admin2@example.com",
            "password": "hashed_pass_admin_2",
            "address": "Ankara, TR",
            "role": "admin",
        },
    ]

    categories = [
        {"category_id": 1, "name": "Electronics"},
        {"category_id": 2, "name": "Clothing"},
        {"category_id": 3, "name": "Home Appliances"},
        {"category_id": 4, "name": "Computers"},
        {"category_id": 5, "name": "Audio"},
        {"category_id": 6, "name": "Mobile"},
        {"category_id": 7, "name": "Kitchen"},
        {"category_id": 8, "name": "Gaming"},
        {"category_id": 9, "name": "Sports"},
        {"category_id": 10, "name": "Books"},
    ]

    products = [
        {
            "product_id": 1,
            "category_id": 1,
            "name": "Wireless Headphones",
            "model": "WH-100",
            "serial_number": "SN10001",
            "description": "BT 5.0 over-ear",
            "quantity_in_stock": 80,
            "price": 1499.90,
            "warranty_status": "2 years",
            "distributor_info": "TechDistributors",
        },
        {
            "product_id": 2,
            "category_id": 6,
            "name": "Smartphone X 256GB",
            "model": "SMPX-256",
            "serial_number": "SN10002",
            "description": "AMOLED 6.5\"",
            "quantity_in_stock": 45,
            "price": 9999.00,
            "warranty_status": "2 years",
            "distributor_info": "MobilePro",
        },
        {
            "product_id": 3,
            "category_id": 4,
            "name": "Laptop Pro 14",
            "model": "LP-14",
            "serial_number": "SN10003",
            "description": "14-inch, 16GB RAM",
            "quantity_in_stock": 30,
            "price": 27999.00,
            "warranty_status": "2 years",
            "distributor_info": "CompWorld",
        },
        {
            "product_id": 4,
            "category_id": 2,
            "name": "Cotton T-Shirt L",
            "model": "TSH-L",
            "serial_number": "SN10004",
            "description": "100% cotton",
            "quantity_in_stock": 200,
            "price": 199.90,
            "warranty_status": "none",
            "distributor_info": "FashionTextiles",
        },
        {
            "product_id": 5,
            "category_id": 7,
            "name": "Air Fryer 4L",
            "model": "AF-4L",
            "serial_number": "SN10005",
            "description": "4L capacity",
            "quantity_in_stock": 60,
            "price": 2799.00,
            "warranty_status": "1 year",
            "distributor_info": "KitchenPro",
        },
        {
            "product_id": 6,
            "category_id": 5,
            "name": "Bluetooth Speaker",
            "model": "SPK-20",
            "serial_number": "SN10006",
            "description": "Portable speaker",
            "quantity_in_stock": 120,
            "price": 899.00,
            "warranty_status": "1 year",
            "distributor_info": "SoundWave",
        },
        {
            "product_id": 7,
            "category_id": 8,
            "name": "Game Controller",
            "model": "GC-2",
            "serial_number": "SN10007",
            "description": "Wireless controller",
            "quantity_in_stock": 90,
            "price": 1199.00,
            "warranty_status": "1 year",
            "distributor_info": "Gamerz",
        },
        {
            "product_id": 8,
            "category_id": 3,
            "name": "Vacuum Cleaner",
            "model": "VC-900",
            "serial_number": "SN10008",
            "description": "Bagless 900W",
            "quantity_in_stock": 50,
            "price": 3499.00,
            "warranty_status": "2 years",
            "distributor_info": "HomeCare",
        },
        {
            "product_id": 9,
            "category_id": 9,
            "name": "Yoga Mat",
            "model": "YM-5",
            "serial_number": "SN10009",
            "description": "5mm non-slip",
            "quantity_in_stock": 150,
            "price": 349.00,
            "warranty_status": "none",
            "distributor_info": "FitLife",
        },
        {
            "product_id": 10,
            "category_id": 10,
            "name": "Sci-Fi Novel",
            "model": "BK-SF-01",
            "serial_number": "SN10010",
            "description": "Bestselling sci-fi",
            "quantity_in_stock": 500,
            "price": 159.00,
            "warranty_status": "none",
            "distributor_info": "BookHub",
        },
    ]

    carts = [
        {"cart_id": cart_id, "user_id": cart_id} for cart_id in range(1, 11)
    ]

    cart_items = [
        {"cart_item_id": 1, "cart_id": 1, "product_id": 1, "quantity": 1},
        {"cart_item_id": 2, "cart_id": 1, "product_id": 4, "quantity": 2},
        {"cart_item_id": 3, "cart_id": 2, "product_id": 2, "quantity": 1},
        {"cart_item_id": 4, "cart_id": 2, "product_id": 9, "quantity": 1},
        {"cart_item_id": 5, "cart_id": 3, "product_id": 5, "quantity": 1},
        {"cart_item_id": 6, "cart_id": 3, "product_id": 6, "quantity": 1},
        {"cart_item_id": 7, "cart_id": 4, "product_id": 3, "quantity": 1},
        {"cart_item_id": 8, "cart_id": 4, "product_id": 10, "quantity": 2},
        {"cart_item_id": 9, "cart_id": 5, "product_id": 7, "quantity": 1},
        {"cart_item_id": 10, "cart_id": 5, "product_id": 1, "quantity": 1},
        {"cart_item_id": 11, "cart_id": 6, "product_id": 8, "quantity": 1},
        {"cart_item_id": 12, "cart_id": 6, "product_id": 5, "quantity": 1},
        {"cart_item_id": 13, "cart_id": 7, "product_id": 6, "quantity": 2},
        {"cart_item_id": 14, "cart_id": 7, "product_id": 2, "quantity": 1},
        {"cart_item_id": 15, "cart_id": 8, "product_id": 4, "quantity": 1},
        {"cart_item_id": 16, "cart_id": 8, "product_id": 9, "quantity": 2},
        {"cart_item_id": 17, "cart_id": 9, "product_id": 10, "quantity": 1},
        {"cart_item_id": 18, "cart_id": 9, "product_id": 3, "quantity": 1},
        {"cart_item_id": 19, "cart_id": 10, "product_id": 7, "quantity": 2},
        {"cart_item_id": 20, "cart_id": 10, "product_id": 8, "quantity": 1},
    ]

    orders = [
        {"order_id": 1, "user_id": 1, "total_amount": 1899.70, "status": "processing"},
        {"order_id": 2, "user_id": 2, "total_amount": 9999.00, "status": "in_transit"},
        {"order_id": 3, "user_id": 3, "total_amount": 2799.00, "status": "delivered"},
        {"order_id": 4, "user_id": 4, "total_amount": 299.90, "status": "processing"},
        {"order_id": 5, "user_id": 5, "total_amount": 2698.90, "status": "delivered"},
        {"order_id": 6, "user_id": 6, "total_amount": 4698.00, "status": "in_transit"},
        {"order_id": 7, "user_id": 7, "total_amount": 2398.00, "status": "processing"},
        {"order_id": 8, "user_id": 8, "total_amount": 698.00, "status": "delivered"},
        {"order_id": 9, "user_id": 9, "total_amount": 28158.00, "status": "processing"},
        {"order_id": 10, "user_id": 10, "total_amount": 1558.00, "status": "delivered"},
    ]

    order_items = [
        {"order_item_id": 1, "order_id": 1, "product_id": 1, "quantity": 1, "unit_price": 1499.90},
        {"order_item_id": 2, "order_id": 1, "product_id": 4, "quantity": 2, "unit_price": 199.90},
        {"order_item_id": 3, "order_id": 2, "product_id": 2, "quantity": 1, "unit_price": 9999.00},
        {"order_item_id": 4, "order_id": 3, "product_id": 5, "quantity": 1, "unit_price": 2799.00},
        {"order_item_id": 5, "order_id": 4, "product_id": 4, "quantity": 1, "unit_price": 299.90},
        {"order_item_id": 6, "order_id": 5, "product_id": 7, "quantity": 1, "unit_price": 1199.00},
        {"order_item_id": 7, "order_id": 5, "product_id": 1, "quantity": 1, "unit_price": 1499.90},
        {"order_item_id": 8, "order_id": 6, "product_id": 8, "quantity": 1, "unit_price": 3499.00},
        {"order_item_id": 9, "order_id": 6, "product_id": 6, "quantity": 1, "unit_price": 1199.00},
        {"order_item_id": 10, "order_id": 7, "product_id": 6, "quantity": 2, "unit_price": 899.00},
        {"order_item_id": 11, "order_id": 8, "product_id": 9, "quantity": 2, "unit_price": 349.00},
        {"order_item_id": 12, "order_id": 9, "product_id": 3, "quantity": 1, "unit_price": 27999.00},
        {"order_item_id": 13, "order_id": 9, "product_id": 10, "quantity": 1, "unit_price": 159.00},
        {"order_item_id": 14, "order_id": 10, "product_id": 6, "quantity": 1, "unit_price": 899.00},
        {"order_item_id": 15, "order_id": 10, "product_id": 5, "quantity": 1, "unit_price": 659.00},
        {"order_item_id": 16, "order_id": 3, "product_id": 6, "quantity": 1, "unit_price": 899.00},
        {"order_item_id": 17, "order_id": 2, "product_id": 10, "quantity": 2, "unit_price": 159.00},
        {"order_item_id": 18, "order_id": 7, "product_id": 2, "quantity": 1, "unit_price": 9999.00},
        {"order_item_id": 19, "order_id": 8, "product_id": 10, "quantity": 1, "unit_price": 159.00},
        {"order_item_id": 20, "order_id": 5, "product_id": 9, "quantity": 1, "unit_price": 349.00},
    ]

    reviews = [
        {
            "review_id": 1,
            "user_id": 1,
            "product_id": 1,
            "rating": 5,
            "comment": "Ses kalitesi harika",
        },
        {
            "review_id": 2,
            "user_id": 2,
            "product_id": 2,
            "rating": 4,
            "comment": "Hızlı ama pil daha iyi olabilirdi",
        },
        {
            "review_id": 3,
            "user_id": 3,
            "product_id": 5,
            "rating": 5,
            "comment": "Yağsız çıtır sonuç",
        },
        {
            "review_id": 4,
            "user_id": 4,
            "product_id": 4,
            "rating": 3,
            "comment": "Kalite iyi, biraz bol",
        },
        {
            "review_id": 5,
            "user_id": 5,
            "product_id": 7,
            "rating": 4,
            "comment": "Tutuşu güzel",
        },
        {
            "review_id": 6,
            "user_id": 6,
            "product_id": 8,
            "rating": 5,
            "comment": "Çekim gücü yüksek",
        },
        {
            "review_id": 7,
            "user_id": 7,
            "product_id": 6,
            "rating": 4,
            "comment": "Taşınabilir ve güçlü",
        },
        {
            "review_id": 8,
            "user_id": 8,
            "product_id": 9,
            "rating": 5,
            "comment": "Kaymıyor, memnunum",
        },
        {
            "review_id": 9,
            "user_id": 9,
            "product_id": 3,
            "rating": 5,
            "comment": "Performans şahane",
        },
        {
            "review_id": 10,
            "user_id": 10,
            "product_id": 10,
            "rating": 4,
            "comment": "Aksiyon dolu, akıcı",
        },
    ]

    signup_logs = [
        {
            "signup_id": 1,
            "user_id": 1,
            "email": "ali@example.com",
            "timestamp": "2025-01-01T10:00:00Z",
            "method": "email_password",
        },
        {
            "signup_id": 2,
            "user_id": 2,
            "email": "ayse@example.com",
            "timestamp": "2025-01-02T09:30:00Z",
            "method": "email_password",
        },
        {
            "signup_id": 3,
            "user_id": 3,
            "email": "mehmet@example.com",
            "timestamp": "2025-01-03T14:20:00Z",
            "method": "email_password",
        },
    ]

    login_logs = [
        {
            "login_id": 1,
            "user_id": 1,
            "email": "ali@example.com",
            "timestamp": "2025-01-10T08:40:00Z",
            "success": True,
            "ip_address": "192.168.1.10",
        },
        {
            "login_id": 2,
            "user_id": 2,
            "email": "ayse@example.com",
            "timestamp": "2025-01-10T10:00:00Z",
            "success": False,
            "ip_address": "192.168.1.11",
        },
        {
            "login_id": 3,
            "user_id": 3,
            "email": "mehmet@example.com",
            "timestamp": "2025-01-10T12:20:00Z",
            "success": True,
            "ip_address": "192.168.1.12",
        },
    ]

    refunds = [
        {
            "refund_id": 1,
            "order_id": 3,
            "product_id": 5,
            "reason": "Kutuda ezik vardı",
            "status": "requested",
        },
        {
            "refund_id": 2,
            "order_id": 2,
            "product_id": 2,
            "reason": "Modeli değiştirmek istiyorum",
            "status": "rejected",
        },
        {
            "refund_id": 3,
            "order_id": 5,
            "product_id": 7,
            "reason": "Uygun olmadı",
            "status": "approved",
        },
        {
            "refund_id": 4,
            "order_id": 6,
            "product_id": 8,
            "reason": "Beklediğim gibi değil",
            "status": "requested",
        },
        {
            "refund_id": 5,
            "order_id": 7,
            "product_id": 6,
            "reason": "Yanlış sipariş",
            "status": "requested",
        },
        {
            "refund_id": 6,
            "order_id": 8,
            "product_id": 9,
            "reason": "Renk beğenilmedi",
            "status": "refunded",
        },
        {
            "refund_id": 7,
            "order_id": 1,
            "product_id": 4,
            "reason": "Beden uymadı",
            "status": "requested",
        },
        {
            "refund_id": 8,
            "order_id": 9,
            "product_id": 3,
            "reason": "Ölü piksel şüphesi",
            "status": "requested",
        },
        {
            "refund_id": 9,
            "order_id": 10,
            "product_id": 6,
            "reason": "Hediye olarak alınmıştı",
            "status": "approved",
        },
        {
            "refund_id": 10,
            "order_id": 5,
            "product_id": 1,
            "reason": "Kulak pedleri rahatsız etti",
            "status": "requested",
        },
    ]

    upload_collection(db, "users", users, "user_id")
    upload_collection(db, "categories", categories, "category_id")
    upload_collection(db, "products", products, "product_id")
    upload_collection(db, "carts", carts, "cart_id")
    upload_collection(db, "cart_items", cart_items, "cart_item_id")
    upload_collection(db, "orders", orders, "order_id")
    upload_collection(db, "order_items", order_items, "order_item_id")
    upload_collection(db, "reviews", reviews, "review_id")
    upload_collection(db, "refunds", refunds, "refund_id")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # pragma: no cover - simple script guard
        print(f"Failed to load data: {exc}", file=sys.stderr)
        raise

upload_collection(db, "signup_logs", signup_logs, "signup_id")
upload_collection(db, "login_logs", login_logs, "login_id")
