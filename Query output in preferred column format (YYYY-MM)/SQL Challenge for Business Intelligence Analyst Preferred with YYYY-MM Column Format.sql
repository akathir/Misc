/*
Creator - Annamalai Kathir(AK)
Date - 1/3/2021
Title - Challenge for Business Intelligence Analyst 
Link - https://www.notion.so/Challenge-for-98089dfacedc40bdb5f7c47500297af6
Tool used - SQL Server Management Studio version 15.0.18183.0 (SQl Server 14.0.2027)
How to run it -
	Step 1 - Create table Transfers with the following columns and datatypes
				[id] varchar(50)
				[total] decimal(10,2)
				[customerId] varchar(50)
				[createdAt] varchar (50)
	Step 2 - Open a new query -> paste this query -> connect to the database
	Step 3 - There are two user inputs in this query. 
	Step 3.1 - First one is to enter the @table_name
	Step 3.2 - second one is to specify the @retention_calculation_monthly_metric. It can be either -
				- retention_unique_users_cohorts - Retention based on customers who have completed their successful transfers every month (or)
				- retention_session_cohorts - Retention rate based on number of sessions (or) 
				- retention_revenue_cohorts - Retention rate based on the revenue each cohort produces in each month

Note - The columns are join_date, 2019-12, 2020-01,..., 2020-10
*/


--Delete views if exists
drop view if exists transfers_age_table;
drop view if exists transfers_age_table_unique_users;
drop view if exists distinct_months;
drop view if exists retention_unique_users_cohorts;
drop view if exists retention_session_cohorts;
drop view if exists retention_revenue_cohorts;

--#################### User Input ########################
--Change @table_name
declare @table_name varchar(10) = 'tx',
		@transfers_age_table varchar(max);

--Create views
set @transfers_age_table = ' 
							create view transfers_age_table as
								with by_month as
									(select customerid, total, left(CONVERT(date,createdat, 127),7) as cdate
									from '+@table_name+')
								select customerid, total, cdate, left(FIRST_VALUE(cdate) over (partition by customerid order by cdate),7) as join_date
								from by_month
						  '
execute(@transfers_age_table);
GO
--Unique users grouped by customerid and createdAt
create view transfers_age_table_unique_users as
	select min(customerid) customerid, min(cdate) cdate, min(join_date) join_date
	from transfers_age_table
	group by (customerid + ' ' + cdate)
GO
create view distinct_months as
	select (select ',' + quotename(cdate)
	from transfers_age_table_unique_users
	group by cdate
	order by cdate FOR XML PATH('')) as months;
GO

--#################### User Input ########################
--@retention_calculation_monthly_metric can be either - retention_unique_users_cohorts (or) retention_session_cohorts (or) retention_revenue_cohorts
declare @retention_calculation_monthly_metric varchar(max) = 'retention_unique_users_cohorts';

declare @months_list as nvarchar(max),
		@retention_unique_users_cohorts as nvarchar(max),
		@retention_session_cohorts varchar(max),
		@retention_revenue_cohorts varchar(max);

--used to remove extra , in front of the string from quotename
select @months_list = stuff(months,1,1,'') from distinct_months;

set @retention_unique_users_cohorts = ' 
									   create view retention_unique_users_cohorts as
										  select *
										  from 
											(select customerid, join_date, cdate
											from transfers_age_table_unique_users) t1
										  pivot
											(count(customerid)
											for cdate
											in (' + @months_list + ')
											) as cohorts;	  
									 '
execute(@retention_unique_users_cohorts);

set @retention_session_cohorts = ' 
								   create view retention_session_cohorts as
									  select *
									  from 
										(select customerid, join_date, cdate
										from transfers_age_table) t1
									  pivot
										(count(customerid)
										for cdate
										in (' + @months_list + ')
										) as cohorts;	  
								'
execute(@retention_session_cohorts);

set @retention_revenue_cohorts = ' 
								   create view retention_revenue_cohorts as
									  select *
									  from 
										(select total, join_date, cdate
										from transfers_age_table) t1
									  pivot
										(sum(total)
										for cdate
										in (' + @months_list + ')
										) as cohorts;	  
							     '
execute(@retention_revenue_cohorts);

--Execute query
declare @cohorts as nvarchar(max);

set @cohorts = '
						 select *
						 from '+ @retention_calculation_monthly_metric +'
						 order by join_date;	  
			   '
execute(@cohorts);
GO

