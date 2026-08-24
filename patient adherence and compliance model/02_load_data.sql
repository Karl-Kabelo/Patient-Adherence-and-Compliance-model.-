BEGIN;

TRUNCATE TABLE clinical_ops.fact_appointment,
               clinical_ops.fact_patient_month,
               clinical_ops.dim_patient
RESTART IDENTITY CASCADE;

\copy clinical_ops.dim_patient (
    patient_id, patient_code, gender, age, primary_risk_cohort, comorbidity_count,
    baseline_risk_score, site, funding_type, employment_status, transport_mode,
    distance_km, programme_type, enrolment_date
) FROM 'patients.csv' WITH (FORMAT csv, HEADER true);

CREATE TEMP TABLE staging_patient_month (
    patient_id BIGINT,
    month_start DATE,
    sessions_prescribed SMALLINT,
    sessions_attended SMALLINT,
    monthly_adherence_rate NUMERIC,
    cumulative_prescribed INTEGER,
    cumulative_attended INTEGER,
    protocol_status VARCHAR(30),
    primary_barrier VARCHAR(100),
    risk_score NUMERIC,
    weight_change_kg NUMERIC,
    systolic_bp_change NUMERIC,
    functional_score_change NUMERIC
);

\copy staging_patient_month FROM 'patient_month.csv' WITH (FORMAT csv, HEADER true);

INSERT INTO clinical_ops.fact_patient_month (
    patient_id, month_start, sessions_prescribed, sessions_attended,
    cumulative_prescribed, cumulative_attended, protocol_status, primary_barrier,
    risk_score, weight_change_kg, systolic_bp_change, functional_score_change
)
SELECT
    patient_id, month_start, sessions_prescribed, sessions_attended,
    cumulative_prescribed, cumulative_attended, protocol_status, primary_barrier,
    risk_score, weight_change_kg, systolic_bp_change, functional_score_change
FROM staging_patient_month;

\copy clinical_ops.fact_appointment (
    appointment_id, patient_id, appointment_date, programme_type, site,
    attended_flag, cancellation_reason
) FROM 'appointments.csv' WITH (FORMAT csv, HEADER true);

COMMIT;
