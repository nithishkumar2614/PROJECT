create database apple
--to view the data

select top 1* from stores
select top 1* from products
select top 1* from category
select top 1* from sales
select top 1* from warranty

---Explaratory data analysis

select distinct store_name from stores
select distinct product_name from products
select distinct category_name from category
select distinct repair_status from warranty
select count(*) from sales

--Business Problems

--1.Find number of stores in each country?

select count(store_id)[Total stores],country from stores
group by country
order by count(store_id) desc

--2.Calculate the total number of units sold by each store?

select store_name,sum(quantity)[Total no of units sold] from stores s1
join sales s2 on s1.Store_ID=s2.store_id
group by store_name
order by sum(quantity) desc

--3.Identify how many sales occurred in December 2023?

select count(*) from sales
where year(sale_date)=2023 and month(sale_date)=12


--4.Determine how many stores have never had a warranty claim filed?

select count(*) from stores
where store_id not in (select distinct store_id from sales s1
              right join warranty w on s1.sale_id=w.sale_id)

			  
--5.Calcutate th percentage of warranty claims marked as "Rejected" ?
select * from warranty

select ((count(*)*100)/(select count(*) from warranty)) as percentage_war from warranty
where repair_status='rejected'
          
--6.Identify which store had the highest total units sold in the last year.
--select max(sale_date) from sales


select  top 1 store_name ,  sum(quantity)[total units sold] from stores s1
join sales s2 on s1.Store_ID=s2.store_id
where sale_date>= (select dateadd(year,-1,max(sale_date)) from sales) 
group by store_name
order by sum(quantity)  desc

--7.Count the number of unique products sold in the last year.

select count(distinct product_id) from sales
where sale_date>=(select dateadd(year,-1,max(sale_date)) from sales) 

--8.Find the average price of products in each category.

select c.category_id,c.category_name,avg(price)[average_price] from products p
join category c on p.Category_ID=c.category_id
group by c.Category_name,c.category_id
order by avg(price) desc

--9.How many warranty claims were filed in 2024?

select count(*) from warranty
where year(claim_date)= 2024


--10.For each store, identify the best-selling day based on highest quantity sold.
select * from
(
select store_id,
       day(sale_date)[best sale day],
	   sum(quantity)[quantity sold] ,
       rank() over(partition by store_id order by sum(quantity) desc) as rank
       from sales
       group by sale_date,store_id
) as A

where rank=1
order by [quantity sold] desc


--11.Identify the least selling product in each country for each year based on total units sold.
select * from(
select p.product_name,
       year(sale_date)[year],
	   sum(quantity)[totalunitssold],
	   country,
	   dense_rank() over(partition by year(sale_date),country order by sum(quantity))[denserank]
from sales s1
join stores s2 on s1.store_id=s2.Store_ID
join products p on s1.product_id=p.Product_ID
group by year(sale_date),country,p.product_name
) as A
where DENSERANK=1
order by [totalunitssold]


--12.Calculate how many warranty claims were filed within 180 days of a product sale.

select count(*) from warranty w
left join sales s on w.sale_id=s.sale_id
where datediff(day,sale_date,claim_date)<=180


--13.Determin how many warranty claims were filed for products launched in the last two years

select product_name,count(*)[no of claims] from warranty w
left join sales s on w.sale_id=s.sale_id
join products p on s.product_id=p.Product_ID
where launch_date>(select dateadd(year,-2,max(launch_date)) from products)
group by product_name
order by count(*)


--14.List the months in the last three years where sales exceeded units in the USA.

select format(sale_date,'MM-yyyy'),
	   sum(quantity)[no of units]
from sales s1 join stores s2 on s1.store_id=s2.Store_ID
where sale_date>(select dateadd(year,-3,max(sale_date)) from sales s1) and country='United States'
group by format(sale_date,'MM-yyyy')
having sum(quantity)>0
order by sum(quantity)

--15.Identify the product category with the most warranty claims filed in the last two years.

select category_name,count(claim_id) from products p
join category c on p.Category_ID=c.category_id
join sales s on p.Product_ID=s.product_id
left join warranty w on s.sale_id=w.sale_id
where launch_date>(select dateadd(year,-2,max(launch_date)) from products)
group by category_name
order by count(claim_id) desc

--16.determine the percentage chance of receiving warranty claims after each purchase for each country.
select country,
       totalunits,
	   totalcount,
	   (cast(totalcount as float)/cast(totalunits as float))*100[Percentage]
	   from(
select country,sum(quantity)[totalunits],count(claim_id)[totalcount] from warranty w
left join sales s on s.sale_id=w.sale_id
join stores s1 on s.store_id=s1.Store_ID
group by country
) A
order by [Percentage] desc


--17.Analyze the year-by-year growth ratio for each store.
with year_sales as(
select store_name ,
       s2.store_id,
       year(sale_date)[year_sale],
	   sum(s1.quantity*p.price)[Total_sale] 
	   from sales s1
join products p on s1.product_id=p.Product_ID
join stores s2 on s1.store_id=s2.Store_ID
group by store_name,year(sale_date),s2.store_id
),
growth_ratio as(
     select store_name,
	 year_sale,
	 lag(Total_sale,1) over(partition by store_name order by year_sale)[Last_year_sale],
	 Total_sale as current_year_sales
	 from year_sales
	 )

select store_name,
       year_sale,
	   current_year_sales,
	   last_year_sale,
	   round((cast (current_year_sales as float)-cast(last_year_sale as float))/cast (last_year_sale as float)*100,2)[Growthratio]
	   from growth_ratio
	where Last_year_sale is not null


--18.Calculate the correlation between product price and warranty claims for products sold in the last five years, 
--segmented by price range.

select product_name,
       case when price<500 then'Low'
	   when price<1000 then 'Moderate'
	   else 'High' end as price_range,
	   count(claim_id) from products p
join sales s on p.Product_ID=s.product_id
join warranty w on s.sale_id=w.sale_id
where sale_date>  dateadd(year,-5,(select max(sale_date) from sales) )
group by product_name,price

--19.Identify the store with the highest percentage of "Completed" claims relative to total claims filed

with total_claimed as
(
select store_id,
count(*) as total_claims
from warranty w join sales s on w.sale_id=s.sale_id
group by store_id
),

completed_claims  as
(
select store_id,
       sum(case when repair_status='Completed' 
	             then 1 else 0 end ) as total_completed_claims
from warranty w 
join sales s1 on w.sale_id=s1.sale_id
group by store_id)

select c1.store_id,
       c1.total_completed_claims,
	   t.total_claims,
       round((cast(c1.total_completed_claims as float)/cast(t.total_claims as float))*100,2)[Percentage_of_completed_claims]
from completed_claims c1 
join total_claimed t on c1.store_id=t.store_id
          

--20.Write a query to calculate the monthly running total of sales for each store over the past four years and compare trends during this period.

with monthly_sales as(

select store_id,
       month(sale_date)[month],
       sum(price*quantity)[total_sales]
	   from sales s
join products p on s.product_id=p.Product_ID
where sale_date>dateadd(year,-4,(select max(sale_date) from sales))
group by store_id,month(sale_date))

select store_id,
       total_sales,
	   [month],
       sum(total_sales) over(partition by [month] order by total_sales)
	   from monthly_sales






