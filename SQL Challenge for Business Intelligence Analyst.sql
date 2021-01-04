/*
Creator - Annamalai Kathir(AK)
Date - 1/3/2021
Title - Challenge for Business Intelligence Analyst 
Link - https://www.notion.so/Challenge-for-98089dfacedc40bdb5f7c47500297af6
Note - Replace "transfers_table_user_input" with your table name
*/

--Create views
create view customer_age_table as
	with by_month as
		(select customerid, CONVERT(date,createdat, 127) as cdate
		from transfers_table_user_input),
	 first_month as
		(select customerid, cdate, FIRST_VALUE(cdate) over (partition by customerid order by cdate) as join_date
		from by_month)
	 select customerid, left(join_date,7) join_date, floor(datediff(day,join_date,cdate)/30) as age_in_month
	 from first_month;

GO

create view distinct_months as
	select (select ',' + quotename(age_in_month)
	from customer_age_table
	group by age_in_month
	order by age_in_month FOR XML PATH('')) as months;

GO

declare @months_list as nvarchar(max),
		@retention_cohorts varchar(max);

--used to remove extra , in front of the string from quotename
select @months_list = stuff(months,1,1,'') from distinct_months;

set @retention_cohorts = ' 
					       create view retention_cohorts as
							  select *
							  from 
								(select customerid, join_date, age_in_month
								from customer_age_table) t1
							  pivot
								(count(customerid)
								for age_in_month
								in (' + @months_list + ')
								) as cohorts;	  
					     '
execute(@retention_cohorts);

GO

--Execute queries
declare @dynamic_sql_months varchar(max) = '',
		@cohorts_by_users as nvarchar(max),
		@cohorts_by_percent as nvarchar(max);

select @dynamic_sql_months = @dynamic_sql_months + ', str(("' + trim(str(age_in_month)) + '"*100)/"0") + ''%'' as "' + trim(str(age_in_month)) + '"'
from customer_age_table
group by age_in_month
order by age_in_month;

set @cohorts_by_users = '
						 select *
						 from retention_cohorts
						 order by join_date;	  
						'
execute(@cohorts_by_users);

set @cohorts_by_percent = '	  	
						   select join_date, ' + stuff(@dynamic_sql_months,1,1,'') + ' 
						   from retention_cohorts 
						   order by join_date;
						  '
execute(@cohorts_by_percent);

GO

--Delete views
drop view if exists customer_age_table;
drop view if exists distinct_months;
drop view if exists retention_cohorts;
