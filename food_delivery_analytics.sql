CREATE TABLE users (
    id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    gender VARCHAR(10),
    ip_address VARCHAR(50)
);

ALTER TABLE users
ALTER COLUMN gender TYPE VARCHAR(20);

-- RESTAURANTS table
CREATE TABLE restaurants (
    restaurant_id INT PRIMARY KEY,
    name VARCHAR(100),
    city VARCHAR(100),
    cuisine_type VARCHAR(50),
    rating DECIMAL(2,1)
);

-- MENU table
CREATE TABLE menu (
    item_id INT PRIMARY KEY,
    restaurant_id INT,
    item_name VARCHAR(100),
    category VARCHAR(50),
    price DECIMAL(10,2),
    FOREIGN KEY (restaurant_id) REFERENCES restaurants(restaurant_id)
);

-- ORDERS table
CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    user_id INT,
    restaurant_id INT,
    order_date DATE,
    total_amount DECIMAL(10,2),
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (restaurant_id) REFERENCES restaurants(restaurant_id)
);


SET DateStyle= 'MDY';

-- ORDER_ITEMS table
CREATE TABLE order_items (
    order_item_id INT PRIMARY KEY,
    order_id INT,
    item_id INT,
    quantity INT,
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (item_id) REFERENCES menu(item_id)
);

-- RATINGS table
CREATE TABLE ratings (
    rating_id INT PRIMARY KEY,
    user_id INT,
    restaurant_id INT,
    rating DECIMAL(2,1),
    review TEXT,
    date DATE,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (restaurant_id) REFERENCES restaurants(restaurant_id)
);

SELECT * FROM users;
SELECT * FROM menu;
SELECT * FROM ratings;
SELECT * FROM restaurants;
SELECT * FROM order_items;
SELECT * FROM orders;

-- ==================================================
-- ANALYSIS QUERIES FOR FOOD DELIVERY PLATFORM
-- ==================================================

-- ====================================
-- USER ANALYTICS
-- ====================================

-- 1. Number of users by gender
SELECT gender, COUNT(gender) AS counted_gender
FROM users
GROUP BY gender
ORDER BY counted_gender DESC;

-- 2. Users who have submitted a rating but never placed an order
SELECT DISTINCT r.user_id
FROM ratings r
WHERE r.user_id NOT IN (SELECT user_id FROM orders);

-- OR (Alternative)
SELECT DISTINCT r.user_id
FROM ratings r
LEFT JOIN orders o ON r.user_id = o.user_id
WHERE o.user_id IS NULL;

-- 3. Users who have placed more than 5 orders
SELECT COUNT(order_id) AS total_orders, user_id
FROM orders
GROUP BY user_id
HAVING COUNT(order_id) > 5;

-- 4. Users who ordered from more than 1 unique restaurant
SELECT user_id, COUNT(DISTINCT restaurant_id) AS unique_restaurants
FROM orders
GROUP BY user_id
HAVING COUNT(DISTINCT restaurant_id) > 1;

-- 5. Users who have never rated but placed at least one order
SELECT DISTINCT(u.first_name)
FROM users u
JOIN orders o ON u.id = o.user_id
WHERE u.id NOT IN (SELECT user_id FROM ratings);

-- OR
SELECT u.first_name
FROM users u
WHERE u.id IN (
    SELECT DISTINCT user_id FROM orders
    EXCEPT
    SELECT DISTINCT user_id FROM ratings
);

-- 6. Top 5 users who spent the most money
SELECT 
    u.id AS user_id,
    u.first_name,
    SUM(o.total_amount) AS spent_money,
    COUNT(o.order_id) AS number_of_orders
FROM orders o
JOIN users u ON o.user_id = u.id
GROUP BY u.id, u.first_name
ORDER BY spent_money DESC
LIMIT 5;

-- 7. Users who have rated the most restaurants
SELECT user_id, COUNT(DISTINCT restaurant_id) AS number_of_restaurants_rated 
FROM ratings 
GROUP BY user_id 
ORDER BY number_of_restaurants_rated DESC
LIMIT 5;

