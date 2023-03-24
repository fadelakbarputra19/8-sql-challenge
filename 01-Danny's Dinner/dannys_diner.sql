drop database dannys_diner;
CREATE SCHEMA dannys_diner;
 use dannys_diner;

CREATE TABLE sales (
  customer_id VARCHAR(1),
  order_date DATE,
  product_id INTEGER
);

INSERT INTO sales
  (customer_id, order_date, product_id)
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
 

CREATE TABLE menu (
  product_id INTEGER,
  product_name VARCHAR(5),
  price INTEGER
);

INSERT INTO menu
  (product_id, product_name, price)
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  

CREATE TABLE members (
  customer_id VARCHAR(1),
  join_date DATE
);

INSERT INTO members
  (customer_id, join_date)
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');

-- 1. What is the total amount each customer spent at the restaurant?
select 
	s.customer_id, count(price), sum(price) as total_amount
from 
	dannys_diner.sales as s
		join 
	dannys_diner.menu as m on s.product_id = m.product_id
group by customer_id;

-- 2. How many days has each customer visited the restaurant?
select 
	customer_id, count(distinct(order_date)) as days
from 
	dannys_diner.sales 
group by customer_id;

-- 3. What was the first item from the menu purchased by each customer?
with order_date_rank as (
	select 
		s.customer_id, s.order_date, s.product_id, m.product_name,dense_rank () over (
		partition by s.customer_id
        order by s.order_date
    ) as rank_by_order
    from 
		dannys_diner.sales as s
			join 
		dannys_diner.menu as m on s.product_id = m.product_id
)
select 
	customer_id, product_name 
from 
	order_date_rank 
where 
	rank_by_order = 1
group by customer_id, product_name;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
select 
	product_name, count(product_name) as jumlah
from 
	dannys_diner.sales as s
		join 
	dannys_diner.menu as m on s.product_id = m.product_id
group by m.product_name 
order by jumlah desc
limit 1;

-- 5. Which item was the most popular for each customer?
with cte as (
	select 
		customer_id, product_name, count(product_name) as jumlah,
		dense_rank() over (
			partition by customer_id
			order by count(product_name) desc
		) as fav_rank
	from 
		sales as s
			join 
		menu as m on s.product_id = m.product_id
	group by customer_id, product_name
)
select 
	customer_id, product_name 
from 
	cte
where fav_rank = 1;

-- 6. Which item was purchased first by the customer after they became a member?
with cte as (
	select 
		sal.customer_id, order_date, product_name, dense_rank() over (
			partition by customer_id
			order by order_date asc
		) as date_rank
    from sales as sal
    join members as mem
    on sal.customer_id = mem.customer_id
    join menu as men
    on men.product_id = sal.product_id
    where (order_date >= mem.join_date) or (order_date >= mem.join_date)
)
select * from cte 
where date_rank = 1;

-- 7. Which item was purchased just before the customer became a member?
with cte as (
	select sal.customer_id, order_date, product_name, dense_rank() over (
		partition by customer_id
        order by order_date desc
		) as date_rank
    from 
		sales as sal
			join 
		members as mem on sal.customer_id = mem.customer_id
			join 
		menu as men on men.product_id = sal.product_id
    where 
		(order_date < mem.join_date) or (order_date < mem.join_date)
)
select * from cte 
where date_rank = 1;

-- 8. What is the total items and amount spent for each member before they became a member?
with cte as (
	select 
		sal.customer_id, sal.order_date, men.product_name, men.price,dense_rank () over (
			partition by customer_id
			order by sal.order_date desc 
		) as date_rank
    from 
		sales as sal
			join 
		menu as men on sal.product_id = men.product_id
			join 
		members as mem on sal.customer_id = mem.customer_id
    where 
		(sal.order_date < mem.join_date) or (sal.order_date < mem.join_date)
)
select 
	customer_id, count(distinct(product_name)), sum(price) as amount from cte
group by customer_id;

-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

-- First method
with cte as (
	select 
		s.customer_id, sum(10*2*price) as amount
    from 
		sales as s
			join 
		menu as m on s.product_id = m.product_id
    where m.product_name = 'sushi'
    group by customer_id
),
cte1 as (
	select 
		s.customer_id, sum(10*price) as amount
    from 
		sales as s
			join 
		menu as m on s.product_id = m.product_id
    where m.product_name != 'sushi'
	group by customer_id
)
select 
	c1.customer_id, coalesce(c.amount,0) + c1.amount as total_poin 
from 
	cte1 as c1
		left join 
	cte as c on c1.customer_id = c.customer_id;

-- Second method
with cte as (
	select 
		s.customer_id, 
		case
			when m.product_name = 'sushi' then m.price * 20
			else m.price * 10
		end as poin
	from 
		sales as s
			join 
		menu as m on s.product_id = m.product_id
)
select 
	customer_id, sum(poin) as total_poin
from 
	cte
group by customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi — how many points do customer A and B have at the end of January?
with customer_date as (
	select 
		m.customer_id, m.join_date, date_add(m.join_date, interval 6 day) as after_one_week, last_day(m.join_date) as last_day
    from 
		members as m
),
my_table as (
	select 
		s.customer_id, m.product_name, s.order_date, c.join_date, c.after_one_week, m.price, c.last_day
    from 
		sales as s
			join 
		customer_date as c on s.customer_id = c.customer_id
			join 
		menu as m on m.product_id = s.product_id
),
final_table as (
	select 
		my.customer_id,
		sum(case
			when my.order_date between my.join_date and my.after_one_week then 20*my.price
			when my.product_name = 'sushi' then 20*my.price
			else 10*my.price
		end) as total_points
	from 
		my_table as my
    where my.order_date < my.last_day
	group by customer_id
)
select 
	* 
from 
	final_table;

--- BONUS ---
-- Join All The Things
-- Recreate the table with: customer_id, order_date, product_name, price, member (Y/N)
with all_table as (
	select 
		s.customer_id, s.order_date, m.product_name, m.price, 
			case
				when s.order_date < mem.join_date then 'N'
				else 'Y'
			end as is_member
    from 
		sales as s
			join 
		menu as m on s.product_id = m.product_id
			join 
		members as mem on s.customer_id = mem.customer_id
    order by customer_id, order_date
),
-- Rank All The Things
-- Recreate the table with: customer_id, order_date, product_name, price, member (Y/N), ranking(null/123)
rank_table as (
	select *, 
    case
		when is_member = 'N' then null
        else dense_rank() over (partition by customer_id, is_member order by order_date)
	end as ranking
    from 
		all_table
)
select 
	* 
from 
	all_table;
