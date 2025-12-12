import firebase_admin
from firebase_admin import credentials, firestore
import sys
import os
from datetime import datetime

# USE THE CORRECT RELATIVE PATH TO YOUR KEY
SERVICE_ACCOUNT_PATH = os.environ.get(
    "SERVICE_ACCOUNT_PATH",
    "../Backend/my-firebase.json"
)

def ensure_app():
    if not firebase_admin._apps:
        cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
        firebase_admin.initialize_app(cred)
    return firestore.client()

def upload_collection(db, collection_name, records, id_field):
    batch = db.batch()
    count = 0
    for record in records:
        # Convert IDs to string for document keys
        record_id = str(record[id_field])
        doc_ref = db.collection(collection_name).document(record_id)
        
        # FIX: Ensure created_at exists for Orders to prevent backend filtering
        if collection_name == 'orders' and 'date' in record and 'created_at' not in record:
            # Create a Firestore-compatible timestamp from the ISO string
            try:
                dt = datetime.fromisoformat(record['date'])
                record['created_at'] = dt
            except:
                record['created_at'] = record['date']

        batch.set(doc_ref, record)
        count += 1
        if count % 400 == 0:
            batch.commit()
            batch = db.batch()
            
    if count % 400 != 0:
        batch.commit()
    print(f"Uploaded {count} documents to '{collection_name}'")

