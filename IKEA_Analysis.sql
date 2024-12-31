select * from inventory; --p

select * from products; --p

select * from sales; --c

select * from stores; --c

-- Adding new column net_sale
BEGIN

ALTER Table sales
ADD COLUMN net_sale FLOAT;

UPDATE sales
SET net_sale = (qty * unit_price) - ((qty * unit_price)*(discount_percentage));

UPDATE sales
SET net_sale = ROUND(net_sale::numeric, 2);

SELECT * FROM sales;

ROLLBACK

COMMIT
-------------------------------------------------------

-- SUBQUERIES

-- Identify the products that have never been sold in any stores

SELECT *
FROM products
WHERE product_id NOT IN (
						SELECT 
							DISTINCT(product_id)
						FROM sales
						);



-- CTAS : CREATE, TABLE, AS, SELECT : creating a combined table

CREATE TABLE global_sales
AS
SELECT 
	s.*,
	p.product_name,
	p.category,
	p.subcategory,
	st.store_name,
	st.city,
	st.country
FROM sales as s
INNER JOIN products as p
ON s.product_id = p.product_id
INNER JOIN stores as st
ON s.store_id = st.store_id;

----------------------------------------------------------

SELECT * FROM global_sales;

-- Find the stores where the total revenue is higher than the average revenue across all stores.

SELECT 
	store_id,
	store_name,
	ROUND(SUM(net_sale)::numeric, 2) as total_revenue
FROM global_sales
GROUP BY 1,2
HAVING SUM(net_sale) > (	

					SELECT 
						SUM(net_sale)/(SELECT COUNT(DISTINCT(store_id)) FROM global_sales)
					FROM global_sales
					
					);  --SELECT statement in GROUP BY Clause


-- *** Important question ***
-- Find the best selling products of each category such that find the products whose sales exceed the average sales of their category.

-- Creating a CTE

WITH sales_t1   --- CTE
AS
	(SELECT 
		category,
		product_id,
		product_name,
		SUM(net_sale) as total_sale
	FROM global_sales
	GROUP BY 1,2,3
	)

SELECT 
	s1.category,
	s1.product_id,
	s1.product_name,
	s1.total_sale     -- outer query
from sales_t1 as s1  
WHERE total_sale > ( SELECT AVG(total_sale) 
					 FROM sales_t1
					 WHERE category = s1.category)  -- correlated subquery -- Subquery in the Where statement
ORDER BY 1;


-- CASE STATEMENTS
-- Find out how many products are under stocked and how many products have good stock level.
-- categorize each product into under stock if current stock level is less than re-order level
-- else categorize them into good stock level.

-- 1. Filtering the CASE STATEMENT column by CTE method

WITH inv_t1
AS
(SELECT
	inv.inventory_id,
	inv.current_stock,
	p.product_name,
	p.category,
	CASE
		WHEN current_stock < reorder_level THEN 'under_stock'
		ELSE 'good_stock_level'
	END as stock_status
FROM inventory as inv
lEFT JOIN products as p
ON inv.product_id = p.product_id
)

SELECT *
FROM inv_t1
WHERE stock_status = 'under_stock'


-- 2. Filtering the CASE STATEMENT column by Subquery Method
-- Subquery in the FROM Statement

SELECT *
FROM
		(SELECT
			inv.inventory_id,
			inv.current_stock,
			inv.reorder_level,
			p.product_name,
			p.category,
			CASE
				WHEN current_stock < reorder_level THEN 'under_stock'
				ELSE 'good_stock_level'
			END as stock_status
		FROM inventory as inv
		lEFT JOIN products as p
		ON inv.product_id = p.product_id
		) as T1
WHERE stock_status = 'under_stock';


-- For each product indicate if it has a 'high discount', 'moderate discount', or 'low discount'
-- based on the discount percentage.
-- Condition: discount > 28 (high), between 27 & 28 (moderate), < 27(low) 

