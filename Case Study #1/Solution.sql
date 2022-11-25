-- Q1. What is the total amount each customer spent at the restaurant?

SELECT s.customer_id, sum(m.price) as total_amount
FROM menu m
JOIN sales s on m.product_id = s.product_id
GROUP BY s.customer_id
ORDER BY total_amount DESC
;

-- Q2. How many days has each customer visited the restaurant?

SELECT customer_id, count(distinct(order_date)) as days_visited
FROM sales
GROUP BY customer_id
ORDER BY days_visited DESC
;

-- Q3. What was the first item from the menu purchased by each customer?

SELECT customer_id, first_value(m.product_name)over(partition by customer_id order by order_date) as first_item_ordered
FROM sales s
JOIN menu m on s.product_id = m.product_id
;

-- 2nd method
WITH orders_info (customer_id, product_name, the_rank) as 
	(
	SELECT s.customer_id, m.product_name, dense_rank()over(partition by s.customer_id order by s.order_date) as the_rank
	FROM sales s
	JOIN menu m on s.product_id = m.product_id
	)									
SELECT customer_id, ARRAY_AGG(distinct product_name) AS first_item_ordered
FROM orders_info
WHERE the_rank = 1
GROUP BY customer_id
;

-- Q4. What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT  m.product_name, count(m.product_id) as max_times_purchased
FROM sales s
JOIN menu m on s.product_id = m.product_id
GROUP BY m.product_name
ORDER BY max_times_purchased DESC
LIMIT 1
;

-- Q5. Which item was the most popular for each customer?

with temp_info as ( 
	select customer_id, m.product_name, count(m.product_name) as the_count, 
	dense_rank() over(partition by customer_id order by count(m.product_name) DESC) as the_rank
	from sales s
	JOIN menu m on s.product_id = m.product_id
	group by customer_id, m.product_name
	)
select customer_id, product_name as most_ordered, the_count
from temp_info
where the_rank = 1

-- Q6. Which item was purchased first by the customer after they became a member?

WITH member_info AS (
	SELECT s.customer_id, product_name, m1.product_id,
    DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date) AS the_rank
    FROM menu m1
    JOIN sales s 
	USING (product_id)
    JOIN members m2 
	USING (customer_id)
    WHERE order_date >= join_date 
	)
SELECT customer_id, product_name
FROM member_info
WHERE the_rank = 1
;

-- Q7. Which item was purchased just before the customer became a member?

WITH member_info (customer_id, product_name, product_id, the_rank) AS 
	(
	SELECT s.customer_id, product_name, m1.product_id,
    DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date) AS the_rank
    FROM menu m1
    JOIN sales s 
	USING (product_id)
    JOIN members m2 
	USING (customer_id)
    WHERE order_date < join_date 
	)
SELECT customer_id,
ARRAY_AGG(product_name) AS product_name
FROM member_info
WHERE the_rank = 1
GROUP BY customer_id
;

-- Q8. What is the total items and amount spent for each member before they became a member?

WITH price_info as (
	SELECT s.customer_id, m1.product_id, COUNT(m1.product_id)over(partition by s.customer_id) as total_items_bought, 
	SUM(price)over(partition by s.customer_id) as sum_spent,
	ROW_NUMBER()over(partition by s.customer_id) as the_row
	FROM menu m1
    JOIN sales s 
	USING (product_id)
    JOIN members m2 
	USING (customer_id)
    WHERE order_date < join_date 
	)
SELECT customer_id, total_items_bought, CONCAT('$', sum_spent) AS sum_spent
FROM price_info
WHERE the_row = 1

-- Q9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

SELECT s.customer_id,
	   SUM(CASE
		   WHEN m1.product_id = 1 THEN 2*10*m1.price
		   ELSE 1*10*m1.price
	   END) as points
FROM menu m1
JOIN sales s 
USING (product_id)
GROUP BY customer_id

/* Q10. In the first week after a customer joins the program 
   		(including their join date) they earn 2x points on all items, 
   		not just sushi- how many points do customer A and B have at the end of January?
*/

SELECT s.customer_id, 
	   SUM(CASE
		   WHEN order_date BETWEEN join_date and join_date + INTERVAL '1 week' THEN 2*10*m1.price
		   WHEN order_date NOT BETWEEN join_date AND join_date + INTERVAL '1 week' AND product_id = 1 THEN 2*10*m1.price
           WHEN order_date NOT BETWEEN join_date AND join_date + INTERVAL '1 week' AND product_id != 1 THEN 1*10*m1.price
	   END) as points
FROM menu m1
JOIN sales s 
USING (product_id)
JOIN members m2 
USING (customer_id)
WHERE order_date >= join_date AND order_date <= '2021-01-31'
GROUP BY s.customer_id

-- Bonus question 1
-- Join everything together and state the membership at the time of order

SELECT s.customer_id, s.order_date, m1.product_name, m1.price, 
	   CASE 
	   		WHEN s.order_date >= m2.join_date THEN 'Y'
			ELSE 'N'
	   END member
FROM sales s
LEFT JOIN menu m1 
USING (product_id)
LEFT JOIN members m2 
USING (customer_id)
ORDER BY s.customer_id, s.order_date

-- Bonus question 2
-- Rank the customers' products, return null for non-members

WITH cte_info as (
SELECT s.customer_id, s.order_date, m1.product_name, m1.price, 
	   CASE 
	   		WHEN s.order_date >= m2.join_date THEN 'Y'
			ELSE 'N'
	   END member
FROM sales s
LEFT JOIN menu m1 
USING (product_id)
LEFT JOIN members m2 
USING (customer_id)
ORDER BY s.customer_id, s.order_date
)
SELECT *,
       CASE
	   		WHEN member='N' THEN NULL 
			ELSE DENSE_RANK() OVER (partition by customer_id,member order by order_date,product_name) 
		END ranking
FROM cte_info;


