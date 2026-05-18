with visitors_with_leads as (
    select
        s.visitor_id,
        s.visit_date,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        lower(s.source) as utm_source,
        row_number() over (
            partition by s.visitor_id
            order by s.visit_date desc
        ) as rn
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where s.medium != 'organic'
),

aggregated_data as (
    select
        utm_source,
        utm_medium,
        utm_campaign,
        date(visit_date) as visit_date,
        count(visitor_id) as visitors_count,
        count(
            case
                when created_at is not null then visitor_id
            end
        ) as leads_count,
        count(case when status_id = 142 then visitor_id end) as purchases_count,
        sum(case when status_id = 142 then amount end) as revenue
    from visitors_with_leads
    where rn = 1
    group by 1, 2, 3, 4
),

marketing_data as (
    select
        date(campaign_date) as visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from ya_ads
    group by 1, 2, 3, 4
    union all
    select
        date(campaign_date) as visit_date,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from vk_ads
    group by 1, 2, 3, 4
)

select
    a.utm_source,
    to_char(a.visit_date, 'MM') as month1,
    to_char(a.visit_date, 'YYYY') as year1,
    sum(a.visitors_count) as visitors_count,
    sum(m.total_cost) as total_cost,
    sum(a.leads_count) as leads_count,
    sum(a.purchases_count) as purchases_count,
    round((sum(a.leads_count) * 100 / sum(nullif(a.visitors_count, 0))), 2)
        as cr1,
    round((sum(a.purchases_count) * 100 / sum(nullif(a.leads_count, 0))), 2)
        as cr2,
    sum(a.revenue) as revenue,
    round((sum(a.revenue) / sum(nullif(a.purchases_count, 0))), 2) as aov,
    round((sum(m.total_cost) / sum(a.visitors_count)), 2) as cpu,
    round((sum(m.total_cost) / sum(a.leads_count)), 2) as cpl,
    round((sum(m.total_cost) / sum(a.purchases_count)), 2) as cppu,
    round((sum(a.revenue) - sum(m.total_cost)) * 100 / sum(m.total_cost), 2)
        as roi
from aggregated_data as a
left join marketing_data as m
    on
        a.visit_date = m.visit_date
        and lower(a.utm_source) = m.utm_source
        and lower(a.utm_medium) = m.utm_medium
        and lower(a.utm_campaign) = m.utm_campaign
-- важный фильтр, иначе подтягиваются визиты, 
--лиды без расходов и искажают основные метрики        
where total_cost is not null
group by 1, 2, 3
order by 15 desc;