WITH temp_t1
AS
	(SELECT 
		product_id,
		product_name,
		round(avg(discount_percentage * 100):: numeric , 3) as average_discount
	FROM global_sales
	GROUP BY 1,2
	),

temp_t2
AS
		(SELECT 
			product_id,
			product_name,
			average_discount,
			CASE
				WHEN average_discount > 28 THEN 'high_discount'
				WHEN average_discount BETWEEN 25 AND 28 THEN 'moderate_discount'
				ELSE 'less_discount'
			END as discount_status
		FROM temp_t1)

SELECT 
	discount_status,
	COUNT(product_id)
FROM temp_t2
GROUP BY 1,


-- Identify the stores with decreasing revenue compared to last year
-- Return the stores with highest decrease ratio
-- Consider current year is 2023 and last year is 2022

WITH last_year_sales
AS
(select 
	st.store_id,
	st.store_name,
	ROUND(sum(s.net_sale)::numeric, 2) as total_sale_2022
FROM stores as st
INNER JOIN sales as s
ON st.store_id = s.store_id
Where EXTRACT(YEAR FROM s.order_date) = 2022
GROUP BY 1,2),

curr_year_sales
AS
(select 
	st.store_id,
	st.store_name,
	ROUND(sum(s.net_sale)::numeric, 2) as total_sale_2023
FROM stores as st
INNER JOIN sales as s
ON st.store_id = s.store_id
Where EXTRACT(YEAR FROM s.order_date) = 2023
GROUP BY 1,2)

Select 
	ls.store_id,
	ls.store_name,
	ls.total_sale_2022,
	cs.total_sale_2023,
	ROUND(((ls.total_sale_2022 - cs.total_sale_2023):: numeric/ ls.total_sale_2022 * 100)::numeric, 2) as sales_decrease
FROM last_year_sales as ls
INNER JOIN curr_year_sales as cs
ON ls.store_id = cs.store_id
WHERE ls.total_sale_2022 > cs.total_sale_2023
ORDER BY sales_decrease DESC;

-- **** Subquery and Correlated Subquery Problems ****

-- 1. Identify products that have never been sold in any store.

SELECT 
	* 
FROM products
WHERE product_id NOT IN ( SELECT 
						   		DISTINCT(product_id) 
						   FROM sales
						  );


-- 2. Find stores where the total sales revenue is higher than the average revenue across all stores.

WITH temp_table1
AS
(SELECT 
	st.store_id,
	st.store_name,
	ROUND(SUM(s.net_sale)::numeric, 2) as total_sale
FROM stores as st
INNER JOIN sales as s
ON st.store_id = s.store_id
GROUP BY 1,2)

SELECT 
	*
FROM temp_table1
WHERE total_sale > (SELECT
						AVG(total_sale)
					FROM temp_table1);


-- 3. Display products whose average unit price in sales transactions is lower 
--    than their listed price in the products table.

SELECT
	p.product_id
FROM products as p
WHERE p.unit_pice > (SELECT 
						AVG(unit_price)
					FROM sales as s
					WHERE s.product_id = p.product_id);


-- 4. Use a correlated subquery to find products whose sales exceeded the average sales of their category.
--    (Find Best Selling Products of Each Category)

SELECT * FROM sales;
SELECT * FROM products;

WITH temp_tabl3
AS
	(SELECT 
		p.category,
		p.product_id,
		p.product_name,
		ROUND(SUM(s.net_sale)::numeric, 2) as total_sale
	FROM products as p
	INNER JOIN sales as s
	ON p.product_id = s.product_id
	GROUP BY 1,2,3)

SELECT
	t3.category,
	t3.product_id,
	t3.product_name,
	t3.total_sale
FROM temp_tabl3 as t3
WHERE t3.total_sale > (SELECT
						AVG(total_sale)
					FROM temp_tabl3 as t4
					WHERE t4.category = t3.category)
ORDER BY 1;

-- 5. List cities with total sales greater than the average sales for their country.

