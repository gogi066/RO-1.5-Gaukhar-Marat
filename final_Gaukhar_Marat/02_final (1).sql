-- ============================================================
-- Database: ecommerce_db
-- Schema: shop
-- pgAdmin: Query Tool на базе ecommerce_db → вставить ВЕСЬ файл → F5
-- Проверка: SELECT * FROM shop.orders;
-- Rerunnable: CREATE IF NOT EXISTS + idempotent ALTER + TRUNCATE
-- ============================================================

-- ===== PART 1: SCHEMA =====

create schema if not exists shop;


-- ===== PART 2: CREATE =====

create table if not exists shop.customer (
    customer_id   serial primary key,
    first_name    varchar(100) not null,
    last_name     varchar(100) not null,
    middle_name   varchar(100),
    email         varchar(255) not null,
    phone         varchar(15),
    created_at    timestamp not null default current_timestamp
);

create table if not exists shop.address (
    address_id    serial primary key,
    customer_id   int not null references shop.customer (customer_id) on delete cascade,
    country       varchar(100) not null,
    city          varchar(100) not null,
    street        varchar(255) not null,
    postal_code   varchar(20) not null
);

create table if not exists shop.category (
    category_id   serial primary key,
    name          varchar(100) not null unique,
    description   text
);

create table if not exists shop.product (
    product_id        serial primary key,
    category_id       int references shop.category (category_id) on delete set null,
    name              varchar(200) not null,
    sku               varchar(50) not null unique,
    price             numeric(10, 2) not null check (price >= 0),
    discount_amount   numeric(10, 2) not null default 0.00 check (discount_amount >= 0),
    final_price       numeric(10, 2) generated always as (price - discount_amount) stored,
    stock_quantity    int not null default 0 check (stock_quantity >= 0)
);

create table if not exists shop.orders (
    order_id              serial primary key,
    customer_id           int not null references shop.customer (customer_id) on delete restrict,
    shipping_address_id   int references shop.address (address_id) on delete set null,
    order_date            timestamp not null check (order_date > timestamp '2026-01-01 00:00:00'),
    status                varchar(20) not null default 'Pending'
        check (status in ('Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled'))
);

create table if not exists shop.order_item (
    order_item_id   serial primary key,
    order_id        int not null references shop.orders (order_id) on delete cascade,
    product_id      int not null references shop.product (product_id) on delete restrict,
    quantity        int not null check (quantity > 0),
    price_per_item  numeric(10, 2) not null check (price_per_item >= 0),
    line_total      numeric(10, 2) generated always as (quantity * price_per_item) stored
);

create table if not exists shop.payment (
    payment_id      serial primary key,
    order_id        int not null references shop.orders (order_id) on delete restrict,
    payment_date    timestamp not null check (payment_date > timestamp '2026-01-01 00:00:00'),
    amount          numeric(10, 2) not null check (amount > 0),
    payment_method  varchar(30) not null
        check (payment_method in ('card', 'paypal', 'bank_transfer', 'cash_on_delivery')),
    status          varchar(20) not null
        check (status in ('pending', 'completed', 'failed', 'refunded'))
);


-- ===== PART 3: ALTER TABLE (idempotent for reruns) =====

alter table shop.customer alter column phone type varchar(20);

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where conname = 'uq_customer_email'
          and conrelid = 'shop.customer'::regclass
    ) then
        alter table shop.customer add constraint uq_customer_email unique (email);
    end if;
end $$;

do $$
begin
    if exists (
        select 1 from information_schema.columns
        where table_schema = 'shop'
          and table_name = 'customer'
          and column_name = 'middle_name'
    ) then
        alter table shop.customer drop column middle_name;
    end if;
end $$;

alter table shop.address alter column postal_code type varchar(30);

alter table shop.payment alter column status set default 'pending';

alter table shop.orders add column if not exists tracking_number varchar(50);


-- ===== PART 4: INSERT =====

truncate shop.payment, shop.order_item, shop.orders, shop.product,
         shop.category, shop.address, shop.customer restart identity cascade;

