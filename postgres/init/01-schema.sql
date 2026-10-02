CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    email       VARCHAR(150) UNIQUE NOT NULL,
    created_at  TIMESTAMP DEFAULT NOW()
);

CREATE TABLE orders (
    order_id    SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customers(customer_id),
    amount      NUMERIC(10,2) NOT NULL,
    status      VARCHAR(20) DEFAULT 'PLACED',
    created_at  TIMESTAMP DEFAULT NOW()
);

INSERT INTO customers (name, email) VALUES
    ('Asha Patil',  'asha@example.com'),
    ('Rohan Mehta', 'rohan@example.com'),
    ('Sara Khan',   'sara@example.com');

INSERT INTO orders (customer_id, amount, status) VALUES
    (1, 1499.00, 'PAID'),
    (2,  250.50, 'PLACED'),
    (3,  899.99, 'SHIPPED'),
    (1,   75.00, 'PAID');