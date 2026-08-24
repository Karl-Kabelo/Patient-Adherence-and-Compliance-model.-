DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM clinical_ops.fact_patient_month
        WHERE sessions_attended > sessions_prescribed
    ) THEN
        RAISE EXCEPTION 'Data quality failure: attended exceeds prescribed';
    END IF;

    IF EXISTS (
        SELECT patient_id, month_start
        FROM clinical_ops.fact_patient_month
        GROUP BY patient_id, month_start
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION 'Data quality failure: duplicate patient-month rows';
    END IF;

    IF EXISTS (
        SELECT 1 FROM clinical_ops.fact_patient_month
        WHERE monthly_adherence_rate NOT BETWEEN 0 AND 1
    ) THEN
        RAISE EXCEPTION 'Data quality failure: adherence outside 0-1';
    END IF;
END $$;

SELECT
    'patients' AS test_name,
    COUNT(*) AS row_count
FROM clinical_ops.dim_patient
UNION ALL
SELECT 'patient_month', COUNT(*) FROM clinical_ops.fact_patient_month
UNION ALL
SELECT 'appointments', COUNT(*) FROM clinical_ops.fact_appointment;
