-- 1. amount each customer spent at the restaurent
select s.customer_id, sum(m.price) as price
from sales as s left join menu m on s.product_id = m.product_id
group by s.customer_id;

-- 2. How many days has each customer visited the restaurant?
select customer_id, count(distinct order_date) from sales
group by customer_id;

-- 3. What was the first item from the menu purchased by each customer?


WITH ranked_sales AS (
    SELECT 
        customer_id,
        order_date,
        product_id,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS rn
    FROM sales
)
SELECT customer_id, order_date, product_id, rn
FROM ranked_sales
WHERE rn <= 1;

WITH ranked_sales AS ( -- creating a ranked_sales table
    SELECT 
        customer_id,
        order_date,
        product_id,
        ROW_NUMBER() OVER (ORDER BY customer_id, order_date) AS rn
    FROM sales
)
select * from ranked_sales;


-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
select sales.product_id, menu.product_name, count(*) from sales
left join menu on sales.product_id = menu.product_id
group by sales.product_id, menu.product_name;

-- 5. Which item was the most popular for each customer?
-- 1st type
with v as (
select customer_id, 
product_id,
count(*) as no_orders,
ROW_NUMBER() over (partition by customer_id order by count(*) desc) as rn
from sales
group by customer_id, product_id
)

select v.customer_id, menu.product_name, v.no_orders from v
left join menu on v.product_id= menu.product_id
where v.rn=1;

-- 2nd type

WITH ranked_sales AS (
    SELECT 
        sales.customer_id, 
        sales.product_id, 
        menu.product_name, 
        COUNT(*) AS order_count,
        ROW_NUMBER() OVER (PARTITION BY sales.customer_id ORDER BY COUNT(*) DESC) AS rn
    FROM sales
    LEFT JOIN menu ON sales.product_id = menu.product_id
    GROUP BY sales.customer_id, sales.product_id, menu.product_name
)
SELECT 
    customer_id, 
    product_id, 
    product_name, 
    order_count
FROM ranked_sales
WHERE rn = 1;


-- 6.Which item was purchased first by the customer after they became a member?

with v as 
(
select sales.customer_id,
 sales.product_id,
 sales.order_date,
 row_number() over (partition by customer_id order by order_date) as rn
 from sales left join members on sales.customer_id = members.customer_id
 where members.join_date<=sales.order_date
)

select customer_id,
 product_id,
 order_date from v where rn<=1;


-- 7.Which item was purchased just before the customer became a member?

with v as 
(
select sales.customer_id,
 sales.product_id,
 sales.order_date,
 row_number() over (partition by customer_id order by order_date desc) as rn
 from sales left join members on sales.customer_id = members.customer_id
 where (case when members.join_date is not null and members.join_date>sales.order_date then 1
 when members.join_date is null then 1 end)
)
select customer_id,
 product_id,
 order_date from v where rn<=1;


-- chatgpt ans
WITH customer_orders AS (
    SELECT 
        s.customer_id, 
        s.order_date, 
        s.product_id, 
        m.join_date,
        ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.order_date DESC) AS rn
    FROM sales AS s
    LEFT JOIN members AS m ON s.customer_id = m.customer_id
),
orders_before_join AS (
    SELECT 
        customer_id, 
        product_id, 
        order_date, 
        join_date,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id 
            ORDER BY 
               order_date DESC
        ) AS rn_before_join
    FROM customer_orders
)
SELECT 
    o.customer_id, 
    o.product_id, 
    m.product_name, 
    o.order_date
FROM orders_before_join AS o
LEFT JOIN menu AS m ON o.product_id = m.product_id
WHERE o.rn_before_join = 1;




-- 8.What is the total items and amount spent for each member before they became a member?

with v as 
(
select sales.customer_id,
 sales.product_id,
 sales.order_date
 from sales left join members on sales.customer_id = members.customer_id
 where (case when members.join_date is not null and members.join_date>sales.order_date then 1
 when members.join_date is null then 1 end)
),
with_price as
(
select v.customer_id,
 v.product_id,
 count(v.product_id) as no_of_prodcuts,
 sum(menu.price) as total_price
 from v left join menu on menu.product_id = v.product_id
 group by v.product_id,v.customer_id
)
select * from with_price;

-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?


-- by merging sushi and sushi less tables
with tab as
(
select sales.customer_id, sum(menu.price)*10 as price
from sales left join menu on sales.product_id = menu.product_id
where menu.product_name != "sushi"
group by sales.customer_id
),
tab2 as
(
select sales.customer_id, sum(menu.price)*20 as price
from sales left join menu on sales.product_id = menu.product_id
where menu.product_name = "sushi"
group by sales.customer_id
),
t as
(
select customer_id, price from tab
union all
select customer_id, price from tab2
)
select customer_id, sum(price) from t
group by customer_id;



-- 3nd method
select sales.customer_id, sum(case when menu.product_name != "sushi" then menu.price*10 else menu.price*20 end)
from sales left join menu on menu.product_id = sales.product_id
group by sales.customer_id;


-- 10.In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

select sales.customer_id, sum(case when sales.order_date - members.join_date<=7 and sales.order_date - members.join_date>=0 then menu.price*20 
									when menu.product_name != "sushi" then menu.price*10
									else menu.price*20 end)
from sales left join members on sales.customer_id = members.customer_id
left join menu on menu.product_id = sales.product_id
group by sales.customer_id;

-- bonues one customer_id	order_date	product_name	price	ismember
select sales.customer_id,
		sales.order_date,
        menu.product_name,
        menu.price,
        case when sales.order_date>=members.join_date then 'Y' else 'N' end as ismember
from sales left join menu on sales.product_id = menu.product_id
left join members on sales.customer_id = members.customer_id
order by sales.customer_id asc, sales.order_date asc, price desc;


-- bonus
with v as
(
select sales.customer_id,
		sales.order_date,
        menu.product_name,
        menu.price,
        case when sales.order_date>=members.join_date then 'Y' else 'N' end as ismember
from sales left join menu on sales.product_id = menu.product_id
left join members on sales.customer_id = members.customer_id
order by sales.customer_id asc, sales.order_date asc, price
)
select *,row_number() over (partition by customer_id) as rank_
    from v;