insert into shop.customer (first_name, last_name, email, phone, created_at)
values
    ('Amanzhan', 'Elnazar', 'amanzhan.elnazar@mail.kz', '+77011234567', '2026-02-10 09:15:00'),
    ('Atlas', 'Zhansaya', 'a.zhansaya@example.kz', '+77022345678', '2026-02-11 11:30:00'),
    ('Bagytzhan', 'Edilzhan', 'bagytzhan.edilzhan@gmail.com', '+77033456789', '2026-02-12 14:00:00'),
    ('David', 'Basiev', 'david.basiev@mail.kz', '+77044567890', '2026-02-13 08:45:00'),
    ('Aziza', 'Erbolatkyzy', 'aziza.erbolatkyzy@outlook.com', '+77055678901', '2026-02-14 16:20:00'),
    ('Erkinbek', 'Eren', 'e.eren@example.kz', '+77066789012', '2026-02-15 10:05:00'),
    ('Saida', 'Zhakieva', 'saida.zhakieva@mail.kz', '+77077890123', '2026-02-16 13:40:00'),
    ('Dias', 'Zholgali', 'd.zholgali@gmail.com', '+77088901234', '2026-02-17 09:55:00'),
    ('Alizhan', 'Zholzhanov', 'a.zholzhanov@example.kz', '+77099012345', '2026-02-18 15:10:00'),
    ('Nikolai', 'Katkalov', 'nikolai.katkalov@mail.kz', '+77010123456', '2026-02-19 12:25:00'),
    ('Ilya', 'Kopytov', 'ilya.kopytov@gmail.com', '+77021234567', '2026-02-20 17:50:00'),
    ('Nurbol', 'Kabezhan', 'n.kabezhan@example.kz', '+77032345678', '2026-02-21 08:30:00');

insert into shop.address (customer_id, country, city, street, postal_code)
values
    ((select customer_id from shop.customer where email = 'amanzhan.elnazar@mail.kz'), 'Kazakhstan', 'Atyrau', 'Abay Avenue 150', '06000'),
    ((select customer_id from shop.customer where email = 'amanzhan.elnazar@mail.kz'), 'Kazakhstan', 'Atyrau', 'Dostyk Street 89', '06000'),
    ((select customer_id from shop.customer where email = 'a.zhansaya@example.kz'), 'Kazakhstan', 'Atyrau', 'Kabanbay Batyr 42', '06000'),
    ((select customer_id from shop.customer where email = 'bagytzhan.edilzhan@gmail.com'), 'Kazakhstan', 'Atyrau', 'Tauke Khan 17', '06000'),
    ((select customer_id from shop.customer where email = 'david.basiev@mail.kz'), 'Kazakhstan', 'Atyrau', 'Bukhar Zhyrau 55', '06000'),
    ((select customer_id from shop.customer where email = 'aziza.erbolatkyzy@outlook.com'), 'Kazakhstan', 'Atyrau', 'Satpayev Street 90', '06000'),
    ((select customer_id from shop.customer where email = 'e.eren@example.kz'), 'Kazakhstan', 'Atyrau', 'Turkestan 12', '06000'),
    ((select customer_id from shop.customer where email = 'saida.zhakieva@mail.kz'), 'Kazakhstan', 'Atyrau', 'Abulkhair Khan 33', '06000'),
    ((select customer_id from shop.customer where email = 'd.zholgali@gmail.com'), 'Kazakhstan', 'Atyrau', 'Lomov Street 7', '06000'),
    ((select customer_id from shop.customer where email = 'a.zholzhanov@example.kz'), 'Kazakhstan', 'Atyrau', 'Rozybakiev 120', '06000'),
    ((select customer_id from shop.customer where email = 'nikolai.katkalov@mail.kz'), 'Kazakhstan', 'Atyrau', 'Kenesary 88', '06000'),
    ((select customer_id from shop.customer where email = 'ilya.kopytov@gmail.com'), 'Kazakhstan', 'Atyrau', 'Gogol Street 45', '06000'),
    ((select customer_id from shop.customer where email = 'n.kabezhan@example.kz'), 'Kazakhstan', 'Atyrau', 'Furmanov Street 72', '06000');

insert into shop.category (name, description)
values
    ('Electronics', 'Smartphones, laptops, and accessories'),
    ('Clothing', 'Men and women apparel'),
    ('Home and Kitchen', 'Cookware, decor, and appliances'),
    ('Books', 'Fiction, non-fiction, and textbooks'),
    ('Sports', 'Fitness gear and outdoor equipment'),
    ('Beauty', 'Skincare, makeup, and personal care');