def main():
    try:
        db = ensure_app()
    except Exception as e:
        print(f"Error: {e}")
        print("Check that '../Backend/my-firebase.json' exists.")
        return

    # --- 1. PRESERVED DATA (Users, Products, Reviews, etc.) ---
    
    users = [
        { "user_id": 1, "name": "Ali Yılmaz", "email": "ali@example.com", "password": "hashed_pass_1", "address": "Istanbul, TR", "role": "product_manager" },
        { "user_id": 2, "name": "Ayşe Demir", "email": "ayse@example.com", "password": "hashed_pass_2", "address": "Ankara, TR", "role": "sales_manager" },
        { "user_id": 3, "name": "Mehmet Kaya", "email": "mehmet@example.com", "password": "hashed_pass_3", "address": "Izmir, TR", "role": "support_agent" },
        { "user_id": 4, "name": "Zeynep Koç", "email": "zeynep@example.com", "password": "hashed_pass_4", "address": "Bursa, TR", "role": "customer" },
        { "user_id": 5, "name": "Eren Şahin", "email": "eren@example.com", "password": "hashed_pass_5", "address": "Antalya, TR", "role": "customer" },
        { "user_id": 6, "name": "Elif Acar", "email": "elif@example.com", "password": "hashed_pass_6", "address": "Eskişehir, TR", "role": "customer" },
        { "user_id": 7, "name": "Can Arslan", "email": "can@example.com", "password": "hashed_pass_7", "address": "Adana, TR", "role": "customer" },
        { "user_id": 8, "name": "Naz Aydın", "email": "naz@example.com", "password": "hashed_pass_8", "address": "Samsun, TR", "role": "customer" },
        { "user_id": 9, "name": "Mert Yıldız", "email": "mert@example.com", "password": "hashed_pass_9", "address": "Kocaeli, TR", "role": "customer" },
        { "user_id": 10, "name": "Deniz Güneş", "email": "deniz@example.com", "password": "hashed_pass_10", "address": "Muğla, TR", "role": "customer" },
        { "user_id": 11, "name": "Burak Yılmaz", "email": "burak@example.com", "password": "hashed_pass_11", "address": "Istanbul, TR", "role": "customer" },
        { "user_id": 12, "name": "Selin Öztürk", "email": "selin@example.com", "password": "hashed_pass_12", "address": "Ankara, TR", "role": "customer" },
        { "user_id": 13, "name": "fatma irem ulusal", "email": "irem_ulusal1@hotmail.com", "password": "$2b$10$0GRbmPDPVpsp2RkEb2XRf.byrjOO50NLMdkf8Hl1sLMT.iMS9sdsm", "address": "", "role": "customer", "created_at": "2025-12-01T19:49:48.741Z" }
    ]

    categories = [
        { "category_id": 1, "name": "Electronics" },
        { "category_id": 2, "name": "Clothing" },
        { "category_id": 3, "name": "Home Appliances" },
        { "category_id": 4, "name": "Computers" },
        { "category_id": 5, "name": "Audio" },
        { "category_id": 6, "name": "Mobile" },
        { "category_id": 7, "name": "Kitchen" },
        { "category_id": 8, "name": "Gaming" },
        { "category_id": 9, "name": "Sports" },
        { "category_id": 10, "name": "Books" }
    ]

    products = [
        { "product_id": 1, "category_id": 1, "name": "Wireless Headphones", "model": "WH-100", "serial_number": "SN10001", "description": "High-quality over-ear wireless headphones with noise cancellation.", "quantity_in_stock": 0, "price": 1499.90, "warranty_status": "2 years", "distributor_info": "TechDistributors", "popularity_score": 2, "category_ids": [1, 5], "image_url": "https://storage.googleapis.com/cs308db.firebasestorage.app/products/Wireless Headphones.png" },
        { "product_id": 2, "category_id": 6, "name": "Smartphone X 256GB", "model": "SMPX-256", "serial_number": "SN10002", "description": "Powerful smartphone with 256GB storage and AMOLED display.", "quantity_in_stock": 20, "price": 9999.00, "warranty_status": "2 years", "distributor_info": "MobilePro", "popularity_score": 1, "category_ids": [6], "image_url": "https://storage.googleapis.com/cs308db.firebasestorage.app/products/Smartphone.png" },
        { "product_id": 3, "category_id": 4, "name": "Laptop Pro 14", "model": "LP-14", "serial_number": "SN10003", "description": "Lightweight laptop with 14-inch display and 16GB RAM.", "quantity_in_stock": 15, "price": 27999.00, "warranty_status": "2 years", "distributor_info": "CompWorld", "popularity_score": 2, "category_ids": [4], "image_url": "https://storage.googleapis.com/cs308db.firebasestorage.app/products/Laptop.png" },
        { "product_id": 4, "category_id": 2, "name": "Cotton T-Shirt L", "model": "TSH-L", "serial_number": "SN10004", "description": "Comfortable cotton T-shirt, size L.", "quantity_in_stock": 60, "price": 199.90, "warranty_status": "none", "distributor_info": "FashionTextiles", "popularity_score": 3, "category_ids": [2], "image_url": "https://storage.googleapis.com/cs308db.firebasestorage.app/products/T shirt.png" },
        { "product_id": 5, "category_id": 7, "name": "Air Fryer 4L", "model": "AF-4L", "serial_number": "SN10005", "description": "Healthy cooking air fryer with 4L capacity.", "quantity_in_stock": 25, "price": 2799.00, "warranty_status": "1 year", "distributor_info": "KitchenPro", "popularity_score": 3, "category_ids": [1, 3], "image_url": "https://storage.googleapis.com/cs308db.firebasestorage.app/products/A\u0131r Fryer.png" },
        { "product_id": 6, "category_id": 5, "name": "Bluetooth Speaker", "model": "SPK-20", "serial_number": "SN10006", "description": "Compact portable speaker with rich bass sound.", "quantity_in_stock": 35, "price": 899.00, "warranty_status": "1 year", "distributor_info": "SoundWave", "popularity_score": 3, "category_ids": [1, 5], "image_url": "https://storage.googleapis.com/cs308db.firebasestorage.app/products/Bluetooth Speaker.png" },
        { "product_id": 7, "category_id": 8, "name": "Game Controller", "model": "GC-2", "serial_number": "SN10007", "description": "Wireless controller compatible with all major consoles.", "quantity_in_stock": 25, "price": 1199.00, "warranty_status": "1 year", "distributor_info": "Gamerz", "popularity_score": 2, "category_ids": [8], "image_url": "https://storage.googleapis.com/cs308db.firebasestorage.app/products/Controller.png" },
        { "product_id": 8, "category_id": 3, "name": "Vacuum Cleaner", "model": "VC-900", "serial_number": "SN10008", "description": "Lightweight bagless vacuum cleaner with high suction power.", "quantity_in_stock": 30, "price": 3499.00, "warranty_status": "2 years", "distributor_info": "HomeCare", "popularity_score": 1, "category_ids": [1, 3], "image_url": "https://storage.googleapis.com/cs308db.firebasestorage.app/products/Vacuum cleaner.png" },
        { "product_id": 9, "category_id": 9, "name": "Yoga Mat", "model": "YM-5", "serial_number": "SN10009", "description": "Non-slip yoga mat for daily workouts and stretching.", "quantity_in_stock": 50, "price": 349.00, "warranty_status": "none", "distributor_info": "FitLife", "popularity_score": 2, "category_ids": [9], "image_url": "https://storage.googleapis.com/cs308db.firebasestorage.app/products/Yoga Mat.png" },
        { "product_id": 10, "category_id": 10, "name": "Sci-Fi Novel", "model": "BK-SF-01", "serial_number": "SN10010", "description": "Bestselling science fiction novel set in a futuristic world.", "quantity_in_stock": 45, "price": 159.00, "warranty_status": "none", "distributor_info": "BookHub", "popularity_score": 3, "category_ids": [10], "image_url": "https://storage.googleapis.com/cs308db.firebasestorage.app/products/Scifi Novel.png" }
    ]

    carts = [ {"cart_id": i, "user_id": i} for i in range(1, 11) ]

    cart_items = [
        { "cart_item_id": 1, "cart_id": 1, "product_id": 1, "quantity": 1 },
        { "cart_item_id": 2, "cart_id": 1, "product_id": 4, "quantity": 2 },
        { "cart_item_id": 3, "cart_id": 2, "product_id": 2, "quantity": 1 },
        { "cart_item_id": 4, "cart_id": 2, "product_id": 9, "quantity": 1 },
        { "cart_item_id": 5, "cart_id": 3, "product_id": 5, "quantity": 1 },
        { "cart_item_id": 6, "cart_id": 3, "product_id": 6, "quantity": 1 },
        { "cart_item_id": 7, "cart_id": 4, "product_id": 3, "quantity": 1 },
        { "cart_item_id": 8, "cart_id": 4, "product_id": 10, "quantity": 2 },
        { "cart_item_id": 9, "cart_id": 5, "product_id": 7, "quantity": 1 },
        { "cart_item_id": 10, "cart_id": 5, "product_id": 1, "quantity": 1 },
        { "cart_item_id": 11, "cart_id": 6, "product_id": 8, "quantity": 1 },
        { "cart_item_id": 12, "cart_id": 6, "product_id": 5, "quantity": 1 },
        { "cart_item_id": 13, "cart_id": 7, "product_id": 6, "quantity": 2 },
        { "cart_item_id": 14, "cart_id": 7, "product_id": 2, "quantity": 1 },
        { "cart_item_id": 15, "cart_id": 8, "product_id": 4, "quantity": 1 },
        { "cart_item_id": 16, "cart_id": 8, "product_id": 9, "quantity": 2 },
        { "cart_item_id": 17, "cart_id": 9, "product_id": 10, "quantity": 1 },
        { "cart_item_id": 18, "cart_id": 9, "product_id": 3, "quantity": 1 },
        { "cart_item_id": 19, "cart_id": 10, "product_id": 7, "quantity": 2 },
        { "cart_item_id": 20, "cart_id": 10, "product_id": 8, "quantity": 1 }
    ]

    reviews = [
        { "review_id": 1, "user_id": 1, "product_id": 1, "rating": 5, "comment": "Ses kalitesi harika" },
        { "review_id": 2, "user_id": 2, "product_id": 2, "rating": 4, "comment": "Hızlı ama pil daha iyi olabilirdi" },
        { "review_id": 3, "user_id": 3, "product_id": 5, "rating": 5, "comment": "Yağsız çıtır sonuç" },
        { "review_id": 4, "user_id": 4, "product_id": 4, "rating": 3, "comment": "Kalite iyi, biraz bol" },
        { "review_id": 5, "user_id": 5, "product_id": 7, "rating": 4, "comment": "Tutuşu güzel" },
        { "review_id": 6, "user_id": 6, "product_id": 8, "rating": 5, "comment": "Çekim gücü yüksek" },
        { "review_id": 7, "user_id": 7, "product_id": 6, "rating": 4, "comment": "Taşınabilir ve güçlü" },
        { "review_id": 8, "user_id": 8, "product_id": 9, "rating": 5, "comment": "Kaymıyor, memnunum" },
        { "review_id": 9, "user_id": 9, "product_id": 3, "rating": 5, "comment": "Performans şahane" },
        { "review_id": 10, "user_id": 10, "product_id": 10, "rating": 4, "comment": "Aksiyon dolu, akıcı" },
        { "review_id": 101, "user_id": 1, "product_id": 1, "rating": 5, "comment": "Ses kalitesi harika, baslar çok güçlü.", "approval_status": "approved", "timestamp": "2023-10-01T10:00:00Z", "author_name": "Ali Yılmaz" },
        { "review_id": 102, "user_id": 2, "product_id": 1, "rating": 4, "comment": "Kulaklık biraz ağır ama performansı süper.", "approval_status": "approved", "timestamp": "2023-10-02T14:30:00Z", "author_name": "Ayşe Demir" },
        { "review_id": 103, "user_id": 3, "product_id": 1, "rating": 5, "comment": "", "approval_status": "approved", "timestamp": "2023-10-03T09:15:00Z", "author_name": "Mehmet Kaya" },
        { "review_id": 104, "user_id": 4, "product_id": 1, "rating": 5, "comment": "", "approval_status": "approved", "timestamp": "2023-10-05T16:20:00Z", "author_name": "Zeynep Koç" },
        { "review_id": 1001, "user_id": 10, "product_id": 10, "rating": 5, "comment": "Bir solukta okudum, harika bir kurgu.", "approval_status": "approved", "timestamp": "2023-11-01T20:00:00Z", "author_name": "Deniz Güneş" },
        { "review_id": 1002, "user_id": 1, "product_id": 10, "rating": 4, "comment": "Sonu biraz aceleye gelmiş gibiydi ama güzel.", "approval_status": "approved", "timestamp": "2023-11-02T09:15:00Z", "author_name": "Ali Yılmaz" },
        { "review_id": 1003, "user_id": 2, "product_id": 10, "rating": 5, "comment": "", "approval_status": "approved", "timestamp": "2023-11-03T15:40:00Z", "author_name": "Ayşe Demir" },
        { "review_id": "1764166823006", "user_id": "1", "product_id": 10, "rating": 3, "comment": "", "status": "approved", "timestamp": "2025-11-26T14:20:23.006Z", "author_name": "Ali Yılmaz" },
        { "review_id": "1764168099542", "user_id": "1", "product_id": 1, "rating": 3, "comment": "haha\n", "status": "pending", "timestamp": "2025-11-26T14:41:39.542Z", "author_name": "Ali Yılmaz" },
        { "review_id": "1764168103621", "user_id": "1", "product_id": 1, "rating": 3, "comment": "", "status": "approved", "timestamp": "2025-11-26T14:41:43.621Z", "author_name": "Ali Yılmaz" },
        { "review_id": "1764247273928", "user_id": "1", "product_id": 2, "rating": 1, "comment": "hello\n", "status": "pending", "timestamp": "2025-11-27T12:41:13.928Z", "author_name": "Ali Yılmaz" },
        { "review_id": "1764339860404", "user_id": "1", "product_id": 1, "rating": 2, "comment": "sdadf", "status": "pending", "timestamp": "2025-11-28T14:24:20.404Z", "author_name": "Ali Yılmaz", "approval_status": "pending", "moderated_by": None, "approval_reason": None },
        { "review_id": "1764855471782", "user_id": "8", "product_id": 9, "rating": 3, "comment": "haha", "status": "pending", "timestamp": "2025-12-04T13:37:51.782Z", "author_name": "Naz Aydın", "approval_status": "pending", "moderated_by": None, "approval_reason": None },
        { "review_id": "1764855481928", "user_id": "8", "product_id": 9, "rating": 4, "comment": "", "status": "pending", "timestamp": "2025-12-04T13:38:01.928Z", "author_name": "Naz Aydın", "approval_status": "pending", "moderated_by": None, "approval_reason": None },
        { "review_id": 201, "user_id": 5, "product_id": 2, "rating": 4, "comment": "Ekran kalitesi muazzam, fakat şarjı 1 günü zor çıkarıyor.", "approval_status": "approved", "timestamp": "2023-10-06T11:00:00Z", "author_name": "Eren Şahin" },
        { "review_id": 202, "user_id": 6, "product_id": 2, "rating": 5, "comment": "Fiyat performans ürünü, tavsiye ederim.", "approval_status": "approved", "timestamp": "2023-10-07T15:45:00Z", "author_name": "Elif Acar" },
        { "review_id": 203, "user_id": 7, "product_id": 2, "rating": 4, "comment": "", "approval_status": "approved", "timestamp": "2023-10-08T10:30:00Z", "author_name": "Can Arslan" },
        { "review_id": 301, "user_id": 8, "product_id": 3, "rating": 5, "comment": "İş için aldım, hızı inanılmaz.", "approval_status": "approved", "timestamp": "2023-10-09T09:00:00Z", "author_name": "Naz Aydın" },
        { "review_id": 302, "user_id": 9, "product_id": 3, "rating": 3, "comment": "Fan sesi biraz fazla çıkıyor yük altında.", "approval_status": "approved", "timestamp": "2023-10-10T13:20:00Z", "author_name": "Mert Yıldız" },
        { "review_id": 303, "user_id": 10, "product_id": 3, "rating": 5, "comment": "", "approval_status": "approved", "timestamp": "2023-10-11T16:50:00Z", "author_name": "Deniz Güneş" },
        { "review_id": 304, "user_id": 1, "product_id": 3, "rating": 4, "comment": "", "approval_status": "approved", "timestamp": "2023-10-12T12:10:00Z", "author_name": "Ali Yılmaz" },
        { "review_id": 401, "user_id": 2, "product_id": 4, "rating": 5, "comment": "Kumaşı çok yumuşak, tam beden.", "approval_status": "approved", "timestamp": "2023-10-13T14:00:00Z", "author_name": "Ayşe Demir" },
        { "review_id": 402, "user_id": 3, "product_id": 4, "rating": 2, "comment": "İlk yıkamada çekti maalesef.", "approval_status": "approved", "timestamp": "2023-10-14T10:30:00Z", "author_name": "Mehmet Kaya" },
        { "review_id": 403, "user_id": 4, "product_id": 4, "rating": 5, "comment": "", "approval_status": "approved", "timestamp": "2023-10-15T11:45:00Z", "author_name": "Zeynep Koç" },
        { "review_id": 501, "user_id": 5, "product_id": 5, "rating": 5, "comment": "Mutfağımın vazgeçilmezi oldu, patatesler harika.", "approval_status": "approved", "timestamp": "2023-10-16T17:00:00Z", "author_name": "Eren Şahin" },
        { "review_id": 502, "user_id": 6, "product_id": 5, "rating": 5, "comment": "", "approval_status": "approved", "timestamp": "2023-10-17T09:20:00Z", "author_name": "Elif Acar" },
        { "review_id": 503, "user_id": 7, "product_id": 5, "rating": 4, "comment": "", "approval_status": "approved", "timestamp": "2023-10-18T13:10:00Z", "author_name": "Can Arslan" },
        { "review_id": 601, "user_id": 8, "product_id": 6, "rating": 4, "comment": "Sesi boyutuna göre çok iyi.", "approval_status": "approved", "timestamp": "2023-10-19T15:30:00Z", "author_name": "Naz Aydın" },
        { "review_id": 602, "user_id": 9, "product_id": 6, "rating": 5, "comment": "", "approval_status": "approved", "timestamp": "2023-10-20T10:00:00Z", "author_name": "Mert Yıldız" },
        { "review_id": 603, "user_id": 10, "product_id": 6, "rating": 5, "comment": "", "approval_status": "approved", "timestamp": "2023-10-21T18:45:00Z", "author_name": "Deniz Güneş" },
        { "review_id": 701, "user_id": 1, "product_id": 7, "rating": 5, "comment": "Tuş hassasiyeti mükemmel, gecikme yok.", "approval_status": "approved", "timestamp": "2023-10-22T11:15:00Z", "author_name": "Ali Yılmaz" },
        { "review_id": 702, "user_id": 2, "product_id": 7, "rating": 3, "comment": "Analoglar biraz sert geldi bana.", "approval_status": "approved", "timestamp": "2023-10-23T14:50:00Z", "author_name": "Ayşe Demir" },
        { "review_id": 703, "user_id": 3, "product_id": 7, "rating": 5, "comment": "", "approval_status": "approved", "timestamp": "2023-10-24T09:40:00Z", "author_name": "Mehmet Kaya" },
        { "review_id": 801, "user_id": 4, "product_id": 8, "rating": 5, "comment": "Çekim gücü inanılmaz, halıları kaldırıyor.", "approval_status": "approved", "timestamp": "2023-10-25T16:00:00Z", "author_name": "Zeynep Koç" },
        { "review_id": 802, "user_id": 5, "product_id": 8, "rating": 4, "comment": "", "approval_status": "approved", "timestamp": "2023-10-26T10:20:00Z", "author_name": "Eren Şahin" },
        { "review_id": 803, "user_id": 6, "product_id": 8, "rating": 5, "comment": "", "approval_status": "approved", "timestamp": "2023-10-27T13:10:00Z", "author_name": "Elif Acar" },
        { "review_id": 901, "user_id": 7, "product_id": 9, "rating": 5, "comment": "Kayma yapmıyor, kalınlığı ideal.", "approval_status": "approved", "timestamp": "2023-10-28T08:50:00Z", "author_name": "Can Arslan" },
        { "review_id": 902, "user_id": 8, "product_id": 9, "rating": 5, "comment": "Rengi göründüğü gibi canlı.", "approval_status": "approved", "timestamp": "2023-10-29T19:00:00Z", "author_name": "Naz Aydın" },
        { "review_id": 903, "user_id": 9, "product_id": 9, "rating": 4, "comment": "", "approval_status": "approved", "timestamp": "2023-10-30T12:30:00Z", "author_name": "Mert Yıldız" }
    ]

    refunds = [
        { "refund_id": 1, "order_id": 3, "product_id": 5, "reason": "Kutuda ezik vardı", "status": "requested" },
        { "refund_id": 2, "order_id": 2, "product_id": 2, "reason": "Modeli değiştirmek istiyorum", "status": "rejected" },
        { "refund_id": 3, "order_id": 5, "product_id": 7, "reason": "Uygun olmadı", "status": "approved" },
        { "refund_id": 4, "order_id": 6, "product_id": 8, "reason": "Beklediğim gibi değil", "status": "requested" },
        { "refund_id": 5, "order_id": 7, "product_id": 6, "reason": "Yanlış sipariş", "status": "requested" },
        { "refund_id": 6, "order_id": 8, "product_id": 9, "reason": "Renk beğenilmedi", "status": "refunded" },
        { "refund_id": 7, "order_id": 1, "product_id": 4, "reason": "Beden uymadı", "status": "requested" },
        { "refund_id": 8, "order_id": 9, "product_id": 3, "reason": "Ölü piksel şüphesi", "status": "requested" },
        { "refund_id": 9, "order_id": 10, "product_id": 6, "reason": "Hediye olarak alınmıştı", "status": "approved" },
        { "refund_id": 10, "order_id": 5, "product_id": 1, "reason": "Kulak pedleri rahatsız etti", "status": "requested" }
    ]

    # --- 2. NEW DATA (ORDERS & ITEMS) ---
    
    orders = [
        {"order_id": 1, "user_id": 1, "total_amount": 1499.90, "status": "delivered", "date": "2023-09-15T14:30:00", "delivery_address": "Istanbul, TR"},
        {"order_id": 2, "user_id": 1, "total_amount": 399.80, "status": "processing", "date": "2023-11-20T09:15:00", "delivery_address": "Istanbul, TR"},
        {"order_id": 3, "user_id": 2, "total_amount": 9999.00, "status": "in_transit", "date": "2023-11-18T16:20:00", "delivery_address": "Ankara, TR"},
        {"order_id": 4, "user_id": 3, "total_amount": 3698.00, "status": "delivered", "date": "2023-08-05T11:00:00", "delivery_address": "Izmir, TR"},
        {"order_id": 5, "user_id": 3, "total_amount": 159.00, "status": "cancelled", "date": "2023-08-10T13:45:00", "delivery_address": "Izmir, TR"},
        {"order_id": 6, "user_id": 4, "total_amount": 349.00, "status": "delivered", "date": "2023-10-01T10:00:00", "delivery_address": "Bursa, TR"},
        {"order_id": 7, "user_id": 5, "total_amount": 1199.00, "status": "delivered", "date": "2023-05-20T15:30:00", "delivery_address": "Antalya, TR"},
        {"order_id": 8, "user_id": 5, "total_amount": 27999.00, "status": "processing", "date": "2023-11-21T08:45:00", "delivery_address": "Antalya, TR"},
        {"order_id": 9, "user_id": 5, "total_amount": 199.90, "status": "in_transit", "date": "2023-11-19T19:20:00", "delivery_address": "Antalya, TR"},
        {"order_id": 10, "user_id": 6, "total_amount": 3499.00, "status": "delivered", "date": "2023-07-12T12:15:00", "delivery_address": "Eskişehir, TR"},
        {"order_id": 11, "user_id": 7, "total_amount": 1798.00, "status": "processing", "date": "2023-11-22T14:10:00", "delivery_address": "Adana, TR"},
        {"order_id": 12, "user_id": 7, "total_amount": 1499.90, "status": "delivered", "date": "2023-09-25T16:50:00", "delivery_address": "Adana, TR"},
        {"order_id": 13, "user_id": 8, "total_amount": 508.00, "status": "delivered", "date": "2023-10-30T09:00:00", "delivery_address": "Samsun, TR"},
        {"order_id": 14, "user_id": 9, "total_amount": 27999.00, "status": "delivered", "date": "2023-06-15T11:30:00", "delivery_address": "Kocaeli, TR"},
        {"order_id": 15, "user_id": 9, "total_amount": 1199.00, "status": "in_transit", "date": "2023-11-18T10:20:00", "delivery_address": "Kocaeli, TR"},
        {"order_id": 16, "user_id": 10, "total_amount": 5598.00, "status": "processing", "date": "2023-11-21T15:45:00", "delivery_address": "Muğla, TR"},
        {"order_id": 17, "user_id": 10, "total_amount": 159.00, "status": "delivered", "date": "2023-08-20T14:00:00", "delivery_address": "Muğla, TR"},
    ]

    order_items = [
        {"order_item_id": 1, "order_id": 1, "product_id": 1, "quantity": 1, "unit_price": 1499.90},
        {"order_item_id": 2, "order_id": 2, "product_id": 4, "quantity": 2, "unit_price": 199.90},
        {"order_item_id": 3, "order_id": 3, "product_id": 2, "quantity": 1, "unit_price": 9999.00},
        {"order_item_id": 4, "order_id": 4, "product_id": 5, "quantity": 1, "unit_price": 2799.00},
        {"order_item_id": 5, "order_id": 4, "product_id": 6, "quantity": 1, "unit_price": 899.00},
        {"order_item_id": 6, "order_id": 5, "product_id": 10, "quantity": 1, "unit_price": 159.00},
        {"order_item_id": 7, "order_id": 6, "product_id": 9, "quantity": 1, "unit_price": 349.00},
        {"order_item_id": 8, "order_id": 7, "product_id": 7, "quantity": 1, "unit_price": 1199.00},
        {"order_item_id": 9, "order_id": 8, "product_id": 3, "quantity": 1, "unit_price": 27999.00},
        {"order_item_id": 10, "order_id": 9, "product_id": 4, "quantity": 1, "unit_price": 199.90},
        {"order_item_id": 11, "order_id": 10, "product_id": 8, "quantity": 1, "unit_price": 3499.00},
        {"order_item_id": 12, "order_id": 11, "product_id": 6, "quantity": 2, "unit_price": 899.00},
        {"order_item_id": 13, "order_id": 12, "product_id": 1, "quantity": 1, "unit_price": 1499.90},
        {"order_item_id": 14, "order_id": 13, "product_id": 9, "quantity": 1, "unit_price": 349.00},
        {"order_item_id": 15, "order_id": 13, "product_id": 10, "quantity": 1, "unit_price": 159.00},
        {"order_item_id": 16, "order_id": 14, "product_id": 3, "quantity": 1, "unit_price": 27999.00},
        {"order_item_id": 17, "order_id": 15, "product_id": 7, "quantity": 1, "unit_price": 1199.00},
        {"order_item_id": 18, "order_id": 16, "product_id": 5, "quantity": 2, "unit_price": 2799.00},
        {"order_item_id": 19, "order_id": 17, "product_id": 10, "quantity": 1, "unit_price": 159.00},
    ]

    # --- 3. UPLOAD ALL COLLECTIONS ---
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
    main()