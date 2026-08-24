CREATE SCHEMA IF NOT EXISTS clinical_ops;

CREATE TABLE IF NOT EXISTS clinical_ops.dim_patient (
    patient_id              BIGINT PRIMARY KEY,
    patient_code            VARCHAR(20) UNIQUE NOT NULL,
    gender                  VARCHAR(20) NOT NULL CHECK (gender IN ('Female','Male','Other','Unknown')),
    age                     SMALLINT NOT NULL CHECK (age BETWEEN 0 AND 120),
    primary_risk_cohort     VARCHAR(40) NOT NULL,
    comorbidity_count       SMALLINT NOT NULL DEFAULT 0 CHECK (comorbidity_count >= 0),
    baseline_risk_score     NUMERIC(5,2) NOT NULL CHECK (baseline_risk_score BETWEEN 0 AND 100),
    site                    VARCHAR(100) NOT NULL,
    funding_type            VARCHAR(50) NOT NULL,
    employment_status       VARCHAR(50),
    transport_mode          VARCHAR(50),
    distance_km             NUMERIC(7,2) CHECK (distance_km >= 0),
    programme_type          VARCHAR(100) NOT NULL,
    enrolment_date          DATE NOT NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS clinical_ops.fact_patient_month (
    patient_id                  BIGINT NOT NULL REFERENCES clinical_ops.dim_patient(patient_id),
    month_start                 DATE NOT NULL,
    sessions_prescribed         SMALLINT NOT NULL CHECK (sessions_prescribed >= 0),
    sessions_attended           SMALLINT NOT NULL CHECK (sessions_attended >= 0),
    monthly_adherence_rate      NUMERIC(7,4) GENERATED ALWAYS AS
        (CASE WHEN sessions_prescribed = 0 THEN NULL
              ELSE sessions_attended::NUMERIC / sessions_prescribed END) STORED,
    cumulative_prescribed       INTEGER NOT NULL CHECK (cumulative_prescribed >= 0),
    cumulative_attended         INTEGER NOT NULL CHECK (cumulative_attended >= 0),
    protocol_status             VARCHAR(30) NOT NULL CHECK (protocol_status IN ('Active','At Risk','Dropped Out','Completed')),
    primary_barrier             VARCHAR(100),
    risk_score                  NUMERIC(5,2) CHECK (risk_score BETWEEN 0 AND 100),
    weight_change_kg            NUMERIC(7,2),
    systolic_bp_change          NUMERIC(7,2),
    functional_score_change     NUMERIC(7,2),
    loaded_at                   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (patient_id, month_start),
    CHECK (sessions_attended <= sessions_prescribed)
);

CREATE TABLE IF NOT EXISTS clinical_ops.fact_appointment (
    appointment_id          BIGINT PRIMARY KEY,
    patient_id              BIGINT NOT NULL REFERENCES clinical_ops.dim_patient(patient_id),
    appointment_date        DATE NOT NULL,
    programme_type          VARCHAR(100) NOT NULL,
    site                    VARCHAR(100) NOT NULL,
    attended_flag           BOOLEAN NOT NULL,
    cancellation_reason     VARCHAR(100),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_patient_month_month
    ON clinical_ops.fact_patient_month(month_start);
CREATE INDEX IF NOT EXISTS ix_patient_month_status
    ON clinical_ops.fact_patient_month(protocol_status);
CREATE INDEX IF NOT EXISTS ix_appointment_patient_date
    ON clinical_ops.fact_appointment(patient_id, appointment_date);
CREATE INDEX IF NOT EXISTS ix_patient_cohort
    ON clinical_ops.dim_patient(primary_risk_cohort, site, funding_type);

CREATE OR REPLACE VIEW clinical_ops.vw_patient_adherence_trailing AS
SELECT
    f.patient_id,
    p.patient_code,
    f.month_start,
    p.gender,
    p.age,
    CASE
        WHEN p.age < 30 THEN '18-29'
        WHEN p.age < 45 THEN '30-44'
        WHEN p.age < 60 THEN '45-59'
        ELSE '60+'
    END AS age_band,
    p.primary_risk_cohort,
    p.site,
    p.funding_type,
    p.employment_status,
    p.transport_mode,
    p.distance_km,
    f.sessions_prescribed,
    f.sessions_attended,
    f.monthly_adherence_rate,
    SUM(f.sessions_attended) OVER (
        PARTITION BY f.patient_id
        ORDER BY f.month_start
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    )::NUMERIC
    / NULLIF(SUM(f.sessions_prescribed) OVER (
        PARTITION BY f.patient_id
        ORDER BY f.month_start
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ),0) AS trailing_3m_adherence,
    SUM(f.sessions_attended) OVER (
        PARTITION BY f.patient_id
        ORDER BY f.month_start
        ROWS BETWEEN 5 PRECEDING AND CURRENT ROW
    )::NUMERIC
    / NULLIF(SUM(f.sessions_prescribed) OVER (
        PARTITION BY f.patient_id
        ORDER BY f.month_start
        ROWS BETWEEN 5 PRECEDING AND CURRENT ROW
    ),0) AS trailing_6m_adherence,
    f.protocol_status,
    f.primary_barrier,
    f.risk_score,
    f.weight_change_kg,
    f.systolic_bp_change,
    f.functional_score_change,
    CASE
        WHEN f.protocol_status = 'Dropped Out' THEN 1
        WHEN f.monthly_adherence_rate < 0.50 THEN 1
        ELSE 0
    END AS intervention_flag
FROM clinical_ops.fact_patient_month f
JOIN clinical_ops.dim_patient p USING (patient_id);

CREATE OR REPLACE VIEW clinical_ops.vw_cohort_monthly_kpis AS
SELECT
    month_start,
    primary_risk_cohort,
    site,
    funding_type,
    gender,
    age_band,
    COUNT(DISTINCT patient_id) AS active_patients,
    SUM(sessions_attended) AS sessions_attended,
    SUM(sessions_prescribed) AS sessions_prescribed,
    SUM(sessions_attended)::NUMERIC / NULLIF(SUM(sessions_prescribed),0) AS weighted_adherence_rate,
    AVG(monthly_adherence_rate) AS mean_patient_adherence_rate,
    AVG(trailing_3m_adherence) AS mean_trailing_3m_adherence,
    COUNT(DISTINCT patient_id) FILTER (WHERE protocol_status = 'Dropped Out') AS dropout_patients,
    COUNT(DISTINCT patient_id) FILTER (WHERE intervention_flag = 1) AS patients_needing_intervention,
    AVG(risk_score) AS mean_risk_score
FROM clinical_ops.vw_patient_adherence_trailing
GROUP BY 1,2,3,4,5,6;

CREATE OR REPLACE VIEW clinical_ops.vw_dropout_first_event AS
SELECT DISTINCT ON (f.patient_id)
    f.patient_id,
    p.patient_code,
    f.month_start AS dropout_month,
    p.primary_risk_cohort,
    p.gender,
    p.age,
    p.site,
    p.funding_type,
    p.employment_status,
    p.transport_mode,
    p.distance_km,
    f.primary_barrier,
    f.risk_score
FROM clinical_ops.fact_patient_month f
JOIN clinical_ops.dim_patient p USING (patient_id)
WHERE f.protocol_status = 'Dropped Out'
ORDER BY f.patient_id, f.month_start;

CREATE OR REPLACE FUNCTION clinical_ops.validate_patient_month()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.month_start <> date_trunc('month', NEW.month_start)::date THEN
        RAISE EXCEPTION 'month_start must be the first day of a month';
    END IF;
    IF NEW.cumulative_attended > NEW.cumulative_prescribed THEN
        RAISE EXCEPTION 'cumulative attended cannot exceed cumulative prescribed';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_patient_month ON clinical_ops.fact_patient_month;
CREATE TRIGGER trg_validate_patient_month
BEFORE INSERT OR UPDATE ON clinical_ops.fact_patient_month
FOR EACH ROW EXECUTE FUNCTION clinical_ops.validate_patient_month();
