-- Cleaning --
-- alter table customer_orders 
-- add record_id int auto_increment primary key;
drop temporary table if exists temp_customer_orders;
create temporary table temp_customer_orders as
select 
	order_id, customer_id, pizza_id,
		case
			when exclusions  = '' then null
			else exclusions
        end as exclusions,
		case
			when extras = '' then null
			else extras
        end as extras, order_time, record_id
from 
	customer_orders;

select 
	* 
from 
	temp_customer_orders;

drop temporary table if exists temp_runner_orders;
create temporary table temp_runner_orders as
	select 
		order_id, runner_id, pickup_time,
			case
				when distance like '%km%' then trim(trailing 'km' from distance)
				else distance
			end as distance_km,
			case
				when duration like '%minutes%' then trim(trailing 'minutes' from duration)
				when duration like '%mins%' then trim(trailing 'mins' from duration)
				when duration like '%minute%' then trim(trailing 'minute' from duration)
				else duration
				end as duration_minutes, 
			case 
				when cancellation = '' then null
				else cancellation
				end as cancellation
	from 
		runner_orders;
    
alter table temp_runner_orders 
modify pickup_time datetime,
modify distance_km float,
modify duration_minutes int;

select 
	* 
from 
	customer_orders;
    
select 
	* 
from 
	temp_runner_orders;


-- A. Pizza Metrics --
-- IMPORTANT!!, here I change ordered to delivered
-- 1. How many pizzas were delivered?
select 
	count(pizza_id) as pizza_ordered
from 
	customer_orders as c
		join
	temp_runner_orders as tro on c.order_id = tro.order_id
where tro.cancellation is null;

-- 2. How many unique customer orders were made?
select 
	count(distinct(order_id)) as unique_customer 
from 
	customer_orders;

-- 3. How many successful orders were delivered by each runner?
select 
	runner_id, count(order_id)  as ordered_sucess 
from 
	temp_runner_orders
where cancellation is null
group by runner_id;

-- 4. How many of each type of pizza was delivered?
select 
	pizza_id, count(c.order_id) as delivered_success 
from 
	customer_orders as c
		join 
	temp_runner_orders as tro on c.order_id = tro.order_id
where tro.cancellation is null
group by c.pizza_id;

-- 5. How many Vegetarian and Meatlovers were delivered by each customer?
select 
	c.customer_id, p.pizza_name, count(p.pizza_name) as order_count 
from 
	customer_orders as c
		join 
	pizza_names as p on c.pizza_id = p.pizza_id
		join 
	temp_runner_orders as tro on tro.order_id = c.order_id
where tro.cancellation is null 
group by c.customer_id, p.pizza_name
order by c.customer_id;

-- 6. What was the maximum number of pizzas delivered in a single order?
select 
	count(c.order_id) as max_single_order 
from 
	customer_orders as c
		join 
	temp_runner_orders as tro on c.order_id = tro.order_id
where tro.cancellation is null
group by c.order_id
order by max_single_order desc
limit 1;

-- 7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
with pizza_change as(
	select customer_id, 
		sum(case
				when exclusions is not null or extras is not null then 1
				else 0
		end ) as at_least_1_change,
		sum(case
				when exclusions is null and extras is null then 1
				else 0
		end ) as no_change
from 
	temp_customer_orders as tco
		join 
temp_runner_orders as tro on tco.order_id = tro.order_id
where tro.cancellation is null
group by customer_id
)
select 
	* 
from 
	pizza_change;
-- 8. How many pizzas were delivered that had both exclusions and extras?
with cte1 as (
	select customer_id, 
		sum(case
			when exclusions is not null and extras is not null then 1
            else 0
		end ) as exclusions_and_extras
from 
	temp_customer_orders as tco
join 
	temp_runner_orders as tro on tco.order_id = tro.order_id
where tro.cancellation is null
group by customer_id)
select 
	sum(exclusions_and_extras) 
from 
	cte1;

-- 9. What was the total volume of pizzas delivered for each hour of the day?
select 
	hour(order_time) as hour_of_day, count(hour(order_time)) as deliver_count
from 
	customer_orders as c
		join 
	temp_runner_orders as tro on c.order_id = tro.order_id
where cancellation is null
group by hour(order_time)
order by hour_of_day;

-- 10. What was the volume of delivers for each day of the week?
select 
	dayname(order_time) as day_of_week, count(dayname(order_time)) as deliver_count
from 	
	customer_orders as c
		join 
	temp_runner_orders as tro on c.order_id = tro.order_id
group by dayname(order_time);

