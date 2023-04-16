# ---
# jupyter:
#   jupytext:
#     formats: ipynb,py:light
#     text_representation:
#       extension: .py
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.14.5
#   kernelspec:
#     display_name: Python 3 (ipykernel)
#     language: python
#     name: python3
# ---

from faker import Faker
from faker_vehicle import VehicleProvider
import psycopg2
import random


# +
def insert_brand(brand_name):
    try:
        query = f"INSERT INTO brand (name) VALUES ('{brand_name}') RETURNING brand_id;"
        cur.execute(query)
        conn.commit()
        return cur.fetchone()[0]
    except Exception as e:
        print(f"Error inserting city: {e}")
        cur.execute("ROLLBACK")

def insert_car(brand_id, model, year, tipe_mobil, body_type, price):
    try:
        query = f"INSERT INTO cars (brand_id, name, year, tipe_mobil, body_type, price) VALUES ({brand_id}, '{model}', {year}, '{tipe_mobil}', '{body_type}', {price});"
        cur.execute(query)
        conn.commit()
    except Exception as e:
        print(f"Error inserting city: {e}")
        cur.execute("ROLLBACK")
    
def insert_city(city, latitude, longitude):
    try:
        query = f"INSERT INTO city (nama_kota, latitude, longitude) VALUES ('{city}', {latitude}, {longitude});"
        cur.execute(query)
        conn.commit()
    except Exception as e:
        print(f"Error inserting city: {e}")
        cur.execute("ROLLBACK")
        
def insert_user(city_id, name, contact):
    try:
        query = f"INSERT INTO users (name, kontak, city_id) VALUES ('{name}', '{contact}', {city_id});"
        cur.execute(query)
        conn.commit()
    except Exception as e:
        print(f"Error inserting users: {e}")
        cur.execute("ROLLBACK")
        
def insert_ads(owner_id, car_id, jarak_tempuh, enable_bid):
    try:
        query = f"INSERT INTO ads (owner_id, car_id, jarak_tempuh, enable_bid) VALUES ({owner_id}, {car_id}, {jarak_tempuh}, {enable_bid});"
        cur.execute(query)
        conn.commit()
    except Exception as e:
        print(f"Error inserting ads: {e}")
        cur.execute("ROLLBACK")

def insert_bid(buyer_id, ads_id, bid_price):
    try:
        query = f"INSERT INTO bids (buyer_id, ads_id, bid_price) VALUES ({buyer_id}, {ads_id}, {bid_price});"
        cur.execute(query)
        conn.commit()
    except Exception as e:
        print(f"Error inserting bids: {e}")
        cur.execute("ROLLBACK")
        
def get_random_id_from_table(cursor, table_name, id):
    query = f"SELECT {id} FROM {table_name} ORDER BY RANDOM() LIMIT 1;"
    cursor.execute(query)
    return cursor.fetchone()[0]

def find_random_id_negotiable_ads(cursor):
    query = f"SELECT ad_id FROM ads WHERE enable_bid = true ORDER BY RANDOM() LIMIT 1;"
    cursor.execute(query)
    return cursor.fetchone()[0]


# +
conn_params = {
    'host': 'localhost',
    'port': '5432',
    'database': 'olx',
    'user': 'postgres',
    'password': ''
}

# Connect to the database
conn = psycopg2.connect(**conn_params)

# Create a cursor object
cur = conn.cursor()

# Set the search_path to include the my_schema schema
cur.execute("SET search_path TO my_schema, public")
# -

fake = Faker('id_ID')

# +
fake.add_provider(VehicleProvider)

# Generate and insert data
num_brands = 10
num_cars_per_brand = 5

for _ in range(num_brands):
    brand_name = fake.vehicle_make()
    brand_id = insert_brand(brand_name)

    for _ in range(num_cars_per_brand):
        car_model = fake.vehicle_make_model()
        car_year = fake.year()
        car_tipe = random.choice(['AT', 'MT'])
        car_body = fake.vehicle_category()
        price = round(random.uniform(50, 500)) * 1000000
        insert_car(brand_id, car_model, car_year, car_tipe, car_body, price)

# +
cities = [fake.city() for _ in range(100)]
cities = list(set(cities))

for city in cities:
    insert_city(city, fake.latitude(), fake.longitude())

# +
total_users = 100

for _ in range(total_users):
    city_id = get_random_id_from_table(cur, 'city', 'city_id')
    name = fake.name_nonbinary()
    contact = fake.phone_number()
    insert_user(city_id, name, contact)

# +
total_ads = 200

for _ in range(total_ads):
    owner_id = get_random_id_from_table(cur, 'users', 'user_id')
    car_id = get_random_id_from_table(cur, 'cars', 'car_id')
    jarak_tempuh = random.randint(1000, 500000)
    enable_bid = random.choice([True, False])
    insert_ads(owner_id, car_id, jarak_tempuh, enable_bid)

# +
total_bid = 200

for _ in range(total_bid):
    ads_id = find_random_id_negotiable_ads(cur)
    buyer_id = get_random_id_from_table(cur, 'users', 'user_id')
    bid_price = price = round(random.uniform(50, 500)) * 1000000
    insert_bid(buyer_id, ads_id, bid_price)
# -

cur.close()
conn.close()
