--модель  Last Paid или click по последней дате
WITH last_click AS (
    SELECT DISTINCT ON (visitor_id) *
    FROM sessions
    WHERE medium <> 'organic'
    ORDER BY visitor_id ASC, visit_date DESC
),

-- 2 запрос групировка по дате и join c leads
group_by_date AS (
    SELECT
        la.source AS utm_source,
        la.medium AS utm_medium,
        la.campaign AS utm_campaign,
        la.content AS utm_content,
        date(la.visit_date) AS visit_date,
        count(la.visitor_id) AS visitors_count,
        count(l.lead_id) AS leads_count,
        count(l.lead_id) FILTER (WHERE l.closing_reason = 'Успешная продажа')
            AS purchases_count,
        sum(l.amount) AS revenue
    FROM last_click AS la
    LEFT JOIN leads AS l ON la.visitor_id = l.visitor_id
    GROUP BY date(la.visit_date), la.source, la.medium, la.campaign, la.content
    ORDER BY revenue DESC NULLS LAST, date(la.visit_date) ASC
),

-- 3 запрос (не связан с двумя выше) сложил vk и ya и сгруппировал по 4 полям
union_vk_ya AS (
    SELECT
        utm_source,
        utm_medium,
        utm_campaign,
        utm_content,
        sum(daily_spent) AS daily_spent
    FROM (
        SELECT
            utm_source,
            utm_medium,
            utm_campaign,
            utm_content,
            daily_spent
        FROM vk_ads
        UNION ALL
        SELECT
            utm_source,
            utm_medium,
            utm_campaign,
            utm_content,
            daily_spent
        FROM ya_ads
    )
    GROUP BY utm_source, utm_medium, utm_campaign, utm_content
)

-- 4 запрос (join c union (vk+ya))
SELECT
    gr.visit_date,
    gr.utm_source,
    gr.utm_medium,
    gr.utm_campaign,
    sum(gr.visitors_count) AS visitors_count,
    sum(un.daily_spent) AS total_cost,
    sum(gr.leads_count) AS leads_count,
    sum(gr.purchases_count) AS purchases_count,
    sum(gr.revenue) AS revenue
FROM group_by_date AS gr
LEFT JOIN union_vk_ya AS un
    ON
        gr.utm_source = un.utm_source
        AND gr.utm_medium = un.utm_medium
        AND gr.utm_campaign = un.utm_campaign
        AND gr.utm_content = un.utm_content
GROUP BY
    gr.visit_date, gr.utm_source, gr.utm_medium, gr.utm_campaign
ORDER BY
    revenue DESC NULLS LAST, gr.visit_date ASC, visitors_count DESC,
    gr.utm_source ASC, gr.utm_medium ASC, gr.utm_campaign ASC;
