SELECT * FROM [dannys_diner].[members];

--1. What is the total amount each customer spent at the restaurant?
SELECT
	CASE
		WHEN customer_id = 'A' THEN 'Customer A'
		WHEN customer_id = 'B' THEN 'Customer B'
		WHEN customer_id = 'C' THEN 'Customer C'
		ELSE customer_id
    END AS Customers, 
	'$' + CAST(SUM(menu.price) AS varchar) AS Amount_Spent
FROM 
	[dannys_diner].[sales]
LEFT JOIN 
	[dannys_diner].[menu]
ON 
	[dannys_diner].[sales].product_id = [dannys_diner].[menu].product_id
GROUP BY 
	customer_id
ORDER BY 
	customer_id;

--	OR

SELECT s.customer_id,
	  '$' + CAST(SUM(m.price) AS varchar) AS Amount_Spent
FROM 
	[dannys_diner].[sales] as s
JOIN 
	[dannys_diner].[menu] as m
ON 
	s.product_id = m.product_id
GROUP BY 
	customer_id
ORDER BY 
	Amount_Spent DESC;


--2. How many days has each customer visited the restaurant?
SELECT customer_id,
	COUNT(DISTINCT order_date) AS Days_visited
FROM [dannys_diner].[sales]
GROUP BY customer_id;

--3. What was the first item from the menu purchased by each customer?

WITH firstitem_bought AS
   (
	SELECT customer_id,product_id, 
	ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY order_date ASC) AS Rnk
FROM 
	[dannys_diner].[sales])
SELECT *
FROM 
	firstitem_bought
WHERE 
	Rnk = 1;
-- OR

SELECT
  itembought_first.customer_id,
  itembought_first.product_id,
  menu.product_name AS Item_bought_first
FROM
  (
    SELECT
      customer_id,
      product_id,
      ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date ASC) AS Rnk
    FROM
      [dannys_diner].[sales]
  ) AS itembought_first
JOIN
  [dannys_diner].[menu]
ON
  [dannys_diner].[menu].product_id = itembought_first.product_id
WHERE
	Rnk = 1;

--4. What is the most purchased item on the menu and how many times was it purchased by all customers?

WITH Purchased_Item AS
	(
	SELECT
	menu.product_name AS Most_Purchased,
	COUNT([dannys_diner].[menu].product_id) AS Times_Purchased
FROM
	[dannys_diner].[sales]
JOIN 
	[dannys_diner].[menu]
ON
	[dannys_diner].[menu].product_id = [dannys_diner].[sales].product_id
GROUP BY 
	product_name
	)

	SELECT Most_Purchased,
		   Times_Purchased
	FROM
		Purchased_Item
	WHERE Times_Purchased =
		(SELECT MAX (Times_Purchased) 
			FROM Purchased_Item);

-- OR

SELECT
  menu.product_name AS Most_Purchased,
  COUNT(menu.product_id) AS Times_Purchased
FROM
  [dannys_diner].[sales]
JOIN
  [dannys_diner].[menu]
ON
  menu.product_id = sales.product_id
GROUP BY menu.product_name
HAVING
  COUNT(menu.product_id) = (
    SELECT MAX(count_Purchase)
    FROM (
      SELECT COUNT(menu.product_id) AS count_Purchase
      FROM [dannys_diner].[sales]
      JOIN [dannys_diner].[menu] ON menu.product_id = sales.product_id
      GROUP BY menu.product_name
    )AS All_in_All);

--5. Which item was the most popular for each customer?

WITH popularity_item AS (
   SELECT s.customer_id,
		m.product_name AS Most_popular, 
	   COUNT(m.product_id) AS popularity_count,
       DENSE_RANK() OVER(PARTITION BY s.customer_id
  ORDER BY 
	  COUNT(m.product_id)DESC) AS order_rank 
  FROM 
	  [dannys_diner].[sales] s 
  JOIN 
	  [dannys_diner].[menu] m 
  ON 
	  s.product_id = m.product_id
  GROUP BY 
	  s.customer_id, m.product_name
)
SELECT customer_id,
	   Most_popular,  
	   popularity_count
