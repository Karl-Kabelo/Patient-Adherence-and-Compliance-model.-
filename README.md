# Patient Adherence and Compliance Model

A clinical operations analytics project focused on patient rehabilitation adherence and compliance, built using PostgreSQL, Power BI, and Advanced Excel.

## Project Overview

This project analyses patient rehabilitation data to identify adherence trends, dropout patterns, clinical risk changes, and factors associated with declining participation.

### Key Metrics

* Monthly rehabilitation adherence
* Trailing 3-month and 6-month adherence
* Dropout rates by clinical and demographic cohorts
* Patients requiring early intervention
* Barriers associated with declining adherence
* Changes in risk scores and basic clinical outcomes over 12 months

## Project Files

| File                                 | Description                                                                 |
| ------------------------------------ | --------------------------------------------------------------------------- |
| `01_schema.sql`                      | PostgreSQL schema with constraints, indexes, views, and validation triggers |
| `02_load_data.sql`                   | PostgreSQL data loading script                                              |
| `03_analysis_queries.sql`            | Analysis queries for cohort decline, dropout, and patient deterioration     |
| `04_data_quality_tests.sql`          | Executable data quality checks                                              |
| `PowerBI_DAX_Measures.txt`           | DAX measures for the Power BI model                                         |
| `patients.csv`                       | 250 synthetic patient records                                               |
| `patient_month.csv`                  | 2,755 monthly patient records                                               |
| `appointments.csv`                   | 14,270 appointment records                                                  |
| `Patient_Adherence_Excel_Model.xlsx` | Excel dashboard and analytical model                                        |

## PostgreSQL Setup

Create the database and run the SQL scripts:

```bash
createdb patient_adherence
psql -d patient_adherence -f 01_schema.sql
psql -d patient_adherence -f 02_load_data.sql
psql -d patient_adherence -f 04_data_quality_tests.sql
```

Run these commands from the project directory so that the relative CSV file paths resolve correctly.

## Power BI Model

Import the following PostgreSQL tables into Power BI:

* `clinical_ops.dim_patient`
* `clinical_ops.fact_patient_month`
* `clinical_ops.fact_appointment`

### Recommended Data Model

Create a dedicated Date table and mark it as the model's Date table.

Recommended relationships:

* `dim_patient[patient_id]` to `fact_patient_month[patient_id]`
* `dim_patient[patient_id]` to `fact_appointment[patient_id]`
* Date table to `fact_patient_month[month_start]`
* Date table to appointment date using an inactive relationship where appropriate

## Dashboard Structure

### 1. Executive Overview

* Weighted adherence
* Dropout rate
* Intervention rate
* Average patient risk score

### 2. Cohort Analysis

Analyse adherence and dropout patterns by:

* Age
* Gender
* Funding type
* Transport access
* Clinical cohort

### 3. Trailing Window Trends

Monitor:

* 3-month adherence
* 6-month adherence
* Month-on-month percentage-point changes

### 4. Dropout Drivers

Analyse:

* Reported barriers
* Demographic patterns
* Access-related factors
* High-risk patient combinations

### 5. Patient Drill-Through

Review individual patient trends including:

* Adherence history
* Patient status
* Risk score
* Clinical outcomes

## Clinical Interpretation

The model follows several safeguards to ensure that the analysis is interpreted appropriately:

* Weighted adherence is calculated as total attended sessions divided by total prescribed sessions.
* Mean patient adherence is maintained as a separate metric.
* A single month of poor adherence does not automatically classify a patient as a dropout.
* The dataset contains synthetic patient information and does not contain real patient data.
* This project is designed for operational analytics and is not a diagnostic or clinical decision-support system.

## Portfolio Summary

Designed a clinical operations analytics dashboard to monitor patient rehabilitation adherence, risk scores, and compliance. The model identifies percentage-point changes in adherence across clinical cohorts using trailing-window metrics while highlighting demographic and access-related factors associated with patient dropout.

## Technologies

* PostgreSQL
* Power BI
* DAX
* Microsoft Excel
* SQL
* Data Quality Testing
* Clinical Operations Analytics

## Data Disclaimer

All patient data used in this project is synthetic and created for portfolio and educational purposes. No real patient information is included.