insert into shop.product (category_id, name, sku, price, discount_amount, stock_quantity)
values
    ((select category_id from shop.category where name = 'Electronics'), 'Samsung Galaxy S26', 'ELEC-SAM-S26', 549999.00, 25000.00, 45),
    ((select category_id from shop.category where name = 'Electronics'), 'Apple MacBook Air M4', 'ELEC-APL-MBA4', 699999.00, 0.00, 20),
    ((select category_id from shop.category where name = 'Electronics'), 'Sony WH-1000XM6 Headphones', 'ELEC-SNY-XM6', 189999.00, 15000.00, 60),
    ((select category_id from shop.category where name = 'Clothing'), 'Merino Wool Sweater', 'CLT-MER-SW01', 45999.00, 5000.00, 120),
    ((select category_id from shop.category where name = 'Clothing'), 'Denim Jacket Classic', 'CLT-DNM-JK02', 32999.00, 0.00, 85),
    ((select category_id from shop.category where name = 'Home and Kitchen'), 'Ceramic Cookware Set 12pc', 'HOM-CKW-12PC', 74999.00, 8000.00, 35),
    ((select category_id from shop.category where name = 'Home and Kitchen'), 'Robot Vacuum Cleaner', 'HOM-RVC-PRO', 159999.00, 20000.00, 28),
    ((select category_id from shop.category where name = 'Books'), 'Clean Code 2nd Edition', 'BK-CC-2ED', 12999.00, 0.00, 200),
    ((select category_id from shop.category where name = 'Books'), 'Database Internals', 'BK-DB-INT', 14999.00, 2000.00, 75),
    ((select category_id from shop.category where name = 'Sports'), 'Yoga Mat Premium', 'SPT-YGA-MAT', 8999.00, 1000.00, 150),
    ((select category_id from shop.category where name = 'Sports'), 'Adjustable Dumbbell Set 24kg', 'SPT-DB-24KG', 54999.00, 0.00, 40),
    ((select category_id from shop.category where name = 'Beauty'), 'Hydrating Face Serum 30ml', 'BTY-SRM-30ML', 11999.00, 1500.00, 90);

insert into shop.orders (customer_id, shipping_address_id, order_date, status)
values
    ((select customer_id from shop.customer where email = 'amanzhan.elnazar@mail.kz'), (select address_id from shop.address where street = 'Abay Avenue 150'), '2026-03-01 10:30:00', 'Delivered'),
    ((select customer_id from shop.customer where email = 'a.zhansaya@example.kz'), (select address_id from shop.address where street = 'Kabanbay Batyr 42'), '2026-03-02 14:15:00', 'Shipped'),
    ((select customer_id from shop.customer where email = 'bagytzhan.edilzhan@gmail.com'), (select address_id from shop.address where street = 'Tauke Khan 17'), '2026-03-03 09:00:00', 'Processing'),
    ((select customer_id from shop.customer where email = 'david.basiev@mail.kz'), (select address_id from shop.address where street = 'Bukhar Zhyrau 55'), '2026-03-04 16:45:00', 'Pending'),
    ((select customer_id from shop.customer where email = 'aziza.erbolatkyzy@outlook.com'), (select address_id from shop.address where street = 'Satpayev Street 90'), '2026-03-05 11:20:00', 'Delivered'),
    ((select customer_id from shop.customer where email = 'e.eren@example.kz'), (select address_id from shop.address where street = 'Turkestan 12'), '2026-03-06 08:50:00', 'Cancelled'),
    ((select customer_id from shop.customer where email = 'saida.zhakieva@mail.kz'), (select address_id from shop.address where street = 'Abulkhair Khan 33'), '2026-03-07 13:10:00', 'Shipped'),
    ((select customer_id from shop.customer where email = 'd.zholgali@gmail.com'), (select address_id from shop.address where street = 'Lomov Street 7'), '2026-03-08 17:30:00', 'Delivered'),
    ((select customer_id from shop.customer where email = 'a.zholzhanov@example.kz'), (select address_id from shop.address where street = 'Rozybakiev 120'), '2026-03-09 10:05:00', 'Processing'),
    ((select customer_id from shop.customer where email = 'nikolai.katkalov@mail.kz'), (select address_id from shop.address where street = 'Kenesary 88'), '2026-03-10 15:40:00', 'Pending'),
    ((select customer_id from shop.customer where email = 'ilya.kopytov@gmail.com'), (select address_id from shop.address where street = 'Gogol Street 45'), '2026-02-15 12:00:00', 'Cancelled'),
    ((select customer_id from shop.customer where email = 'n.kabezhan@example.kz'), (select address_id from shop.address where street = 'Furmanov Street 72'), '2026-03-11 09:25:00', 'Delivered');