WITH temp_tabl4
AS
	(SELECT 
		st.city,
		st.country,
		ROUND(SUM(s.net_sale)::numeric, 2) as total_sale
	FROM stores as st
	INNER JOIN sales as s
	ON st.store_id = s.store_id
	GROUP BY 1,2
	)	

SELECT
	t5.city,
	t5.total_sale
FROM temp_tabl4 as t5
WHERE t5.total_sale > (SELECT
							AVG(total_sale)
						FROM temp_tabl4
						WHERE country = t5.country)


-- **** CASE Statement ****

-- 1. Categorize stores based on sales performance as "High," "Medium," or "Low" using 
--    the total sales revenue.

WITH temp_tabl6
AS
	(SELECT 
		st.store_id,
		st.store_name,
		ROUND(SUM(s.net_sale)::numeric, 2) as total_sale
	FROM stores as st
	INNER JOIN sales as s
	ON st.store_id = s.store_id
	GROUP BY 1,2 
	)

SELECT
	*,
	CASE
		WHEN total_sale > 300000 THEN 'High_Performing'
		WHEN total_sale BETWEEN 120995.53 AND 300000 THEN 'Medium_Performing'
		ELSE 'Low_Performing'
	END as store_performance
FROM temp_tabl6


-- 2. Create a column indicating if the product price is above or below the average price for its category.

SELECT 
	*,
	CASE
		WHEN p.unit_pice > (SELECT 
								AVG(unit_pice) 
						    FROM products
						    WHERE category = p.category) THEN 'Above_Priced'
		ELSE 'Below_Priced'
	END as price_category
FROM products as p;

-- 3. Display the reorder status for each product in inventory as "Low Stock" if 
--    current stock is below the reorder level, otherwise "Sufficient Stock."

SELECT 
	*,
	CASE
		WHEN current_stock < reorder_level THEN 'Low_Stock'
		ELSE 'Sufficient_Stock'
	END as inventory_status
FROM inventory;

-- 4. Identify each store’s top-selling product and categorize it as “Top Performer” or “Underperformer” 
--    based on a specified sales quantity threshold.
-- Threshold qty = 80

SELECT 
	store_id,
	product_id,
	SUM(qty) as total_qty,
	CASE
		WHEN SUM(qty) > 80 THEN 'Top_Performer'
		ELSE 'Under_Performer'
	END as top_selling_products
FROM sales
GROUP BY 1,2
ORDER BY 1,4;

-- 5. For each product, indicate if it has a "High Discount," "Moderate Discount," or "Low Discount" 
--    based on the discount percentage.
-- Condition: discount > 28 (high), between 27 & 28 (moderate), < 27(low)

WITH temp_tabl8
AS
	(SELECT 
		product_id,
		ROUND(AVG(discount_percentage)::numeric, 2)*100 as avg_dis_per
	FROM sales
	GROUP BY 1
	),

temp_tabl9
AS
	(SELECT 
		*,
		CASE
			WHEN avg_dis_per > 28 THEN 'High'
			WHEN avg_dis_per BETWEEN 27 AND 28 THEN 'Moderate'
			ELSE 'Low'
		END AS discount_category
	FROM temp_tabl8)

SELECT 
	discount_category,
	COUNT(product_id)
FROM temp_tabl9
GROUP BY 1;

-- 6. Mark stores as "Overstocked" or "Understocked" if current stock is above or below reorder level.

-- SELECT * FROM inventory
-- SELECT * FROM stores
-- SELECT * FROM sales
-- SELECT * FROM products

-- **** Window Functions (ROW_NUMBER, RANK, DENSE_RANK) with PARTITION BY ****

-- 1. List the top five products by sales quantity within each store.

WITH product_sales
AS
(select 
	st.store_id,
	p.product_id,
	p.product_name,
	sum(s.qty) as total_quantity
FROM stores as st
INNER JOIN sales as s
ON st.store_id = s.store_id
INNER JOIN products as p
ON s.product_id = p.product_id
GROUP BY 1,2,3
)

