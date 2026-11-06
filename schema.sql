-- Inventory Management System
-- PostgreSQL database schema, sample data, 2 SQL functions, 3 procedures.

DROP TABLE IF EXISTS sale_items CASCADE;
DROP TABLE IF EXISTS sales CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS categories CASCADE;

CREATE TABLE categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    category_id INT NOT NULL REFERENCES categories(category_id),
    product_name VARCHAR(150) NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
    stock_quantity INT NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    customer_name VARCHAR(150) NOT NULL,
    email VARCHAR(150) UNIQUE
);

CREATE TABLE sales (
    sale_id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(customer_id),
    sale_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) NOT NULL DEFAULT 'COMPLETED'
        CHECK (status IN ('COMPLETED', 'CANCELLED'))
);

CREATE TABLE sale_items (
    sale_item_id SERIAL PRIMARY KEY,
    sale_id INT NOT NULL REFERENCES sales(sale_id),
    product_id INT NOT NULL REFERENCES products(product_id),
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0)
);

INSERT INTO categories (category_name) VALUES
('Electronics'), ('School Supplies'), ('Accessories');

INSERT INTO products (category_id, product_name, unit_price, stock_quantity) VALUES
(1, 'USB Keyboard', 450.00, 20),
(1, 'Wireless Mouse', 350.00, 15),
(2, 'Notebook', 55.00, 100),
(3, 'USB Flash Drive 32GB', 280.00, 30);

INSERT INTO customers (customer_name, email) VALUES
('Juan Dela Cruz', 'juan@example.com'),
('Maria Santos', 'maria@example.com');

-- FUNCTION 1: Returns the current total value of one product's stock.
CREATE OR REPLACE FUNCTION get_product_stock_value(p_product_id INT)
RETURNS NUMERIC(12,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_value NUMERIC(12,2);
BEGIN
    SELECT unit_price * stock_quantity
    INTO v_value
    FROM products
    WHERE product_id = p_product_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product % does not exist', p_product_id
            USING ERRCODE = 'P0002';
    END IF;

    RETURN v_value;
END;
$$;

-- FUNCTION 2: Calculates the total of a sale using its sale items.
CREATE OR REPLACE FUNCTION calculate_sale_total(p_sale_id INT)
RETURNS NUMERIC(12,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total NUMERIC(12,2);
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sales WHERE sale_id = p_sale_id) THEN
        RAISE EXCEPTION 'Sale % does not exist', p_sale_id
            USING ERRCODE = 'P0002';
    END IF;

    SELECT COALESCE(SUM(quantity * unit_price), 0)
    INTO v_total
    FROM sale_items
    WHERE sale_id = p_sale_id;

    RETURN v_total;
END;
$$;

-- PROCEDURE 1: Creates a sale, records its item, and decreases stock.
-- The INOUT parameter returns the newly created sale_id.
CREATE OR REPLACE PROCEDURE create_sale(
    IN p_customer_id INT,
    IN p_product_id INT,
    IN p_quantity INT,
    INOUT p_sale_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock INT;
    v_price NUMERIC(12,2);
BEGIN
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RAISE EXCEPTION 'Quantity must be greater than zero';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM customers WHERE customer_id = p_customer_id) THEN
        RAISE EXCEPTION 'Customer % does not exist', p_customer_id;
    END IF;

    SELECT stock_quantity, unit_price
    INTO v_stock, v_price
    FROM products
    WHERE product_id = p_product_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product % does not exist', p_product_id;
    END IF;

    IF v_stock < p_quantity THEN
        RAISE EXCEPTION 'Insufficient stock. Available: %, requested: %', v_stock, p_quantity;
    END IF;

    INSERT INTO sales (customer_id) VALUES (p_customer_id)
    RETURNING sale_id INTO p_sale_id;

    INSERT INTO sale_items (sale_id, product_id, quantity, unit_price)
    VALUES (p_sale_id, p_product_id, p_quantity, v_price);

    UPDATE products
    SET stock_quantity = stock_quantity - p_quantity
    WHERE product_id = p_product_id;
END;
$$;

-- PROCEDURE 2: Adds stock to an existing product.
CREATE OR REPLACE PROCEDURE restock_product(
    IN p_product_id INT,
    IN p_quantity INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RAISE EXCEPTION 'Restock quantity must be greater than zero';
    END IF;

    UPDATE products
    SET stock_quantity = stock_quantity + p_quantity
    WHERE product_id = p_product_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product % does not exist', p_product_id;
    END IF;
END;
$$;

-- PROCEDURE 3: Cancels a completed sale and restores the sold quantities.
CREATE OR REPLACE PROCEDURE cancel_sale(IN p_sale_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_item RECORD;
    v_status VARCHAR(20);
BEGIN
    SELECT status INTO v_status
    FROM sales
    WHERE sale_id = p_sale_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Sale % does not exist', p_sale_id;
    END IF;

    IF v_status = 'CANCELLED' THEN
        RAISE EXCEPTION 'Sale % is already cancelled', p_sale_id;
    END IF;

    FOR v_item IN
        SELECT product_id, quantity
        FROM sale_items
        WHERE sale_id = p_sale_id
    LOOP
        UPDATE products
        SET stock_quantity = stock_quantity + v_item.quantity
        WHERE product_id = v_item.product_id;
    END LOOP;

    UPDATE sales SET status = 'CANCELLED'
    WHERE sale_id = p_sale_id;
END;
$$;
