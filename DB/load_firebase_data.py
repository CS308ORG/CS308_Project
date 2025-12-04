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
    "/Users/mehmetsalcan/Desktop/untitled folder/cs308db-firebase-adminsdk-fbsvc-3a93f74bd8.json",
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
            "role": "product_manager",
        },
        {
            "user_id": 2,
            "name": "Ayşe Demir",
            "email": "ayse@example.com",
            "password": "hashed_pass_2",
            "address": "Ankara, TR",
            "role": "sales_manager",
        },
        {
            "user_id": 3,
            "name": "Mehmet Kaya",
            "email": "mehmet@example.com",
            "password": "hashed_pass_3",
            "address": "Izmir, TR",
            "role": "support_agent",
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
            "name": "Burak Yılmaz",
            "email": "burak@example.com",
            "password": "hashed_pass_11",
            "address": "Istanbul, TR",
            "role": "customer",
        },
        {
            "user_id": 12,
            "name": "Selin Öztürk",
            "email": "selin@example.com",
            "password": "hashed_pass_12",
            "address": "Ankara, TR",
            "role": "customer",
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
            "description": "High-quality over-ear wireless headphones with noise cancellation.",
            "price": 1200,
            "quantity_in_stock": 0,
            "distributor_info": "TechDistributors",
            "category_ids": [1, 5],  # Electronics + Audio
            "image_url": "https://storage.googleapis.com/cs308db.firebasestorage.app/products/Wireless Headphones.png"
        },
        {
            "product_id": 2,
            "category_id": 6,
            "name": "Smartphone X 256GB",
            "description": "Powerful smartphone with 256GB storage and AMOLED display.",
            "price": 23000,
            "quantity_in_stock": 20,
            "distributor_info": "MobilePro",
            "category_ids": [6],  # Phones
            "image_url": "https://storage.googleapis.com/cs308db.firebasestorage.app/products/Smartphone.png"
        },
        {
            "product_id": 3,
            "category_id": 4,
            "name": "Laptop Pro 14",
            "description": "Lightweight laptop with 14-inch display and 16GB RAM.",
            "price": 32000,
            "quantity_in_stock": 15,
            "distributor_info": "CompWorld",
            "category_ids": [4],  # Computers
            "image_url": "https://storage.googleapis.com/cs308db.firebasestorage.app/products/Laptop.png"
        },
        {
            "product_id": 4,
            "category_id": 2,
            "name": "Cotton T-Shirt L",
            "description": "Comfortable cotton T-shirt, size L.",
            "price": 350,
            "quantity_in_stock": 60,
            "distributor_info": "FashionTextiles",
            "category_ids": [2],  # Wear
            "image_url": "https://storage.googleapis.com/cs308db.firebasestorage.app/products/T shirt.png"
        },
        {
            "product_id": 5,
            "category_id": 7,
            "name": "Air Fryer 4L",
            "description": "Healthy cooking air fryer with 4L capacity.",
            "price": 2200,
            "quantity_in_stock": 25,
            "distributor_info": "KitchenPro",
            "category_ids": [1, 3],  # Electronics + Home Appliances
            "image_url": "https://storage.googleapis.com/cs308db.firebasestorage.app/products/Aır Fryer.png"
        },
        {
            "product_id": 6,
            "category_id": 5,
            "name": "Bluetooth Speaker",
            "description": "Compact portable speaker with rich bass sound.",
            "price": 950,
            "quantity_in_stock": 35,
            "distributor_info": "SoundWave",
            "category_ids": [1, 5],  # Electronics + Audio
            "image_url": "https://storage.googleapis.com/cs308db.firebasestorage.app/products/Bluetooth Speaker.png"
        },
        {
            "product_id": 7,
            "category_id": 8,
            "name": "Game Controller",
            "description": "Wireless controller compatible with all major consoles.",
            "price": 1500,
            "quantity_in_stock": 25,
            "distributor_info": "Gamerz",
            "category_ids": [8],  # Gaming
            "image_url": "https://storage.googleapis.com/cs308db.firebasestorage.app/products/Controller.png"
        },
        {
            "product_id": 8,
            "category_id": 3,
            "name": "Vacuum Cleaner",
            "description": "Lightweight bagless vacuum cleaner with high suction power.",
            "price": 1800,
            "quantity_in_stock": 30,
            "distributor_info": "HomeCare",
            "category_ids": [1, 3],  # Electronics + Home Appliances
            "image_url": "https://storage.googleapis.com/cs308db.firebasestorage.app/products/Vacuum cleaner.png"
        },
        {
            "product_id": 9,
            "category_id": 9,
            "name": "Yoga Mat",
            "description": "Non-slip yoga mat for daily workouts and stretching.",
            "price": 400,
            "quantity_in_stock": 50,
            "distributor_info": "FitLife",
            "category_ids": [9],  # Sports
            "image_url": "https://storage.googleapis.com/cs308db.firebasestorage.app/products/Yoga Mat.png"
        },
        {
            "product_id": 10,
            "category_id": 10,
            "name": "Sci-Fi Novel",
            "description": "Bestselling science fiction novel set in a futuristic world.",
            "price": 250,
            "quantity_in_stock": 45,
            "distributor_info": "BookHub",
            "category_ids": [10],  # Books
            "image_url": "https://storage.googleapis.com/cs308db.firebasestorage.app/products/Scifi Novel.png"
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
        # User 1 (Ali) - 2 Orders
        {"order_id": 1, "user_id": 1, "total_amount": 1499.90, "status": "delivered", "date": "2023-09-15T14:30:00", "delivery_address": "Istanbul, TR"},
        {"order_id": 2, "user_id": 1, "total_amount": 399.80, "status": "processing", "date": "2023-11-20T09:15:00", "delivery_address": "Istanbul, TR"},
        # User 2 (Ayse) - 1 Order
        {"order_id": 3, "user_id": 2, "total_amount": 9999.00, "status": "in_transit", "date": "2023-11-18T16:20:00", "delivery_address": "Ankara, TR"},
        # User 3 (Mehmet) - 2 Orders
        {"order_id": 4, "user_id": 3, "total_amount": 3698.00, "status": "delivered", "date": "2023-08-05T11:00:00", "delivery_address": "Izmir, TR"},
        {"order_id": 5, "user_id": 3, "total_amount": 159.00, "status": "cancelled", "date": "2023-08-10T13:45:00", "delivery_address": "Izmir, TR"},
        # User 4 (Zeynep) - 1 Order
        {"order_id": 6, "user_id": 4, "total_amount": 349.00, "status": "delivered", "date": "2023-10-01T10:00:00", "delivery_address": "Bursa, TR"},
        # User 5 (Eren) - 3 Orders
        {"order_id": 7, "user_id": 5, "total_amount": 1199.00, "status": "delivered", "date": "2023-05-20T15:30:00", "delivery_address": "Antalya, TR"},
        {"order_id": 8, "user_id": 5, "total_amount": 27999.00, "status": "processing", "date": "2023-11-21T08:45:00", "delivery_address": "Antalya, TR"},
        {"order_id": 9, "user_id": 5, "total_amount": 199.90, "status": "in_transit", "date": "2023-11-19T19:20:00", "delivery_address": "Antalya, TR"},
        # User 6 (Elif) - 1 Order
        {"order_id": 10, "user_id": 6, "total_amount": 3499.00, "status": "delivered", "date": "2023-07-12T12:15:00", "delivery_address": "Eskişehir, TR"},
        # User 7 (Can) - 2 Orders
        {"order_id": 11, "user_id": 7, "total_amount": 1798.00, "status": "processing", "date": "2023-11-22T14:10:00", "delivery_address": "Adana, TR"},
        {"order_id": 12, "user_id": 7, "total_amount": 1499.90, "status": "delivered", "date": "2023-09-25T16:50:00", "delivery_address": "Adana, TR"},
        # User 8 (Naz) - 1 Order
        {"order_id": 13, "user_id": 8, "total_amount": 508.00, "status": "delivered", "date": "2023-10-30T09:00:00", "delivery_address": "Samsun, TR"},
        # User 9 (Mert) - 2 Orders
        {"order_id": 14, "user_id": 9, "total_amount": 27999.00, "status": "delivered", "date": "2023-06-15T11:30:00", "delivery_address": "Kocaeli, TR"},
        {"order_id": 15, "user_id": 9, "total_amount": 1199.00, "status": "in_transit", "date": "2023-11-18T10:20:00", "delivery_address": "Kocaeli, TR"},
        # User 10 (Deniz) - 2 Orders
        {"order_id": 16, "user_id": 10, "total_amount": 5598.00, "status": "processing", "date": "2023-11-21T15:45:00", "delivery_address": "Muğla, TR"},
        {"order_id": 17, "user_id": 10, "total_amount": 159.00, "status": "delivered", "date": "2023-08-20T14:00:00", "delivery_address": "Muğla, TR"},
    ]

    order_items = [
        # Order 1 (Ali): 1x Headphones
        {"order_item_id": 1, "order_id": 1, "product_id": 1, "quantity": 1, "unit_price": 1499.90},
        
        # Order 2 (Ali): 2x T-Shirts
        {"order_item_id": 2, "order_id": 2, "product_id": 4, "quantity": 2, "unit_price": 199.90},
        # Order 3 (Ayse): 1x Smartphone
        {"order_item_id": 3, "order_id": 3, "product_id": 2, "quantity": 1, "unit_price": 9999.00},
        # Order 4 (Mehmet): 1x Air Fryer + 1x Speaker
        {"order_item_id": 4, "order_id": 4, "product_id": 5, "quantity": 1, "unit_price": 2799.00},
        {"order_item_id": 5, "order_id": 4, "product_id": 6, "quantity": 1, "unit_price": 899.00},
        # Order 5 (Mehmet): 1x Novel
        {"order_item_id": 6, "order_id": 5, "product_id": 10, "quantity": 1, "unit_price": 159.00},
        # Order 6 (Zeynep): 1x Yoga Mat
        {"order_item_id": 7, "order_id": 6, "product_id": 9, "quantity": 1, "unit_price": 349.00},
        # Order 7 (Eren): 1x Controller
        {"order_item_id": 8, "order_id": 7, "product_id": 7, "quantity": 1, "unit_price": 1199.00},
        # Order 8 (Eren): 1x Laptop
        {"order_item_id": 9, "order_id": 8, "product_id": 3, "quantity": 1, "unit_price": 27999.00},
        # Order 9 (Eren): 1x T-Shirt
        {"order_item_id": 10, "order_id": 9, "product_id": 4, "quantity": 1, "unit_price": 199.90},
        # Order 10 (Elif): 1x Vacuum
        {"order_item_id": 11, "order_id": 10, "product_id": 8, "quantity": 1, "unit_price": 3499.00},
        # Order 11 (Can): 2x Speakers
        {"order_item_id": 12, "order_id": 11, "product_id": 6, "quantity": 2, "unit_price": 899.00},
        # Order 12 (Can): 1x Headphones
        {"order_item_id": 13, "order_id": 12, "product_id": 1, "quantity": 1, "unit_price": 1499.90},
        # Order 13 (Naz): 1x Yoga Mat + 1x Novel
        {"order_item_id": 14, "order_id": 13, "product_id": 9, "quantity": 1, "unit_price": 349.00},
        {"order_item_id": 15, "order_id": 13, "product_id": 10, "quantity": 1, "unit_price": 159.00},
        # Order 14 (Mert): 1x Laptop
        {"order_item_id": 16, "order_id": 14, "product_id": 3, "quantity": 1, "unit_price": 27999.00},
        # Order 15 (Mert): 1x Controller
        {"order_item_id": 17, "order_id": 15, "product_id": 7, "quantity": 1, "unit_price": 1199.00},
        # Order 16 (Deniz): 2x Air Fryers
        {"order_item_id": 18, "order_id": 16, "product_id": 5, "quantity": 2, "unit_price": 2799.00},
        # Order 17 (Deniz): 1x Novel
        {"order_item_id": 19, "order_id": 17, "product_id": 10, "quantity": 1, "unit_price": 159.00},
    ]

    reviews = [
        # --- Product 1: Wireless Headphones ---
        {
            "review_id": 101, "user_id": 1, "author_name": "Ali Yılmaz", "product_id": 1,
            "rating": 5, "comment": "Ses kalitesi harika, baslar çok güçlü.", "status": "approved", "timestamp": "2023-10-01T10:00:00Z"
        },
        {
            "review_id": 102, "user_id": 2, "author_name": "Ayşe Demir", "product_id": 1,
            "rating": 4, "comment": "Kulaklık biraz ağır ama performansı süper.", "status": "approved", "timestamp": "2023-10-02T14:30:00Z"
        },
        {
            "review_id": 103, "user_id": 3, "author_name": "Mehmet Kaya", "product_id": 1,
            "rating": 5, "comment": "", "status": "approved", "timestamp": "2023-10-03T09:15:00Z"
        },
        {
            "review_id": 104, "user_id": 4, "author_name": "Zeynep Koç", "product_id": 1,
            "rating": 5, "comment": "", "status": "approved", "timestamp": "2023-10-05T16:20:00Z"
        },
        # --- Product 2: Smartphone X 256GB ---
        {
            "review_id": 201, "user_id": 5, "author_name": "Eren Şahin", "product_id": 2,
            "rating": 4, "comment": "Ekran kalitesi muazzam, fakat şarjı 1 günü zor çıkarıyor.", "status": "approved", "timestamp": "2023-10-06T11:00:00Z"
        },
        {
            "review_id": 202, "user_id": 6, "author_name": "Elif Acar", "product_id": 2,
            "rating": 5, "comment": "Fiyat performans ürünü, tavsiye ederim.", "status": "approved", "timestamp": "2023-10-07T15:45:00Z"
        },
        {
            "review_id": 203, "user_id": 7, "author_name": "Can Arslan", "product_id": 2,
            "rating": 4, "comment": "", "status": "approved", "timestamp": "2023-10-08T10:30:00Z"
        },
        # --- Product 3: Laptop Pro 14 ---
        {
            "review_id": 301, "user_id": 8, "author_name": "Naz Aydın", "product_id": 3,
            "rating": 5, "comment": "İş için aldım, hızı inanılmaz.", "status": "approved", "timestamp": "2023-10-09T09:00:00Z"
        },
        {
            "review_id": 302, "user_id": 9, "author_name": "Mert Yıldız", "product_id": 3,
            "rating": 3, "comment": "Fan sesi biraz fazla çıkıyor yük altında.", "status": "approved", "timestamp": "2023-10-10T13:20:00Z"
        },
        {
            "review_id": 303, "user_id": 10, "author_name": "Deniz Güneş", "product_id": 3,
            "rating": 5, "comment": "", "status": "approved", "timestamp": "2023-10-11T16:50:00Z"
        },
        {
            "review_id": 304, "user_id": 1, "author_name": "Ali Yılmaz", "product_id": 3,
            "rating": 4, "comment": "", "status": "approved", "timestamp": "2023-10-12T12:10:00Z"
        },
        # --- Product 4: Cotton T-Shirt L ---
        {
            "review_id": 401, "user_id": 2, "author_name": "Ayşe Demir", "product_id": 4,
            "rating": 5, "comment": "Kumaşı çok yumuşak, tam beden.", "status": "approved", "timestamp": "2023-10-13T14:00:00Z"
        },
        {
            "review_id": 402, "user_id": 3, "author_name": "Mehmet Kaya", "product_id": 4,
            "rating": 2, "comment": "İlk yıkamada çekti maalesef.", "status": "approved", "timestamp": "2023-10-14T10:30:00Z"
        },
        {
            "review_id": 403, "user_id": 4, "author_name": "Zeynep Koç", "product_id": 4,
            "rating": 5, "comment": "", "status": "approved", "timestamp": "2023-10-15T11:45:00Z"
        },
        # --- Product 5: Air Fryer 4L ---
        {
            "review_id": 501, "user_id": 5, "author_name": "Eren Şahin", "product_id": 5,
            "rating": 5, "comment": "Mutfağımın vazgeçilmezi oldu, patatesler harika.", "status": "approved", "timestamp": "2023-10-16T17:00:00Z"
        },
        {
            "review_id": 502, "user_id": 6, "author_name": "Elif Acar", "product_id": 5,
            "rating": 5, "comment": "", "status": "approved", "timestamp": "2023-10-17T09:20:00Z"
        },
        {
            "review_id": 503, "user_id": 7, "author_name": "Can Arslan", "product_id": 5,
            "rating": 4, "comment": "", "status": "approved", "timestamp": "2023-10-18T13:10:00Z"
        },
        # --- Product 6: Bluetooth Speaker ---
        {
            "review_id": 601, "user_id": 8, "author_name": "Naz Aydın", "product_id": 6,
            "rating": 4, "comment": "Sesi boyutuna göre çok iyi.", "status": "approved", "timestamp": "2023-10-19T15:30:00Z"
        },
        {
            "review_id": 602, "user_id": 9, "author_name": "Mert Yıldız", "product_id": 6,
            "rating": 5, "comment": "", "status": "approved", "timestamp": "2023-10-20T10:00:00Z"
        },
        {
            "review_id": 603, "user_id": 10, "author_name": "Deniz Güneş", "product_id": 6,
            "rating": 5, "comment": "", "status": "approved", "timestamp": "2023-10-21T18:45:00Z"
        },
        # --- Product 7: Game Controller ---
        {
            "review_id": 701, "user_id": 1, "author_name": "Ali Yılmaz", "product_id": 7,
            "rating": 5, "comment": "Tuş hassasiyeti mükemmel, gecikme yok.", "status": "approved", "timestamp": "2023-10-22T11:15:00Z"
        },
        {
            "review_id": 702, "user_id": 2, "author_name": "Ayşe Demir", "product_id": 7,
            "rating": 3, "comment": "Analoglar biraz sert geldi bana.", "status": "approved", "timestamp": "2023-10-23T14:50:00Z"
        },
        {
            "review_id": 703, "user_id": 3, "author_name": "Mehmet Kaya", "product_id": 7,
            "rating": 5, "comment": "", "status": "approved", "timestamp": "2023-10-24T09:40:00Z"
        },
        # --- Product 8: Vacuum Cleaner ---
        {
            "review_id": 801, "user_id": 4, "author_name": "Zeynep Koç", "product_id": 8,
            "rating": 5, "comment": "Çekim gücü inanılmaz, halıları kaldırıyor.", "status": "approved", "timestamp": "2023-10-25T16:00:00Z"
        },
        {
            "review_id": 802, "user_id": 5, "author_name": "Eren Şahin", "product_id": 8,
            "rating": 4, "comment": "", "status": "approved", "timestamp": "2023-10-26T10:20:00Z"
        },
        {
            "review_id": 803, "user_id": 6, "author_name": "Elif Acar", "product_id": 8,
            "rating": 5, "comment": "", "status": "approved", "timestamp": "2023-10-27T13:10:00Z"
        },
        # --- Product 9: Yoga Mat ---
        {
            "review_id": 901, "user_id": 7, "author_name": "Can Arslan", "product_id": 9,
            "rating": 5, "comment": "Kayma yapmıyor, kalınlığı ideal.", "status": "approved", "timestamp": "2023-10-28T08:50:00Z"
        },
        {
            "review_id": 902, "user_id": 8, "author_name": "Naz Aydın", "product_id": 9,
            "rating": 5, "comment": "Rengi göründüğü gibi canlı.", "status": "approved", "timestamp": "2023-10-29T19:00:00Z"
        },
        {
            "review_id": 903, "user_id": 9, "author_name": "Mert Yıldız", "product_id": 9,
            "rating": 4, "comment": "", "status": "approved", "timestamp": "2023-10-30T12:30:00Z"
        },
        # --- Product 10: Sci-Fi Novel ---
        {
            "review_id": 1001, "user_id": 10, "author_name": "Deniz Güneş", "product_id": 10,
            "rating": 5, "comment": "Bir solukta okudum, harika bir kurgu.", "status": "approved", "timestamp": "2023-11-01T20:00:00Z"
        },
        {
            "review_id": 1002, "user_id": 1, "author_name": "Ali Yılmaz", "product_id": 10,
            "rating": 4, "comment": "Sonu biraz aceleye gelmiş gibiydi ama güzel.", "status": "approved", "timestamp": "2023-11-02T09:15:00Z"
        },
        {
            "review_id": 1003, "user_id": 2, "author_name": "Ayşe Demir", "product_id": 10,
            "rating": 5, "comment": "", "status": "approved", "timestamp": "2023-11-03T15:40:00Z"
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

    # --- NEW POPULARITY CALCULATION START ---
    # 1. Create a map to store total quantity sold per product
    sales_volume = {}

    for item in order_items:
        p_id = item["product_id"]
        qty = item["quantity"]
        # Sum the quantity for this product
        sales_volume[p_id] = sales_volume.get(p_id, 0) + qty

    # 2. Inject the calculated score into the products list
    for product in products:
        p_id = product["product_id"]
        # Get total sales, default to 0 if never sold
        total_sold = sales_volume.get(p_id, 0)
        product["popularity_score"] = total_sold
        print(f"Product {p_id} ({product['name']}): Popularity Score = {total_sold}")
    # --- NEW POPULARITY CALCULATION END ---

    upload_collection(db, "users", users, "user_id")
    upload_collection(db, "categories", categories, "category_id")
    upload_collection(db, "products", products, "product_id")
    upload_collection(db, "carts", carts, "cart_id")
    upload_collection(db, "cart_items", cart_items, "cart_item_id")
    upload_collection(db, "orders", orders, "order_id")
    upload_collection(db, "order_items", order_items, "order_item_id")
    upload_collection(db, "reviews", reviews, "review_id")
    upload_collection(db, "refunds", refunds, "refund_id")
    upload_collection(db, "signup_logs", signup_logs, "signup_id")
    upload_collection(db, "login_logs", login_logs, "login_id")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # pragma: no cover - simple script guard
        print(f"Failed to load data: {exc}", file=sys.stderr)
        raise
