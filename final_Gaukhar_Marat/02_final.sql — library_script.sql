-- Database: library_db
-- Schema: library

-- PART 1: SCHEMA
CREATE SCHEMA IF NOT EXISTS library;
SET search_path TO library, public;


-- PART 2: CLEAN UP PREVIOUS ROLES RUN

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'library_readonly') THEN
        DROP OWNED BY library_readonly;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'library_writer') THEN
        DROP OWNED BY library_writer;
    END IF;
END $$;

DROP ROLE IF EXISTS library_readonly;
DROP ROLE IF EXISTS library_writer;


-- PART 3: CREATE TABLES

CREATE TABLE IF NOT EXISTS branches (
    branch_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    address VARCHAR(50) NOT NULL
);

CREATE TABLE IF NOT EXISTS category (
    category_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS author (
    author_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    surname VARCHAR(50) NOT NULL,
    full_name VARCHAR(100) GENERATED ALWAYS AS (name || ' ' || surname) STORED
);

CREATE TABLE IF NOT EXISTS books (
    book_id SERIAL PRIMARY KEY,
    category_id INT NOT NULL REFERENCES category(category_id) ON DELETE RESTRICT,
    title VARCHAR(255) NOT NULL UNIQUE,
    isbn VARCHAR(13) NOT NULL UNIQUE,
    publication_year INT NOT NULL,
    description TEXT
);

CREATE TABLE IF NOT EXISTS book_author (
    book_author_id SERIAL PRIMARY KEY,
    book_id INT NOT NULL REFERENCES books(book_id) ON DELETE CASCADE,
    author_id INT NOT NULL REFERENCES author(author_id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS members (
    member_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    surname VARCHAR(50) NOT NULL,
    full_name VARCHAR(100) GENERATED ALWAYS AS (name || ' ' || surname) STORED,
    personal_id VARCHAR(12) NOT NULL UNIQUE,
    email VARCHAR(120) NOT NULL UNIQUE,
    phone VARCHAR(20),
    status VARCHAR(20) NOT NULL DEFAULT 'active'
);

CREATE TABLE IF NOT EXISTS loans (
    loan_id SERIAL PRIMARY KEY,
    book_id INT NOT NULL REFERENCES books(book_id) ON DELETE RESTRICT,
    member_id INT NOT NULL REFERENCES members(member_id) ON DELETE RESTRICT,
    branch_id INT NOT NULL REFERENCES branches(branch_id) ON DELETE RESTRICT,
    loan_date DATE NOT NULL DEFAULT CURRENT_DATE,
    return_due_date DATE NOT NULL,
    actual_return_date DATE
);

CREATE TABLE IF NOT EXISTS fines (
    fine_id SERIAL PRIMARY KEY,
    loan_id INT NOT NULL REFERENCES loans(loan_id) ON DELETE RESTRICT,
    fine_amount NUMERIC(6,2),
    fine_date DATE NOT NULL DEFAULT CURRENT_DATE,
    is_paid BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS reservation (
    reservation_id SERIAL PRIMARY KEY,
    book_id INT NOT NULL REFERENCES books(book_id) ON DELETE CASCADE,
    member_id INT NOT NULL REFERENCES members(member_id) ON DELETE CASCADE,
    reservation_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'active'
);


-- PART 4: ALTER TABLE 

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'library' AND table_name = 'members' AND column_name = 'registered_at'
    ) THEN
        ALTER TABLE members ADD COLUMN registered_at DATE NOT NULL DEFAULT CURRENT_DATE;
    END IF;
END $$;

ALTER TABLE members ALTER COLUMN phone TYPE VARCHAR(25);
ALTER TABLE reservation ALTER COLUMN status SET DEFAULT 'active';

-- PART 5: ADD CONSTRAINTS

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_loan_max_period' AND conrelid = 'loans'::regclass) THEN
        ALTER TABLE loans ADD CONSTRAINT chk_loan_max_period CHECK (return_due_date <= loan_date + INTERVAL '60 days');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_book_author' AND conrelid = 'book_author'::regclass) THEN
        ALTER TABLE book_author ADD CONSTRAINT uq_book_author UNIQUE (book_id, author_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_loan_due_date' AND conrelid = 'loans'::regclass) THEN
        ALTER TABLE loans ADD CONSTRAINT chk_loan_due_date CHECK (return_due_date > DATE '2026-01-01');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fine_amount' AND conrelid = 'fines'::regclass) THEN
        ALTER TABLE fines ADD CONSTRAINT chk_fine_amount CHECK (fine_amount >= 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_member_status' AND conrelid = 'members'::regclass) THEN
        ALTER TABLE members ADD CONSTRAINT chk_member_status CHECK (status IN ('active', 'blocked', 'inactive'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_reservation_status' AND conrelid = 'reservation'::regclass) THEN
        ALTER TABLE reservation ADD CONSTRAINT chk_reservation_status CHECK (status IN ('active', 'fulfilled', 'cancelled', 'expired'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_publication_year' AND conrelid = 'books'::regclass) THEN
        ALTER TABLE books ADD CONSTRAINT chk_publication_year CHECK (publication_year BETWEEN 1000 AND 2100);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_reservation' AND conrelid = 'reservation'::regclass) THEN
        ALTER TABLE reservation ADD CONSTRAINT uq_reservation UNIQUE (book_id, member_id, reservation_date);
    END IF;
END $$;


-- PART 6: TRUNCATE & DATA INSERT

TRUNCATE fines, reservation, loans, book_author, books, members, branches, author, category RESTART IDENTITY CASCADE;

INSERT INTO branches (name, address) VALUES
('Central Branch', 'Abay Ave 1, Almaty'),
('Bostandyk Branch', 'Timiryazev St 42, Almaty'),
('Alatau Branch', 'Raiymbek Ave 210, Almaty'),
('Medeu Branch', 'Dostyk Ave 97, Almaty'),
('Turksib Branch', 'Suyunbay Ave 333, Almaty'),
('Almaly Branch', 'Furmanov St 77, Almaty');

INSERT INTO category (name) VALUES
('Fiction'), ('Science'), ('History'), ('Biography'), ('Technology'), ('Children');

INSERT INTO author (name, surname) VALUES
('Fyodor', 'Dostoevsky'), ('Leo', 'Tolstoy'), ('George', 'Orwell'), ('Mikhail', 'Bulgakov'),
('Yuval Noah', 'Harari'), ('Robert', 'Martin'), ('Stephen', 'Hawking'), ('Dale', 'Carnegie');

INSERT INTO books (category_id, title, isbn, publication_year, description) VALUES
((SELECT category_id FROM category WHERE name = 'Fiction'), 'The Brothers Karamazov', '9785699180420', 1880, 'A novel by Fyodor Dostoevsky exploring faith, doubt, and morality'),
((SELECT category_id FROM category WHERE name = 'Fiction'), 'War and Peace', '9785170593665', 1869, 'Leo Tolstoy epic novel set during the Napoleonic Wars'),
((SELECT category_id FROM category WHERE name = 'Fiction'), '1984', '9780141036144', 1949, 'George Orwell dystopian novel about a totalitarian society'),
((SELECT category_id FROM category WHERE name = 'Fiction'), 'The Master and Margarita', '9785699677674', 1967, 'Mikhail Bulgakov satirical novel blending fantasy and Soviet reality'),
((SELECT category_id FROM category WHERE name = 'History'), 'Sapiens: A Brief History of Humankind', '9780062316097', 2011, 'Yuval Noah Harari survey of human history from Stone Age to present'),
((SELECT category_id FROM category WHERE name = 'Technology'), 'Clean Code', '9780132350884', 2008, 'Robert Martin guide to writing readable and maintainable code'),
((SELECT category_id FROM category WHERE name = 'History'), 'Homo Deus', '9781784703936', 2015, 'Yuval Noah Harari look at the future of humanity'),
((SELECT category_id FROM category WHERE name = 'Science'), 'A Brief History of Time', '9780553053401', 1988, 'Stephen Hawking introduction to cosmology and the universe'),
((SELECT category_id FROM category WHERE name = 'Biography'), 'How to Win Friends and Influence People', '9780671027032', 1936, 'Dale Carnegie classic self-help and interpersonal skills guide'),
((SELECT category_id FROM category WHERE name = 'Fiction'), 'The Idiot', '9785389074724', 1869, 'Fyodor Dostoevsky novel about a kind and naive prince in Russian society');

INSERT INTO book_author (book_id, author_id)
SELECT b.book_id, a.author_id FROM books b JOIN author a ON (b.isbn = '9785699180420' AND a.surname = 'Dostoevsky')
UNION ALL SELECT b.book_id, a.author_id FROM books b JOIN author a ON (b.isbn = '9785170593665' AND a.surname = 'Tolstoy')
UNION ALL SELECT b.book_id, a.author_id FROM books b JOIN author a ON (b.isbn = '9780141036144' AND a.surname = 'Orwell')
UNION ALL SELECT b.book_id, a.author_id FROM books b JOIN author a ON (b.isbn = '9785699677674' AND a.surname = 'Bulgakov')
UNION ALL SELECT b.book_id, a.author_id FROM books b JOIN author a ON (b.isbn = '9780062316097' AND a.surname = 'Harari')
UNION ALL SELECT b.book_id, a.author_id FROM books b JOIN author a ON (b.isbn = '9780132350884' AND a.surname = 'Martin')
UNION ALL SELECT b.book_id, a.author_id FROM books b JOIN author a ON (b.isbn = '9781784703936' AND a.surname = 'Harari')
UNION ALL SELECT b.book_id, a.author_id FROM books b JOIN author a ON (b.isbn = '9780553053401' AND a.surname = 'Hawking')
UNION ALL SELECT b.book_id, a.author_id FROM books b JOIN author a ON (b.isbn = '9780671027032' AND a.surname = 'Carnegie')
UNION ALL SELECT b.book_id, a.author_id FROM books b JOIN author a ON (b.isbn = '9785389074724' AND a.surname = 'Dostoevsky');

INSERT INTO members (name, surname, personal_id, email, phone, status) VALUES
('Elnazar', 'Amanzhan', '040112100001', 'elnazar.amanzhan@lib.kz', '+77011110001', 'active'),
('Amina', 'Kurmangazy', '040128200002', 'amina.kurmangazy@lib.kz', '+77011110002', 'active'),
('Adelia', 'Umbetalieva', '040207300003', 'adelia.umbetalieva@lib.kz', '+77011110003', 'active'),
('Alikhan', 'Salimov', '040211400004', 'alikhan.salimov@lib.kz', '+77011110004', 'active'),
('Aziza', 'Erbolatkyzy', '040224500005', 'aziza.erbolatkyzy@lib.kz', '+77011110005', 'active'),
('Anuar', 'Kuanysh', '040304600006', 'anuar.kuanysh@lib.kz', '+77011110006', 'active'),
('Nurmuhammed', 'Kuanyshkali', '040309700007', 'nurmuhammed.kuanyshkali@lib.kz', '+77011110007', 'active'),
('Karina', 'Sharonova', '040317800008', 'karina.sharonova@lib.kz', '+77011110008', 'active'),
('Atazhan', 'Gabit', '040321900009', 'atazhan.gabit@lib.kz', '+77011110009', 'active'),
('Baytemir', 'Mishelov', '040404000010', 'baytemir.mishelov@lib.kz', '+77011110010', 'active'),
('Ansar', 'Olzhagul', '040414000012', 'ansar.olzhagul@lib.kz', '+77011110012', 'active'),
('Nikolay', 'Katkalev', '040423000013', 'nikolay.katkalev@lib.kz', '+77011110013', 'active'),
('Zhansaya', 'Atlas', '040430000014', 'zhansaya.atlas@lib.kz', '+77011110014', 'active'),
('Rasul', 'Orazakhay', '040610000015', 'rasul.orazakhay@lib.kz', '+77011110015', 'active'),
('Alikzhan', 'Zholzhanov', '040612000016', 'alikzhan.zholzhanov@lib.kz', '+77011110016', 'active'),
('David', 'Basiev', '040703000017', 'david.basiev@lib.kz', '+77011110017', 'active'),
('Ilya', 'Kopytov', '040706000018', 'ilya.kopytov@gmail.com', '+77021234567', 'active'),
('Albina', 'Marat', '040807000019', 'albina.marat@lib.kz', '+77011110019', 'active'),
('Gaukhar', 'Marat', '040925000020', 'gaukhar.marat@lib.kz', '+77011110020', 'blocked'),
('Nurbol', 'Kabizhan', '041010000021', 'nurbol.kabizhan@lib.kz', '+77011110021', 'active'),
('Aydana', 'Sagyndykkyzy', '041028000022', 'aydana.sagyndykkyzy@lib.kz', '+77011110022', 'active'),
('Eren', 'Erkinbek', '041115000023', 'eren.erkinbek@lib.kz', '+77011110023', 'active'),
('Saida', 'Zhakieva', '041126000024', 'saida.zhakieva@lib.kz', '+77011110024', 'active'),
('Dias', 'Zholgali', '041207000025', 'dias.zholgali@gmail.com', '+77088901234', 'active'),
('Adylzhan', 'Bagytbek', '041216000026', 'adylzhan.bagytbek@lib.kz', '+77011110026', 'active'),
('Utezhan', 'Kayrmukhanbet', '041221000027', 'utezhan.kayrmukhanbet@lib.kz', '+77011110027', 'active');

INSERT INTO loans (book_id, member_id, branch_id, loan_date, return_due_date, actual_return_date) VALUES
((SELECT book_id FROM books WHERE isbn = '9785699180420'), (SELECT member_id FROM members WHERE email = 'elnazar.amanzhan@lib.kz'), (SELECT branch_id FROM branches WHERE name = 'Central Branch'), '2026-02-01', '2026-03-01', '2026-02-27'),
((SELECT book_id FROM books WHERE isbn = '9780141036144'), (SELECT member_id FROM members WHERE email = 'amina.kurmangazy@lib.kz'), (SELECT branch_id FROM branches WHERE name = 'Bostandyk Branch'), '2026-02-05', '2026-03-05', NULL),
((SELECT book_id FROM books WHERE isbn = '9785699677674'), (SELECT member_id FROM members WHERE email = 'adelia.umbetalieva@lib.kz'), (SELECT branch_id FROM branches WHERE name = 'Alatau Branch'), '2026-02-10', '2026-03-10', '2026-03-08'),
((SELECT book_id FROM books WHERE isbn = '9780062316097'), (SELECT member_id FROM members WHERE email = 'alikhan.salimov@lib.kz'), (SELECT branch_id FROM branches WHERE name = 'Medeu Branch'), '2026-02-15', '2026-03-15', NULL),
((SELECT book_id FROM books WHERE isbn = '9780132350884'), (SELECT member_id FROM members WHERE email = 'aziza.erbolatkyzy@lib.kz'), (SELECT branch_id FROM branches WHERE name = 'Central Branch'), '2026-02-20', '2026-03-20', '2026-03-18'),
((SELECT book_id FROM books WHERE isbn = '9785170593665'), (SELECT member_id FROM members WHERE email = 'anuar.kuanysh@lib.kz'), (SELECT branch_id FROM branches WHERE name = 'Turksib Branch'), '2026-03-01', '2026-03-31', NULL),
((SELECT book_id FROM books WHERE isbn = '9781784703936'), (SELECT member_id FROM members WHERE email = 'nurmuhammed.kuanyshkali@lib.kz'), (SELECT branch_id FROM branches WHERE name = 'Almaly Branch'), '2026-03-05', '2026-04-04', '2026-04-01'),
((SELECT book_id FROM books WHERE isbn = '9780553053401'), (SELECT member_id FROM members WHERE email = 'karina.sharonova@lib.kz'), (SELECT branch_id FROM branches WHERE name = 'Central Branch'), '2026-03-10', '2026-04-09', NULL),
((SELECT book_id FROM books WHERE isbn = '9780671027032'), (SELECT member_id FROM members WHERE email = 'baytemir.mishelov@lib.kz'), (SELECT branch_id FROM branches WHERE name = 'Bostandyk Branch'), '2026-03-15', '2026-04-14', '2026-04-10'),
((SELECT book_id FROM books WHERE isbn = '9785389074724'), (SELECT member_id FROM members WHERE email = 'nikolay.katkalev@lib.kz'), (SELECT branch_id FROM branches WHERE name = 'Medeu Branch'), '2026-03-20', '2026-04-19', NULL);

INSERT INTO fines (loan_id, fine_amount, fine_date, is_paid) VALUES
((SELECT l.loan_id FROM loans l JOIN members m ON m.member_id = l.member_id JOIN books b ON b.book_id = l.book_id WHERE m.email = 'amina.kurmangazy@lib.kz' AND b.isbn = '9780141036144'), 150.00, '2026-03-06', FALSE),
((SELECT l.loan_id FROM loans l JOIN members m ON m.member_id = l.member_id JOIN books b ON b.book_id = l.book_id WHERE m.email = 'alikhan.salimov@lib.kz' AND b.isbn = '9780062316097'), 200.00, '2026-03-16', FALSE),
((SELECT l.loan_id FROM loans l JOIN members m ON m.member_id = l.member_id JOIN books b ON b.book_id = l.book_id WHERE m.email = 'anuar.kuanysh@lib.kz' AND b.isbn = '9785170593665'), 300.00, '2026-04-01', FALSE),
((SELECT l.loan_id FROM loans l JOIN members m ON m.member_id = l.member_id JOIN books b ON b.book_id = l.book_id WHERE m.email = 'karina.sharonova@lib.kz' AND b.isbn = '9780553053401'), 250.00, '2026-04-10', FALSE),
((SELECT l.loan_id FROM loans l JOIN members m ON m.member_id = l.member_id JOIN books b ON b.book_id = l.book_id WHERE m.email = 'nikolay.katkalev@lib.kz' AND b.isbn = '9785389074724'), 180.00, '2026-04-20', FALSE),
((SELECT l.loan_id FROM loans l JOIN members m ON m.member_id = l.member_id JOIN books b ON b.book_id = l.book_id WHERE m.email = 'adelia.umbetalieva@lib.kz' AND b.isbn = '9785699677674'), 0.00, '2026-03-09', TRUE);

INSERT INTO reservation (book_id, member_id, reservation_date, status) VALUES
((SELECT book_id FROM books WHERE isbn = '9785699180420'), (SELECT member_id FROM members WHERE email = 'zhansaya.atlas@lib.kz'), '2026-03-01', 'active'),
((SELECT book_id FROM books WHERE isbn = '9780141036144'), (SELECT member_id FROM members WHERE email = 'rasul.orazakhay@lib.kz'), '2026-03-05', 'fulfilled'),
((SELECT book_id FROM books WHERE isbn = '9785170593665'), (SELECT member_id FROM members WHERE email = 'aydana.sagyndykkyzy@lib.kz'), '2026-03-10', 'active'),
((SELECT book_id FROM books WHERE isbn = '9780062316097'), (SELECT member_id FROM members WHERE email = 'eren.erkinbek@lib.kz'), '2026-03-15', 'cancelled'),
((SELECT book_id FROM books WHERE isbn = '9781784703936'), (SELECT member_id FROM members WHERE email = 'saida.zhakieva@lib.kz'), '2026-03-20', 'active'),
((SELECT book_id FROM books WHERE isbn = '9780553053401'), (SELECT member_id FROM members WHERE email = 'dias.zholgali@gmail.com'), '2026-03-25', 'expired');


-- PART 7: UPDATE & DELETE

-- apply extra note to technology books description
UPDATE books SET description = description || ' [Updated edition 2026]' WHERE category_id = (SELECT category_id FROM category WHERE name = 'Technology');

-- update fine amounts for unpaid entries based on overdue days
UPDATE fines f SET fine_amount = (SELECT GREATEST(CURRENT_DATE - l.return_due_date, 0) * 50.00 FROM loans l WHERE l.loan_id = f.loan_id) WHERE f.is_paid = FALSE;

-- demo block for handling expired reservations with safe rollback for defense
BEGIN;
SAVEPOINT delete_expired_reservations;
DELETE FROM reservation WHERE status = 'expired' AND reservation_date < CURRENT_DATE - INTERVAL '14 days' RETURNING reservation_id, member_id, book_id, reservation_date;
ROLLBACK TO SAVEPOINT delete_expired_reservations;
COMMIT;


-- PART 8: GRANT & REVOKE

CREATE ROLE library_readonly;
GRANT USAGE ON SCHEMA library TO library_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA library TO library_readonly;

CREATE ROLE library_writer;
GRANT USAGE ON SCHEMA library TO library_writer;
GRANT INSERT, UPDATE ON loans TO library_writer;
GRANT INSERT ON fines TO library_writer;
GRANT INSERT ON members TO library_writer;

-- revoke update permission to maintain history logs intact
REVOKE UPDATE ON loans FROM library_writer;