insert into shop.order_item (order_id, product_id, quantity, price_per_item)
values
    ((select o.order_id from shop.orders o join shop.customer c on o.customer_id = c.customer_id where c.email = 'amanzhan.elnazar@mail.kz' and o.order_date = '2026-03-01 10:30:00'), (select product_id from shop.product where sku = 'ELEC-SAM-S26'), 1, 524999.00),
    ((select o.order_id from shop.orders o join shop.customer c on o.customer_id = c.customer_id where c.email = 'amanzhan.elnazar@mail.kz' and o.order_date = '2026-03-01 10:30:00'), (select product_id from shop.product where sku = 'ELEC-SNY-XM6'), 1, 174999.00),
    ((select o.order_id from shop.orders o join shop.customer c on o.customer_id = c.customer_id where c.email = 'a.zhansaya@example.kz' and o.order_date = '2026-03-02 14:15:00'), (select product_id from shop.product where sku = 'ELEC-APL-MBA4'), 1, 699999.00),
    ((select o.order_id from shop.orders o join shop.customer c on o.customer_id = c.customer_id where c.email = 'bagytzhan.edilzhan@gmail.com' and o.order_date = '2026-03-03 09:00:00'), (select product_id from shop.product where sku = 'CLT-MER-SW01'), 2, 40999.00),
    ((select o.order_id from shop.orders o join shop.customer c on o.customer_id = c.customer_id where c.email = 'david.basiev@mail.kz' and o.order_date = '2026-03-04 16:45:00'), (select product_id from shop.product where sku = 'BK-CC-2ED'), 1, 12999.00),
    ((select o.order_id from shop.orders o join shop.customer c on o.customer_id = c.customer_id where c.email = 'aziza.erbolatkyzy@outlook.com' and o.order_date = '2026-03-05 11:20:00'), (select product_id from shop.product where sku = 'HOM-RVC-PRO'), 1, 139999.00),
    ((select o.order_id from shop.orders o join shop.customer c on o.customer_id = c.customer_id where c.email = 'saida.zhakieva@mail.kz' and o.order_date = '2026-03-07 13:10:00'), (select product_id from shop.product where sku = 'SPT-YGA-MAT'), 3, 7999.00),
    ((select o.order_id from shop.orders o join shop.customer c on o.customer_id = c.customer_id where c.email = 'd.zholgali@gmail.com' and o.order_date = '2026-03-08 17:30:00'), (select product_id from shop.product where sku = 'SPT-DB-24KG'), 1, 54999.00),
    ((select o.order_id from shop.orders o join shop.customer c on o.customer_id = c.customer_id where c.email = 'a.zholzhanov@example.kz' and o.order_date = '2026-03-09 10:05:00'), (select product_id from shop.product where sku = 'BTY-SRM-30ML'), 2, 10499.00),
    ((select o.order_id from shop.orders o join shop.customer c on o.customer_id = c.customer_id where c.email = 'nikolai.katkalov@mail.kz' and o.order_date = '2026-03-10 15:40:00'), (select product_id from shop.product where sku = 'CLT-DNM-JK02'), 1, 32999.00),
    ((select o.order_id from shop.orders o join shop.customer c on o.customer_id = c.customer_id where c.email = 'ilya.kopytov@gmail.com' and o.order_date = '2026-02-15 12:00:00'), (select product_id from shop.product where sku = 'HOM-CKW-12PC'), 1, 66999.00),
    ((select o.order_id from shop.orders o join shop.customer c on o.customer_id = c.customer_id where c.email = 'n.kabezhan@example.kz' and o.order_date = '2026-03-11 09:25:00'), (select product_id from shop.product where sku = 'BK-DB-INT'), 1, 12999.00);

