-- 1. Cohorts with the largest month-on-month adherence decline
WITH x AS (
    SELECT
        month_start,
        primary_risk_cohort,
        age_band,
        funding_type,
        weighted_adherence_rate,
        LAG(weighted_adherence_rate) OVER (
            PARTITION BY primary_risk_cohort, age_band, funding_type
            ORDER BY month_start
        ) AS prior_rate
    FROM clinical_ops.vw_cohort_monthly_kpis
)
SELECT *,
       weighted_adherence_rate - prior_rate AS absolute_change,
       (weighted_adherence_rate - prior_rate) / NULLIF(prior_rate,0) AS relative_change
FROM x
WHERE prior_rate IS NOT NULL
ORDER BY relative_change ASC
LIMIT 20;

-- 2. Dropout rate by demographic and access factors
SELECT
    p.primary_risk_cohort,
    p.gender,
    CASE WHEN p.age < 30 THEN '18-29'
         WHEN p.age < 45 THEN '30-44'
         WHEN p.age < 60 THEN '45-59'
         ELSE '60+' END AS age_band,
    p.funding_type,
    p.transport_mode,
    COUNT(*) AS enrolled_patients,
    COUNT(d.patient_id) AS dropout_patients,
    COUNT(d.patient_id)::NUMERIC / NULLIF(COUNT(*),0) AS dropout_rate
FROM clinical_ops.dim_patient p
LEFT JOIN clinical_ops.vw_dropout_first_event d USING (patient_id)
GROUP BY 1,2,3,4,5
HAVING COUNT(*) >= 5
ORDER BY dropout_rate DESC, enrolled_patients DESC;

-- 3. Identify patients whose 3-month trailing adherence dropped by >= 20 percentage points
WITH x AS (
    SELECT *,
           LAG(trailing_3m_adherence, 1) OVER (
               PARTITION BY patient_id ORDER BY month_start
           ) AS prior_3m
    FROM clinical_ops.vw_patient_adherence_trailing
)
SELECT
    patient_code, month_start, primary_risk_cohort, site,
    prior_3m, trailing_3m_adherence,
    trailing_3m_adherence - prior_3m AS change,
    protocol_status, primary_barrier
FROM x
WHERE prior_3m IS NOT NULL
  AND trailing_3m_adherence - prior_3m <= -0.20
ORDER BY change ASC;