-- 8. Top 5 users with highest average rating (min. 3 restaurants rated)
SELECT u.first_name, AVG(r.rating) AS average_rating, COUNT(DISTINCT(r.restaurant_id))
FROM users u
JOIN ratings r ON u.id = r.user_id
GROUP BY r.user_id, u.first_name
HAVING COUNT(DISTINCT r.restaurant_id) >= 3
ORDER BY average_rating DESC
LIMIT 5;

-- 9. Average number of items per order for each user (Top 5)
SELECT 
    u.first_name,
    SUM(oi.quantity) AS total_items_ordered,
    COUNT(DISTINCT(o.order_id)) AS orders_placed,
    ROUND(1.0 * SUM(oi.quantity) / COUNT(DISTINCT o.order_id), 2) AS avg_items_per_order
FROM users u
JOIN orders o ON u.id = o.user_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY u.id, u.first_name
ORDER BY avg_items_per_order DESC
LIMIT 5;

-- 10. Users who ordered from more than 3 different restaurants
SELECT u.first_name, COUNT(DISTINCT o.restaurant_id) AS restaurant_count
FROM users u
JOIN orders o ON u.id = o.user_id
GROUP BY o.user_id, u.first_name
HAVING COUNT(DISTINCT o.restaurant_id) > 3;

-- 11. Top 3 users with most orders in a single month
SELECT 
    CONCAT(u.first_name, ' ', u.last_name) AS user_name,
    EXTRACT(YEAR FROM o.order_date) AS year,
    TO_CHAR(o.order_date, 'Month') AS month,
    COUNT(o.order_id) AS total_orders
FROM users u
JOIN orders o ON u.id = o.user_id
GROUP BY u.id, u.first_name, u.last_name, EXTRACT(YEAR FROM o.order_date), TO_CHAR(o.order_date, 'Month')
ORDER BY total_orders DESC
LIMIT 3;

-- 12. User who ordered from max number of different cuisines
SELECT 
    CONCAT(u.first_name, ' ', u.last_name) AS user_name,
    COUNT(DISTINCT r.cuisine_type) AS distinct_cuisines_count
FROM users u
JOIN orders o ON u.id = o.user_id
JOIN restaurants r ON o.restaurant_id = r.restaurant_id
GROUP BY u.id, u.first_name, u.last_name
ORDER BY distinct_cuisines_count DESC
LIMIT 1;


-- ====================================
-- RESTAURANT ANALYTICS
-- ====================================

-- 1. Top 5 restaurants by average rating
SELECT restaurant_id, AVG(rating) AS avg_rating
FROM ratings
GROUP BY restaurant_id
ORDER BY avg_rating DESC
LIMIT 5;

-- 2. Top 5 restaurants by total sales
SELECT r.name, SUM(o.total_amount) AS total_sales
FROM restaurants r
JOIN orders o ON r.restaurant_id = o.restaurant_id
GROUP BY r.name
ORDER BY total_sales DESC
LIMIT 5;

-- 3. Restaurant with most reviews
SELECT r.restaurant_id, r.name, COUNT(rt.review) AS number_of_reviews 
FROM ratings rt
JOIN restaurants r ON rt.restaurant_id = r.restaurant_id
GROUP BY r.restaurant_id, r.name 
ORDER BY number_of_reviews DESC
LIMIT 1;

-- 4. Restaurant with highest average rating for each cuisine
WITH cuisine_ranks AS (
    SELECT 
        r.cuisine_type,
        r.name AS restaurant_name,
        ROUND(AVG(rt.rating), 2) AS average_rating,
        DENSE_RANK() OVER (PARTITION BY r.cuisine_type ORDER BY AVG(rt.rating) DESC) AS rank
    FROM restaurants r
    JOIN ratings rt ON r.restaurant_id = rt.restaurant_id
    GROUP BY r.cuisine_type, r.name
)
SELECT cuisine_type, restaurant_name, average_rating
FROM cuisine_ranks
WHERE rank = 1;

-- 5. Restaurant with highest average number of items per order
SELECT r.name, 
    COUNT(DISTINCT o.order_id) AS total_orders, 
    ROUND(SUM(oi.quantity) * 1.0 / COUNT(DISTINCT o.order_id), 2) AS avg_items_per_order
FROM restaurants r
JOIN orders o ON r.restaurant_id = o.restaurant_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY r.restaurant_id, r.name
ORDER BY avg_items_per_order DESC
LIMIT 1;