insert into shop.order_item (order_id, product_id, quantity, price_per_item)
select o.order_id, p.product_id, 1, p.final_price
from shop.orders o
join shop.customer c on o.customer_id = c.customer_id
cross join shop.product p
where c.email = 'a.zhansaya@example.kz'
  and o.order_date = '2026-03-02 14:15:00'
  and p.sku = 'BK-DB-INT';

insert into shop.payment (order_id, payment_date, amount, payment_method, status)
values
    ((select o.order_id from shop.orders o join shop.customer c on o.customer_id = c.customer_id where c.email = 'amanzhan.elnazar@mail.kz' and o.order_date = '2026-03-01 10:30:00'), '2026-03-01 10:35:00', 699998.00, 'card', 'completed'),
    ((select o.order_id from shop.orders o join shop.customer c on o.customer_id = c.customer_id where c.email = 'a.zhansaya@example.kz' and o.order_date = '2026-03-02 14:15:00'), '2026-03-02 14:20:00', 712998.00, 'paypal', 'completed'),
    ((select o.order_id from shop.orders o join shop.customer c on o.customer_id = c.customer_id where c.email = 'bagytzhan.edilzhan@gmail.com' and o.order_date = '2026-03-03 09:00:00'), '2026-03-03 09:05:00', 81998.00, 'card', 'completed'),
    ((select o.order_id from shop.orders o join shop.customer c on o.customer_id = c.customer_id where c.email = 'aziza.erbolatkyzy@outlook.com' and o.order_date = '2026-03-05 11:20:00'), '2026-03-05 11:25:00', 139999.00, 'bank_transfer', 'completed'),
    ((select o.order_id from shop.orders o join shop.customer c on o.customer_id = c.customer_id where c.email = 'e.eren@example.kz' and o.order_date = '2026-03-06 08:50:00'), '2026-03-06 08:55:00', 32999.00, 'card', 'failed'),
    ((select o.order_id from shop.orders o join shop.customer c on o.customer_id = c.customer_id where c.email = 'saida.zhakieva@mail.kz' and o.order_date = '2026-03-07 13:10:00'), '2026-03-07 13:15:00', 23997.00, 'card', 'completed'),
    ((select o.order_id from shop.orders o join shop.customer c on o.customer_id = c.customer_id where c.email = 'd.zholgali@gmail.com' and o.order_date = '2026-03-08 17:30:00'), '2026-03-08 17:35:00', 54999.00, 'cash_on_delivery', 'completed'),
    ((select o.order_id from shop.orders o join shop.customer c on o.customer_id = c.customer_id where c.email = 'a.zholzhanov@example.kz' and o.order_date = '2026-03-09 10:05:00'), '2026-03-09 10:10:00', 20998.00, 'card', 'pending');


-- ===== PART 5: UPDATE + DELETE =====

-- apply 10% extra discount to all Electronics category products for a spring sale
update shop.product
set discount_amount = discount_amount + (price * 0.10)
where category_id = (select category_id from shop.category where name = 'Electronics')
  and discount_amount < price * 0.11;

-- mark orders as Delivered when payment completed successfully
update shop.orders o
set status = 'Delivered'
from shop.payment p
where o.order_id = p.order_id
  and p.status = 'completed'
  and o.status = 'Shipped';

-- remove cancelled orders older than 30 days (rolled back to keep data for defense)
begin;
savepoint delete_cancelled_orders;
delete from shop.orders
where status = 'Cancelled'
  and order_date < timestamp '2026-03-01 00:00:00'
returning order_id, order_date, status;
rollback to savepoint delete_cancelled_orders;
commit;


-- ===== PART 6: GRANT + REVOKE =====

-- clean up previous run: roles keep grants until revoked
do $$
begin
    if exists (select 1 from pg_roles where rolname = 'ecommerce_readonly') then
        drop owned by ecommerce_readonly;
    end if;
    if exists (select 1 from pg_roles where rolname = 'ecommerce_writer') then
        drop owned by ecommerce_writer;
    end if;
end $$;

drop role if exists ecommerce_readonly;
drop role if exists ecommerce_writer;

create role ecommerce_readonly;
grant usage on schema shop to ecommerce_readonly;
grant select on all tables in schema shop to ecommerce_readonly;

create role ecommerce_writer;
grant usage on schema shop to ecommerce_writer;
grant insert, update on shop.orders to ecommerce_writer;
-- revoke update: warehouse clerks create orders but must not alter history
revoke update on shop.orders from ecommerce_writer;