SELECT *
FROM
	(SELECT 
		*,
		DENSE_RANK() OVER(PARTITION BY store_id ORDER BY total_quantity DESC) as most_sold_products_rank
	FROM product_sales) as product_ranking_across_stores
WHERE most_sold_products_rank < 6;

-- 2. Retrieve the top-selling product in each category.

WITH products_across_category
AS
(select 
	p.category,
	p.product_id,
	p.product_name,
	SUM(s.qty) as total_quantity
FROM products as p
INNER JOIN sales as s
ON p.product_id = s.product_id
GROUP BY 1,2,3
)

SELECT *
FROM
	(SELECT 
		*,
		DENSE_RANK() OVER(PARTITION BY category ORDER BY total_quantity DESC) as ranking
	FROM products_across_category) as product_ranking
WHERE ranking < 2;

-- 3. Get RANK for each store based on total revenue.

WITH stores_revenue
AS
	(SELECT 
		st.store_id,
		st.store_name,
		ROUND(SUM(s.net_sale)::numeric,2) as total_revenue
	FROM stores as st
	INNER JOIN sales as s
	ON st.store_id = s.store_id
	GROUP BY 1,2
	)

SELECT
	*,
	DENSE_RANK() OVER(ORDER BY total_revenue DESC) as store_ranking
FROM stores_revenue;

-- 4. Use ROW_NUMBER to find the first sale of each product in each store.

-- 5. Rank products within each category based on total sales revenue.

WITH products_revenue
AS
(select 
	p.category,
	p.product_id,
	p.product_name,
	ROUND(SUM(s.net_sale)::numeric, 2) as total_revenue
FROM products as p
INNER JOIN sales as s
ON p.product_id = s.product_id
GROUP BY 1,2,3
)

SELECT
	*,
	DENSE_RANK() OVER(PARTITION BY category ORDER BY total_revenue DESC) as ranking
FROM products_revenue;

-- 6. Asign a unique ranking to each product based on its sales quantity, grouped by country.

WITH products_sales_across_country
AS
	(select 
		st.country,
		s.product_id,
		ROUND(sum(s.qty)::numeric, 2) as total_quantity
	FROM stores as st
	INNER JOIN sales as s
	ON st.store_id = s.store_id
	GROUP BY 1,2
		)

SELECT 
	*,
	DENSE_RANK() OVER(PARTITION BY country ORDER BY country ASC, total_quantity DESC)
FROM products_sales_across_country;


-- 7. For each store, show the order history of products sorted by the 
--    order date and assign a sequential number to each order.

WITH product_sale
AS
(select 
	st.store_id,
	st.store_name,
	s.product_id,
	s.order_date
FROM stores as st
INNER JOIN sales as s
ON st.store_id = s.store_id
)

SELECT 
	*,
	ROW_NUMBER() OVER(PARTITION BY store_id ORDER BY order_date ASC) as order_history
FROM product_sale;


-- 8. Find the top three stores with the highest sales revenue in each country using
--    the DENSE_RANK function.

WITH stores_net_sale
AS
(select 
	st.country,
	st.store_id,
	st.store_name,
	ROUND(sum(s.net_sale)::numeric, 2) as total_revenue
FROM stores as st
INNER JOIN sales as s
ON st.store_id = s.store_id
GROUP BY 1,2,3
)

SELECT *
FROM (
		SELECT 
			*,
			DENSE_RANK() OVER(PARTITION BY country ORDER BY country asc, total_revenue DESC) as ranking
		FROM stores_net_sale
     ) as store_ranking
WHERE ranking < 4;

-- 9. Retrieve the total revenue and discount given on each product category per store.

WITH t1
AS
(select 
	s.store_id,
	p.category,
	ROUND(sum(s.net_sale)::numeric,2) as total_revenue
from products as p 
INNER JOIN sales as s
ON p.product_id = s.product_id
GROUP BY 1,2
),

