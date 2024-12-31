# IKEA Retail Sales SQL Project

![Project Banner Placeholder](https://static.dezeen.com/uploads/2019/04/ikea-logo-new-hero-1-1704x958.jpg)

Welcome to the **IKEA Retail Sales SQL Project**! This project leverages a detailed dataset of millions of sales records, product inventory, and store information across IKEA's global operations. The analysis focuses on uncovering sales trends, product performance, and inventory management insights to assist in data-driven decision-making.

---

## Table of Contents
- [Introduction](#introduction)
- [Project Structure](#project-structure)
- [Database Schema](#database-schema)
- [Business Problems](#business-problems)
- [SQL Queries & Analysis](#sql-queries--analysis)
- [Getting Started](#getting-started)
- [Questions & Feedback](#questions--feedback)
- [Contact Me](#contact-me)
- [ERD (Entity-Relationship Diagram)](#erd-entity-relationship-diagram)

---

## Introduction

The IKEA Retail Sales SQL Project demonstrates the use of SQL to analyze retail data, including **sales records**, **store performance**, **product trends**, and **inventory status**. Using a robust schema, this project answers critical business questions and provides actionable insights to optimize IKEA's operational efficiency and profitability.

---

## Project Structure

1. **SQL Scripts**: Contains SQL queries to create the database schema, populate tables, and perform analyses.
2. **Dataset**: Includes sales data, product information, store details, and inventory records.
3. **Analysis**: SQL queries solve key business problems, leveraging advanced SQL techniques like joins, aggregations, and subqueries.

---

## Database Schema

### 1. **Products Table**
- **product_id**: Unique identifier for each product (Primary Key).
- **product_name**: Name of the product.
- **category**: Category to which the product belongs.
- **subcategory**: Subcategory of the product.
- **unit_price**: Price per unit of the product.

### 2. **Stores Table**
- **store_id**: Unique identifier for each store (Primary Key).
- **store_name**: Name of the store.
- **city**: City where the store is located.
- **country**: Country where the store operates.

### 3. **Sales Table**
- **order_id**: Unique identifier for each sales order (Primary Key).
- **order_date**: Date when the order was placed.
- **product_id**: Foreign key referencing the `products` table.
- **qty**: Quantity of the product sold.
- **discount_percentage**: Discount applied to the order.
- **unit_price**: Price per unit of the product at the time of sale.
- **store_id**: Foreign key referencing the `stores` table.

### 4. **Inventory Table**
- **inventory_id**: Unique identifier for each inventory record (Primary Key).
- **product_id**: Foreign key referencing the `products` table.
- **current_stock**: Current stock level of the product.
- **reorder_level**: Minimum stock level to trigger a reorder.

---

## Business Problems

This project tackles the following business problems:

### Easy-Level Queries
1. Identify products that have never been sold in any store.
```SQL
SELECT * 
FROM products
WHERE product_id NOT IN ( SELECT
				DISTINCT(product_id) 
			  FROM sales);
```
2. Find stores where the total sales revenue is higher than the average revenue across all stores.
```SQL
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

SELECT *
FROM temp_table1
WHERE total_sale > (SELECT
			AVG(total_sale)
		   FROM temp_table1);
```
3. List cities with total sales greater than the average sales for their country.
```SQL
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
			WHERE country = t5.country);

```
4. Categorize stores based on sales performance as "High," "Medium," or "Low" using the total sales revenue.
```SQL
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
FROM temp_tabl6;

```
5. Retrieve stores with a total discount percentage above the average discount for all stores.
```SQL
WITH total_stores_revenue
AS
(select 
	store_id,
	ROUND(sum(net_sale)::numeric, 2) as total_revenue
from sales
GROUP BY 1)

SELECT *,
	CASE
		WHEN total_revenue > (SELECT
					ROUND(sum(total_revenue)/count(store_id)::numeric, 2) as average_revenue
					FROM total_stores_revenue) THEN 'High Revenue'
		ELSE 'LOW Revenue'
	END
FROM total_stores_revenue;
```
6. For each store, list the top three most frequently sold product categories and  the total revenue generated by each.
```SQL
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
	
SELECT *
FROM
		(SELECT 
			*,
			DENSE_RANK() OVER(PARTITION BY store_id ORDER BY quantity_sold DESC) as category_ranking
		FROM product_sales) as sales_across_category
WHERE category_ranking < 4;
```

### Medium to Hard-Level Queries
1. Identify the stores with decreasing revenue compared to last year, return the stores with highest decrease ratio, considering current year as 2023 and last year as 2022.
```SQL
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
```
2.  Identify products whose sales exceeded the average sales of their category.
```SQL
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
```
3. For each product, indicate if it has a "High Discount," "Moderate Discount," or "Low Discount" based on the discount percentage.
```SQL
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
	(SELECT *,
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
```
4. List the top five products by sales quantity within each store.
```SQL
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
	(SELECT *,
		DENSE_RANK() OVER(PARTITION BY store_id ORDER BY total_quantity DESC) as most_sold_products_rank
	FROM product_sales) as product_ranking_across_stores
WHERE most_sold_products_rank < 6;
```		
5. Retrieve the top-selling product in each category.
```SQL
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
```
6. Identify the top three stores with the highest sales revenue in each country.
```SQL
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
```
7. Identify the product with the highest number of units sold in each category and store.
```SQL
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
```
8. Identify the latest sale for each product in each store.
```SQL
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
```
9. Identify the top five stores by sales quantity for products in the "Kitchen" category, with rankings adjusted based on discount levels.
```SQL
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
	(SELECT *,
		DENSE_RANK() OVER(ORDER BY average_discount_per DESC, quantity_sold DESC) as stores_ranking
	FROM product_sales) as ranked_table
WHERE stores_ranking < 6
```
---

## SQL Queries & Analysis

All SQL queries developed for this project are available in the `queries.sql` file. The queries demonstrate advanced SQL skills, including:

- Aggregations with `GROUP BY`.
- Filtering data using `WHERE` and `HAVING`.
- Joining multiple tables to uncover insights.
- Utilizing CTEs, CTAS
- Using subqueries and window functions for complex analyses.

---

## Getting Started

### Prerequisites
- PostgreSQL (or any SQL-compatible database).
- Basic knowledge of SQL.

### Steps to Run
1. **Clone the Repository**:
   ```bash
   git clone https://github.com/SudhinPillai26/IKEA_SQL_Advanced_Project.git
   ```
2. **Set Up the Database**:
   - Run `schema.sql` to create the database schema.
   - Populate tables with sample data using `data.sql`.

3. **Execute Queries**:
   - Open `queries.sql` and execute the queries for analysis.

---

## Questions & Feedback

Feel free to reach out with questions or suggestions. Here's an example query for reference

---

## Contact Me

📧 **[Email](mailto:sudhinpillai1998@gmail.com)**  
💼 **[LinkedIn](https://linkedin.com/in/yourprofile)**  

---

## ERD (Entity-Relationship Diagram)

Here’s the ERD for the IKEA Retail Sales SQL Project:

![ERD Placeholder](https://github.com/najirh/sql-b01-ikea/blob/main/IKEA.png)

---