-- 6. Restaurant with highest average order value (min 10 orders)
SELECT r.name, 
    COUNT(o.order_id) AS no_of_orders, 
    ROUND(SUM(o.total_amount) * 1.0 / COUNT(o.order_id), 2) AS average_order_value
FROM restaurants r
JOIN orders o ON r.restaurant_id = o.restaurant_id
GROUP BY o.restaurant_id, r.name
HAVING COUNT(o.order_id) >= 10
ORDER BY average_order_value DESC
LIMIT 1;


-- ====================================
-- MENU INSIGHTS
-- ====================================

-- 1. Top 5 most ordered items (by quantity)
SELECT m.item_name, SUM(o.quantity) AS total_quantity_ordered
FROM order_items o
JOIN menu m ON o.item_id = m.item_id
GROUP BY m.item_name
ORDER BY total_quantity_ordered DESC
LIMIT 5;

-- 2. Top 5 menu items by revenue
SELECT m.item_name, 
    SUM(o.quantity * m.price) AS total_revenue
FROM menu m
JOIN order_items o ON m.item_id = o.item_id
GROUP BY m.item_name
ORDER BY total_revenue DESC
LIMIT 5;

-- 3. Most profitable item
SELECT m.item_name, 
    SUM(m.price * o.quantity) AS total_revenue, 
    SUM(o.quantity) AS total_quantity_sold
FROM menu m
JOIN order_items o ON m.item_id = o.item_id
GROUP BY o.item_id, m.item_name
ORDER BY total_revenue DESC
LIMIT 1;

-- 4. Top 3 most frequently ordered items
SELECT m.item_name, 
    SUM(o.quantity) AS total_order_count,
    COUNT(o.item_id) AS frequency_of_orders 
FROM menu m
JOIN order_items o ON m.item_id = o.item_id
GROUP BY m.item_name
ORDER BY total_order_count DESC
LIMIT 3;


-- ====================================
-- REVENUE & TREND ANALYSIS
-- ====================================

-- 1. Orders placed each month in 2024
SELECT 
    TO_CHAR(order_date, 'Month') AS month,
    COUNT(order_id) AS orders_placed
FROM orders
WHERE EXTRACT(YEAR FROM order_date) = 2024
GROUP BY TO_CHAR(order_date, 'Month')
ORDER BY month;

-- 2. Month & year with highest number of orders
SELECT 
    EXTRACT(YEAR FROM order_date) AS order_year,
    EXTRACT(MONTH FROM order_date) AS order_month,
    COUNT(order_id) AS total_orders
FROM orders
GROUP BY order_year, order_month
ORDER BY total_orders DESC
LIMIT 1;

-- 3. Monthly revenue trend for top 3 restaurants
WITH top_restaurants AS (
    SELECT restaurant_id
    FROM orders
    GROUP BY restaurant_id
    ORDER BY SUM(total_amount) DESC
    LIMIT 3
)
SELECT 
    r.name AS restaurant_name,
    EXTRACT(YEAR FROM o.order_date) AS year,
    EXTRACT(MONTH FROM o.order_date) AS month,
    SUM(o.total_amount) AS monthly_revenue
FROM orders o
JOIN restaurants r ON o.restaurant_id = r.restaurant_id
WHERE o.restaurant_id IN (SELECT restaurant_id FROM top_restaurants)
GROUP BY r.name, year, month
ORDER BY r.name, year, month;

-- 4. Day of week with highest orders
SELECT TO_CHAR(order_date, 'DAY') AS day_name, COUNT(order_id) AS total_orders
FROM orders
GROUP BY day_name
ORDER BY total_orders DESC
LIMIT 1;

-- 5. Average rating per cuisine type
SELECT r.cuisine_type, 
       ROUND(AVG(rt.rating), 2) AS average_ratings
FROM restaurants r
JOIN ratings rt ON r.restaurant_id = rt.restaurant_id
GROUP BY r.cuisine_type
ORDER BY average_ratings DESC;

-- 6. Restaurant with most unique users rating it
SELECT r.name, COUNT(DISTINCT rt.user_id) AS users_rated
FROM restaurants r
JOIN ratings rt ON r.restaurant_id = rt.restaurant_id
GROUP BY rt.restaurant_id, r.name
ORDER BY users_rated DESC
LIMIT 1;










