-- B. Runner and Customer Experience ---
-- 1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
select 
	week(registration_date) as on_week, count(runner_id) as sign_up
from 
	runners
group by on_week;

-- 2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
with diff_pick_order as (
	select 
		tro.runner_id, c.order_id, c.customer_id, timestampdiff(minute, c.order_time, tro.pickup_time) as time_to_pick
    from 
		customer_orders as c
			join 
		temp_runner_orders as tro on c.order_id = tro.order_id
    where tro.cancellation is null
    group by time_to_pick, tro.runner_id, c.order_id, c.customer_id
) 
select 
	runner_id, avg(time_to_pick) as avg_time_to_pick
from 
	diff_pick_order
group by runner_id; 

-- 3. Is there any relationship between the number of pizzas and how long the order takes to prepare?
with cte as (
	select 
		c.order_id, count(c.order_id) as num_of_pizza, timestampdiff(minute, c.order_time, tro.pickup_time) as time_to_pick
    from 
		customer_orders as c
			join 
		temp_runner_orders as tro on c.order_id = tro.order_id
    where tro.cancellation is null
    group by c.order_id, time_to_pick
)
select 
	num_of_pizza, avg(time_to_pick) as avg_time_to_pick_mins 
from 
	cte
group by num_of_pizza;

-- 4. What was the average distance travelled for each customer?
with cte as (
	select 
		c.customer_id, tro.distance_km
	from 
		customer_orders as c
			join 
		temp_runner_orders as tro on c.order_id = tro.order_id
    where tro.distance_km is not null
)
select 
	customer_id, avg(distance_km) 
from 
	cte
group by customer_id;

-- 5. What was the difference between the longest and shortest delivery times for all orders?
select 
	max(duration_minutes) - min(duration_minutes) as diff_logest_shorthest
from 
	temp_runner_orders;

-- 6. What was the average speed for each runner for each delivery and do you notice any trend for these values?
-- a. for each runner each order
select 
	runner_id, order_id, (distance_km)/(duration_minutes/60) as speed_km_per_hours 
from 
	temp_runner_orders
where cancellation is null;
-- b. for each runner
select
	runner_id, avg(distance_km/(duration_minutes/60)) as avg_speed
from 
	temp_runner_orders
where cancellation is null
group by runner_id;

-- 7. What is the successful delivery percentage for each runner?
select 
	runner_id, 
	sum(
		case
			when cancellation is null then 1
			else 0
		end) /
	count(
    case
			when cancellation is null then 1
			else 0
		end
    ) as percentage
from 
	temp_runner_orders
group by runner_id;

-- C. Ingredient Optimisation
-- Preprocessing data (please look at my python code on repo)
drop table if exists pizza_recipes_norm;
create table pizza_recipes_norm (
	pizza_id int not null,
    topping_id int not null
);
load data infile 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/pizza_recipes_cleaned.csv'
into table pizza_recipes_norm
fields terminated by ','
enclosed by '"'
lines terminated by '\n'
ignore 1 rows;

select * from pizza_recipes_norm;
-- 1. What are the standard ingredients for each pizza?
select 
	pn.pizza_name, pt.topping_name
from
	pizza_names as pn
		join
	pizza_recipes_norm as prn on pn.pizza_id = prn.pizza_id
		join
	pizza_toppings as pt on pt.topping_id = prn.topping_id;

-- 2. What was the most commonly added extra?
drop table if exists extras_cleaned;
create table extras_cleaned (
	order_id int not null,
    extras int,
    record_id int not null
);
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/extras_cleaned.csv'
INTO TABLE extras_cleaned
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

select 
	pt.topping_name, count(ex.extras)
from
	extras_cleaned as ex 
		join
	pizza_toppings as pt on ex.extras = pt.topping_id
group by pt.topping_name;

-- 3. What was the most common exclusion?
drop table if exists exclusions_cleaned;
create table exclusions_cleaned (
	order_id int not null,
    exclusions int,
    record_id int not null
);
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/exclusions_cleaned.csv'
INTO TABLE exclusions_cleaned
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

select 
	pt.topping_name, count(exc.exclusions) as amount
from 
	pizza_toppings as pt
		join
	exclusions_cleaned as exc on pt.topping_id = exc.exclusions
group by pt.topping_name
order by amount desc;

-- 4. 
-- Generate an order item for each record in the customers_orders table in the format of one of the following:
-- Meat Lovers
-- Meat Lovers - Exclude Beef
-- Meat Lovers - Extra Bacon
-- Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers
drop temporary table if exists resep_pizza;
create temporary table resep_pizza as
select 
	pn.pizza_id, pn.topping_id, pt.topping_name 
