-- 1. Jumlah employee 'M' dan 'F' yang bekerja pada tiap tahun
select 
	year(from_date) as tahun, gender, count(d.emp_no) as number_of_employees
from 
	t_dept_emp as d
		join 
    t_employees as e on d.emp_no = e.emp_no
group by tahun, gender
having tahun >= 1990
order by tahun;

-- 2. Jumlah employee 'M' dan 'F' pada tiap departement
select 
	dept.dept_name as departement_name, e.gender, count(e.emp_no) as number_of_employess
from 
	t_employees as e
		join 
    t_dept_emp as demp on e.emp_no = demp.emp_no
		join 
	t_departments as dept on demp.dept_no = dept.dept_no
group by departement_name, gender
order by departement_name;

-- 3. Jumlah manager 'M' dan 'F' pada tiap departement di tiap tahun

drop temporary table if exists daftar_tahun;
create temporary table daftar_tahun as
select 
	year(hire_date) as tahun 
from 
	t_employees
group by tahun
order by tahun;

with cte as (
	select 
		dept.dept_name, e.gender, demp.emp_no, demp.from_date, demp.to_date, dt.tahun,
		case
			when year(demp.from_date) <= dt.tahun and dt.tahun <= year(demp.to_date) then 1
			else 0
		end as is_active
	from 
		t_employees as e cross join daftar_tahun as dt
			join 
		t_dept_manager as demp on e.emp_no = demp.emp_no
			join 
		t_departments as dept on dept.dept_no = demp.dept_no
	order by emp_no, tahun
)

select 
	gender, tahun, sum(is_active)
from 
	cte 
group by tahun, gender
order by tahun;

-- 4. Rata-rata gaji employee 'M' dan 'F' pertahun pada tiap departement
select 
	year(s.from_date) as tahun, dept.dept_name, e.gender, round(avg(s.salary), 2) as avg_salary
from 
	t_salaries as s 
		join 
	t_employees as e on e.emp_no = s.emp_no
		join 
	t_dept_emp as demp on demp.emp_no = e.emp_no
		join 
	t_departments as dept on dept.dept_no = demp.dept_no
group by e.gender, dept.dept_name, tahun
having tahun <= 2002
order by dept_name, tahun;

-- 5. Rata-rata gaji 'M' dan 'F' pada tiap departement
delimiter $$
create procedure avg_between (in min_salary float, in max_salary float)
begin
select
    e.gender, dept.dept_name, avg(s.salary) as avg_salaries
from 
	t_employees as e
		join 
	t_dept_emp as demp on e.emp_no = demp.emp_no
		join 
	t_departments as dept on demp.dept_no = dept.dept_no
		join 
    t_salaries as s on s.emp_no = e.emp_no
	where s.salary between min_salary and max_salary
group by e.gender, dept.dept_name;
end$$
call avg_between(50000, 90000)