FROM 
	  popularity_item
WHERE 
      order_rank = 1;

-- 6. Which item was purchased first by the customer after they became a member?

WITH Purchased_first AS (
   SELECT mb.join_date,
		  mb.customer_id,
	      m.product_name AS first_Purchased,
	      s.order_date AS date_purchased,
	      DENSE_RANK() OVER (PARTITION BY mb.customer_id ORDER BY order_date ASC ) AS Ranking
FROM 
	 [dannys_diner].[sales] s
JOIN 
	[dannys_diner].[menu] m
	ON
	s.product_id = m.product_id
JOIN
	[dannys_diner].[members] mb
	ON
	s.customer_id = mb.customer_id
WHERE 
	order_date >= join_date
	)
SELECT customer_id,
	   join_date,	
	   first_Purchased,
	   date_purchased
FROM	
	Purchased_first
WHERE Ranking =1;

--7.Which item was purchased just before the customer became a member?

WITH Purchased_before AS (
   SELECT mb.join_date,
		  mb.customer_id,
	      m.product_name AS Purchased_Before_Member,
	      s.order_date AS purchase_before_join,
	      DENSE_RANK() OVER (PARTITION BY mb.customer_id ORDER BY order_date ASC ) AS Ranking
FROM 
	 [dannys_diner].[sales] s
INNER JOIN 
	[dannys_diner].[menu] m
	ON
	s.product_id = m.product_id
INNER JOIN
	[dannys_diner].[members] mb
	ON
	s.customer_id = mb.customer_id
WHERE 
	order_date < join_date
	)
SELECT customer_id,
	   join_date,	
	   Purchased_Before_Member,
	   purchase_before_join
FROM	
	Purchased_before
WHERE Ranking =1;

-- 8. What is the total items and amount spent for each member before they became a member?

SELECT 
    s.customer_id,
    COUNT(s.product_id) AS items_total,
    '$' + CAST(SUM(m.price) AS varchar) AS amount_spent
FROM 
	[dannys_diner].[sales] s
JOIN
    [dannys_diner].[members] mb 
ON 
	s.customer_id = mb.customer_id
JOIN
   [dannys_diner].[menu]  m on s.product_id = m.product_id
WHERE 
	s.order_date < mb.join_date
GROUP BY 
	s.customer_id;

-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

WITH Points_earner AS(
	SELECT
	m.product_id,
	m.product_name,
	CASE
		WHEN product_name = 'sushi' THEN price *2
		ELSE price * 1 
		END AS points_earn
	FROM
	[dannys_diner].[menu] m
	)
SELECT
    s.customer_id,
    SUM(pe.points_earn) AS total_points
FROM dannys_diner.sales s
JOIN
    Points_earner  pe
ON 
	s.product_id = pe.product_id
GROUP BY 
	s.customer_id;

-- 10 In the first week after a customer joins the program (including their join date) they earn 2x points on all items, 
   -- not just sushi - how many points do customer A and B have at the end of January?

 WITH purchase_points AS (
        SELECT
	    s.customer_id,
	    s.product_id,
	    s.order_date,
	    c.join_date,
	    CASE
	        WHEN s.order_date between c.join_date and DATEADD(d, 6, c.join_date)
		    OR s.product_id = 1
		THEN m.price*20
		ELSE m.price *10
	      END AS product_points
	FROM dannys_diner.sales s
	JOIN
	    dannys_diner.menu m 
	ON s.product_id = m.product_id
	JOIN
	    dannys_diner.members c 
	ON 
		s.customer_id = c.customer_id
	WHERE 
		s.order_date <= '2021-01-31'
    )
    
SELECT
    customer_id,
    SUM(product_points) AS total_points
FROM 
	purchase_points as pp
GROUP BY 
	customer_id;