t2
AS
(select 
	s.store_id,
	p.category,
	ROUND(sum(s.discount_percentage)::numeric,2) as total_discount
from products as p 
INNER JOIN sales as s
ON p.product_id = s.product_id
GROUP BY 1,2)

SELECT
	t1.*,
	t2.total_discount
FROM t1
INNER JOIN t2
ON t1.store_id = t2.store_id;

	
-- 1. Find the average discount and total revenue generated for each subcategory across all stores.

select 
	p.subcategory,
	ROUND(SUM(s.net_sale)::numeric,2) as total_revenue,
	ROUND(AVG(s.discount_percentage)::numeric,2) as avg_discount 
FROM sales as s
INNER JOIN products as p
ON s.product_id = p.product_id
GROUP BY 1

-- 2. Retrieve the top three products by total sales revenue in each store.

WITH product_revenue
AS
(SELECT
	st.store_id,
	st.store_name,
	s.product_id,
	ROUND(sum(net_sale)::numeric, 2) as total_revenue
FROM stores as st
INNER JOIN sales as s
ON st.store_id = s.store_id
GROUP BY 1,2,3
)

SELECT *
FROM
	(SELECT
		*,
		DENSE_RANK() OVER(PARTITION BY store_id ORDER BY total_revenue DESC) as product_ranking
	FROM product_revenue) as ranked_table
WHERE product_ranking < 4;

-- 3. Determine the product with the highest number of units sold in each category and store.
 
WITH product_quantity
AS
(SELECT
	s.store_id,
	p.category,
	p.product_id,
	ROUND(SUM(s.qty)::numeric, 2) as total_quantity
FROM products as p
INNER JOIN sales as s
ON p.product_id = s.product_id
GROUP BY 1,2,3
)

SELECT *
FROM
	(SELECT
		*,
		DENSE_RANK() OVER(PARTITION BY store_id ORDER BY total_quantity DESC) as product_ranking
	FROM product_quantity) as ranked_table
WHERE product_ranking < 2;

-- 4. Find the average sales revenue generated by each product in stores where it sold above 
--    the average sales quantity.

-- 5. Identify stores with sales for all products in the "Furniture" category, regardless of stock level.
SELECT
	s.store_id,
	p.category,
	count(order_id) as total_orders,
	sum(qty) as total_quantity_sold,
	sum(net_sale) as total_revenue
FROM products as p
INNER JOIN sales as s
ON p.product_id = s.product_id
WHERE p.category = 'Furniture'
GROUP BY 1,2
ORDER BY 1

-- 6. Use window functions to identify the latest sale for each product in each store.

WITH product_sale
AS
(SELECT
	s.store_id,
	p.product_id,
	-- p.product_name,
	s.order_date,
	s.net_sale
FROM products as p
INNER JOIN sales as s
ON p.product_id = s.product_id
)
SELECT 
	store_id,
	product_id,
	order_date,
	net_sale as latest_sale
FROM
	(SELECT 
		*,
		DENSE_RANK() OVER(PARTITION BY store_id, product_id ORDER BY order_date ASC) as latest_sale_rank
	FROM product_sale
	) as latest_Sale
WHERE latest_sale_rank < 2;
	
-- 7. Determine the average reorder level for products across different subcategories.

select 
	subcategory,
	ROUND(avg(reorder_level)::numeric, 2) as average_reorder_level_across_sub_category
FROM products as p
INNER JOIN inventory as i
ON p.product_id = i.product_id
GROUP BY 1;

-- 8. Retrieve stores with a total discount percentage above the average discount for all stores.

WITH stores_total_discount
AS
(SELECT
 store_id,
 ROUND(sum(discount_percentage)::numeric, 2) as total_discount_percentage
FROM sales
GROUP BY 1
)

SELECT 
	store_id
FROM stores_total_discount
WHERE total_discount_percentage >(SELECT 
									ROUND(avg(total_discount_percentage)::numeric, 2)
								FROM stores_total_discount);


