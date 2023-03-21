-- Cleaning --
drop temporary table if exists temp_customer_orders;
create temporary table temp_customer_orders as
select order_id, customer_id, pizza_id,
	case
		when exclusions  = '' then null
        else exclusions
        end as exclusions,
	case
		when extras = '' then null
        else extras
        end as extras, order_time
from customer_orders;

select * from temp_customer_orders;

drop temporary table if exists temp_runner_orders;
create temporary table temp_runner_orders as
	select order_id, runner_id, pickup_time,
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
	from runner_orders;
    
alter table temp_runner_orders 
modify pickup_time datetime,
modify distance_km float,
modify duration_minutes int;

select * from customer_orders;
select * from temp_runner_orders;


-- A. Pizza Metrics --
-- IMPORTANT!!, here I change ordered to delivered
-- 1. How many pizzas were delivered?
select count(pizza_id) as pizza_ordered
from customer_orders as c
join temp_runner_orders as tro
on c.order_id = tro.order_id
where tro.cancellation is null;

-- 2. How many unique customer orders were made?
select count(distinct(order_id)) as unique_customer from customer_orders;

-- 3. How many successful orders were delivered by each runner?
select runner_id, count(order_id)  as ordered_sucess 
from temp_runner_orders
where cancellation is null
group by runner_id;

-- 4. How many of each type of pizza was delivered?
select pizza_id, count(c.order_id) as delivered_success from customer_orders as c
join temp_runner_orders as tro
on c.order_id = tro.order_id
where tro.cancellation is null
group by c.pizza_id;

-- 5. How many Vegetarian and Meatlovers were delivered by each customer?
select c.customer_id, p.pizza_name, count(p.pizza_name) as order_count from customer_orders as c
join pizza_names as p
on c.pizza_id = p.pizza_id
join temp_runner_orders as tro
on tro.order_id = c.order_id
where tro.cancellation is null 
group by c.customer_id, p.pizza_name
order by c.customer_id;

-- 6. What was the maximum number of pizzas delivered in a single order?
select count(c.order_id) as max_single_order from customer_orders as c
join temp_runner_orders as tro
on c.order_id = tro.order_id
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
from temp_customer_orders as tco
join temp_runner_orders as tro
on tco.order_id = tro.order_id
where tro.cancellation is null
group by customer_id
)
select * from pizza_change;
-- 8. How many pizzas were delivered that had both exclusions and extras?
with cte1 as (
select customer_id, 
	sum(case
			when exclusions is not null and extras is not null then 1
            else 0
		end ) as exclusions_and_extras
from temp_customer_orders as tco
join temp_runner_orders as tro
on tco.order_id = tro.order_id
where tro.cancellation is null
group by customer_id)
select sum(exclusions_and_extras) from cte1;

-- 9. What was the total volume of pizzas delivered for each hour of the day?
select hour(order_time) as hour_of_day, count(hour(order_time)) as deliver_count
from customer_orders as c
join temp_runner_orders as tro
on c.order_id = tro.order_id
where cancellation is null
group by hour(order_time)
order by hour_of_day;

-- 10. What was the volume of delivers for each day of the week?
select dayname(order_time) as day_of_week, count(dayname(order_time)) as deliver_count
from customer_orders as c
join temp_runner_orders as tro
on c.order_id = tro.order_id
group by dayname(order_time);

-- B. Runner and Customer Experience ---
-- 1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
select week(registration_date) as on_week, count(runner_id) as sign_up
from runners
group by on_week;

-- 2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
with diff_pick_order as (
	select tro.runner_id, c.order_id, c.customer_id, timestampdiff(minute, c.order_time, tro.pickup_time) as time_to_pick
    from customer_orders as c
    join temp_runner_orders as tro
    on c.order_id = tro.order_id
    where tro.cancellation is null
    group by time_to_pick, tro.runner_id, c.order_id, c.customer_id
) 
select runner_id, avg(time_to_pick) as avg_time_to_pick
from diff_pick_order
group by runner_id; 

-- 3. Is there any relationship between the number of pizzas and how long the order takes to prepare?
with cte as (
	select c.order_id, count(c.order_id) as num_of_pizza, timestampdiff(minute, c.order_time, tro.pickup_time) as time_to_pick
    from customer_orders as c
    join temp_runner_orders as tro
    on c.order_id = tro.order_id
    where tro.cancellation is null
    group by c.order_id, time_to_pick
)
select num_of_pizza, avg(time_to_pick) as avg_time_to_pick_mins from cte
group by num_of_pizza;

-- 4. What was the average distance travelled for each customer?
with cte as (
	select c.customer_id, tro.distance_km
	from customer_orders as c
	join temp_runner_orders as tro
	on c.order_id = tro.order_id
    where tro.distance_km is not null
)
select customer_id, avg(distance_km) 
from cte
group by customer_id;

-- 5. What was the difference between the longest and shortest delivery times for all orders?
select max(duration_minutes) - min(duration_minutes) as diff_logest_shorthest
from temp_runner_orders;

-- 6. What was the average speed for each runner for each delivery and do you notice any trend for these values?
-- a. for each runner each order
select runner_id, order_id, (distance_km)/(duration_minutes/60) as speed_km_per_hours 
from temp_runner_orders
where cancellation is null;
-- b. for each runner
select runner_id, avg(distance_km/(duration_minutes/60)) as avg_speed
from temp_runner_orders
where cancellation is null
group by runner_id;

-- 7. What is the successful delivery percentage for each runner?
select runner_id, 
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
from temp_runner_orders
group by runner_id;