from 
	pizza_recipes_norm as pn
		join 
	pizza_toppings as pt on pt.topping_id = pn.topping_id;

with extras_cte as (
	select ex.record_id, concat('Extra ', group_concat(r.topping_name separator',')) as record_options
	from extras_cleaned as ex 
	join pizza_toppings as r on ex.extras = r.topping_id
	group by record_id
),
exclusions_cte as (
	select ex.record_id, concat('Exclude ', group_concat(r.topping_name separator ' ,')) as record_options
    from exclusions_cleaned as ex
    join pizza_toppings as r on ex.exclusions = r.topping_id
    group by record_id
),
extras_exclude as (
	select * from extras_cte
    union
    select * from exclusions_cte
)
select tco.record_id, concat_ws(' - ', p.pizza_name, group_concat(ex.record_options separator ' - ')) as orders
from temp_customer_orders as tco
join pizza_names as p on p.pizza_id = tco.pizza_id
join extras_exclude as ex on ex.record_id = tco.record_id
group by record_id, p.pizza_name
order by record_id;
-- 5. What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?
with cte1 as (
	select tco.record_id, tco.pizza_id, r.topping_id, r.topping_name,
    case
		when topping_id in (select topping_id from resep_pizza as res where res.pizza_id = tco.pizza_id) then 1
        else 0
	end as jumlah,
    case
		when r.topping_id in (select extras from extras_cleaned as ext where ext.record_id = tco.record_id) then 1
        when r.topping_id in (select exclusions from exclusions_cleaned as exc where exc.record_id = tco.record_id) then -1
        else 0
	end as ubah
	from temp_customer_orders tco
	cross join pizza_toppings r 
	order by record_id, r.topping_id
)
select topping_name, sum(jumlah+ubah)as amount from cte1
group by topping_name
order by amount desc;

-- D. Pricing and Ratings
-- 1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - 
-- how much money has Pizza Runner made so far if there are no delivery fees?
select sum(
	case
		when pizza_id = 1 then 12
        when pizza_id = 2 then 10
        end
) as jumlah
from temp_customer_orders tco
join temp_runner_orders tro on tro.order_id = tco.order_id
where tro.cancellation is null;

-- 2. What if there was an additional $1 charge for any pizza extras? Add cheese is $1 extra
select count(ex.extras) + 138 as amount from temp_customer_orders tco
join temp_runner_orders tro on tro.order_id = tco.order_id
join extras_cleaned as ex on ex.order_id = tco.order_id
where tco.extras is not null and tro.cancellation is null;

-- 3. The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, 
-- how would you design an additional table for this new dataset - 
-- generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5.
drop table if exists runner_ratings;
create table runner_ratings (
    order_id int not null,
    ratings int
);
insert into runner_ratings (order_id, ratings)
values 
(1,5),
(2,2),
(3,4),
(4,4),
(5,3),
(7,4),
(8,3),
(10,5);

-- 4. Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries?
-- customer_id
-- order_id
-- runner_id
-- rating
-- order_time
-- pickup_time
-- Time between order and pickup
-- Delivery duration
-- Average speed
-- Total number of pizzas
select tco.customer_id, r.order_id, r.ratings, tro.runner_id, tco.order_time, tro.pickup_time, timediff(tro.pickup_time, tco.order_time) as diff,
tro.duration_minutes, round((tro.distance_km*1000 / (tro.duration_minutes*60)), 1) as avg_speed_m_per_s, count(tco.pizza_id)
from temp_customer_orders tco
join temp_runner_orders tro on tco.order_id = tro.order_id
join runner_ratings r on r.order_id = tro.order_id
group by r.order_id, tco.customer_id, r.ratings, r.ratings, tro.runner_id, tco.order_time, tro.pickup_time, diff, tro.duration_minutes, avg_speed_m_per_s
order by tco.customer_id;
select * from temp_customer_orders;

-- 5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre 
-- traveled - how much money does Pizza Runner get?
with cte as (
	select tco.record_id, tco.pizza_id,
    case
		when tco.pizza_id = 1 then 12
        when tco.pizza_id = 2 then 10
	end as harga_per_pizza,
    tro.distance_km, round((tro.distance_km * 0.3),1) as biaya_pengiriman
    from temp_customer_orders tco
    join temp_runner_orders tro on tco.order_id = tro.order_id
    where tro.cancellation is null
)
select sum(harga_per_pizza) + sum(biaya_pengiriman) as pendapatan from cte;