-- 9.Use subqueries to find products whose sales exceed the highest sales of any 
--   other product in the same category.

-- 10.Retrieve the total revenue generated by each store and classify it as "High Revenue" 
--    or "Low Revenue" based on the overall average.

WITH total_stores_revenue
AS
(select 
	store_id,
	ROUND(sum(net_sale)::numeric, 2) as total_revenue
from sales
GROUP BY 1)

SELECT 
	*,
	CASE
		WHEN total_revenue > (SELECT
									ROUND(sum(total_revenue)/count(store_id)::numeric, 2) 
									as average_revenue
							   FROM total_stores_revenue) THEN 'High Revenue'
		ELSE 'LOW Revenue'
	END
FROM total_stores_revenue;

-- 11.For each store, list the top three most frequently sold product categories and 
--    the total revenue generated by each.

WITH product_sales
AS
	(SELECT
		s.store_id,
		p.category,
		sum(s.qty) as quantity_sold,
		ROUND(sum(s.net_sale)::numeric, 2) as total_sales_revenue
	FROM sales as s
	INNER JOIN products as p
	ON s.product_id = p.product_id
	GROUP BY 1,2
	)
	
SELECT 
	*
FROM
		(SELECT 
			*,
			DENSE_RANK() OVER(PARTITION BY store_id ORDER BY quantity_sold DESC) as category_ranking
		FROM product_sales) as sales_across_category
WHERE category_ranking < 4;


-- 12. Find the top five stores by sales quantity for products in the "Kitchen" category, 
--     with rankings adjusted based on discount levels.


WITH product_sales
AS
	(SELECT
		s.store_id,
		p.category,
		sum(s.qty) as quantity_sold,
		ROUND(avg(s.discount_percentage)::numeric, 2) as average_discount_per
	FROM sales as s
	INNER JOIN products as p
	ON s.product_id = p.product_id
	WHERE p.category = 'Kitchen'
	GROUP BY 1,2
	)

SELECT *
FROM
	(SELECT 
		*,
		DENSE_RANK() OVER(ORDER BY average_discount_per DESC, quantity_sold DESC) as stores_ranking
	FROM product_sales) as ranked_table
WHERE stores_ranking < 6


-- 13. For each product category, identify the top-performing stores based on total sales revenue
--     and assign a performance rank to each.

WITH product_sales
AS
	(SELECT
		p.category,
		s.store_id,
		ROUND(sum(s.net_sale)::numeric, 2) as total_sales_revenue
	FROM sales as s
	INNER JOIN products as p
	ON s.product_id = p.product_id
	GROUP BY 1,2
	)

SELECT *
FROM
	(SELECT 
		*,
		DENSE_RANK() OVER(PARTITION BY category ORDER BY total_sales_revenue DESC) as stores_ranking
	FROM product_sales) as ranked_table
WHERE stores_ranking < 2


-- 14. List products with inventory levels below their reorder level and sales quantities 
--     above the average for their category.

-- products
-- inventory level < reorder level
-- total_sales > avg_sales_category

WITH product_sales
AS
	(select 
		p.product_id,
		p.product_name,
		p.category,
		ROUND(sum(s.net_sale)::numeric, 2) as total_sales
	FROM sales as s
	INNER JOIN products as p
	ON s.product_id = p.product_id
	INNER JOIN inventory i
	ON p.product_id = i.product_id
	WHERE i.current_stock < i.reorder_level
	GROUP BY 1,2,3)


SELECT 
	ps.product_id,
	ps.product_name,
	ps.total_sales
FROM product_sales as ps
WHERE ps.total_sales > (
						SELECT 
							avg(sales.net_sale)
						from sales
						INNER JOIN products
						ON sales.product_id = products.product_id
						WHERE products.category = ps.category
);

-- 15. Calculate the total revenue and discount applied for each stores and categorize 
--     it as "High," "Moderate," or "Low" discount based on predefined ranges.






