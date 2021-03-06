--N3C covid-19 phenotype, PCORnet CDM, Oracle
--N3C phenotype V1.2

-- start date
var start_date varchar2(32);
exec :start_date := '2020-01-01';

------ DX category values
var dx_strong_positive varchar2(32);
exec :dx_strong_positive := '1_strong_positive';

var dx_weak_positive varchar2(32);
exec :dx_weak_positive := '2_weak_positive';
 
-- Lab LOINC codes from phenotype doc
with covid_loinc as
(
	select '94307-6' as loinc from dual UNION
	select '94308-4' as loinc from dual UNION
	select '94309-2' as loinc from dual UNION
	select '94310-0' as loinc from dual UNION
	select '94311-8' as loinc from dual UNION
	select '94312-6' as loinc from dual UNION
	select '94313-4' as loinc from dual UNION
	select '94314-2' as loinc from dual UNION
	select '94315-9' as loinc from dual UNION
	select '94316-7' as loinc from dual UNION
	select '94500-6' as loinc from dual UNION
	select '94502-2' as loinc from dual UNION
	select '94505-5' as loinc from dual UNION
	select '94506-3' as loinc from dual UNION
	select '94507-1' as loinc from dual UNION
	select '94508-9' as loinc from dual UNION
	select '94509-7' as loinc from dual UNION
	select '94510-5' as loinc from dual UNION
	select '94511-3' as loinc from dual UNION
	select '94532-9' as loinc from dual UNION
	select '94533-7' as loinc from dual UNION
	select '94534-5' as loinc from dual UNION
	select '94547-7' as loinc from dual UNION
	select '94558-4' as loinc from dual UNION
	select '94559-2' as loinc from dual UNION
	select '94562-6' as loinc from dual UNION
	select '94563-4' as loinc from dual UNION
	select '94564-2' as loinc from dual UNION
	select '94565-9' as loinc from dual UNION
	select '94639-2' as loinc from dual UNION
	select '94640-0' as loinc from dual UNION
	select '94641-8' as loinc from dual UNION
	select '94642-6' as loinc from dual UNION
	select '94643-4' as loinc from dual UNION
	select '94644-2' as loinc from dual UNION
	select '94645-9' as loinc from dual UNION
	select '94646-7' as loinc from dual UNION
	select '94647-5' as loinc from dual UNION
	select '94660-8' as loinc from dual UNION
	select '94661-6' as loinc from dual 
),
-- Diagnosis ICD-10 codes from phenotype doc
covid_icd10 as
(
	select 'B97.21' as icd10_code,	:dx_strong_positive as dx_category from dual UNION
	select 'B97.29' as icd10_code,	:dx_strong_positive as dx_category from dual UNION
	select 'U07.1' as icd10_code,	:dx_strong_positive as dx_category from dual UNION
	select 'Z20.828' as icd10_code,	:dx_weak_positive as dx_category from dual UNION
	select 'B34.2' as icd10_code,	:dx_weak_positive as dx_category from dual UNION
	select 'R50%' as icd10_code,	:dx_weak_positive as dx_category from dual UNION
	select 'R05%' as icd10_code,	:dx_weak_positive as dx_category from dual UNION
	select 'R06.0%' as icd10_code,	:dx_weak_positive as dx_category from dual UNION
	select 'J12%' as icd10_code,	:dx_weak_positive as dx_category from dual UNION
	select 'J18%' as icd10_code,	:dx_weak_positive as dx_category from dual UNION
	select 'J20%' as icd10_code,	:dx_weak_positive as dx_category from dual UNION
	select 'J40%' as icd10_code,	:dx_weak_positive as dx_category from dual UNION
	select 'J21%' as icd10_code,	:dx_weak_positive as dx_category from dual UNION
	select 'J96%' as icd10_code,	:dx_weak_positive as dx_category from dual UNION
	select 'J22%' as icd10_code,	:dx_weak_positive as dx_category from dual UNION
	select 'J06.9' as icd10_code,	:dx_weak_positive as dx_category from dual UNION
	select 'J98.8' as icd10_code,	:dx_weak_positive as dx_category from dual UNION
	select 'J80%' as icd10_code,	:dx_weak_positive as dx_category from dual UNION
	select 'R43.0' as icd10_code,	:dx_weak_positive as dx_category from dual UNION
	select 'R43.2' as icd10_code,	:dx_weak_positive as dx_category from dual
),
-- procedure codes from phenotype doc
covid_proc_codes as
(
    select 'U0001' as procedure_code from dual UNION
    select 'U0002' as procedure_code from dual UNION
    select '87635' as procedure_code from dual UNION
    select '86318' as procedure_code from dual UNION
    select '86328' as procedure_code from dual UNION
    select '86769' as procedure_code from dual
),
-- patients with covid related lab since start_date
covid_lab_result_cm as
(
    select
        lab_result_cm.*
    from
        lab_result_cm
    where
        lab_result_cm.result_date >= to_date(:start_date,'YYYY-MM-DD')
        and 
        (
            lab_result_cm.lab_loinc in (select loinc from covid_loinc)
            or
			lab_result_cm.raw_lab_name like '%COVID-19%'
			or
			lab_result_cm.raw_lab_name like '%SARS-COV-2%'            
        )
),
-- patients with covid related diagnosis since start_date
covid_diagnosis as
(
    select
        dxq.*,
        coalesce(dx_date,admit_date) as best_dx_date,  -- use for later queries
        -- custom dx_category for one ICD-10 code, see phenotype doc
		case
			when dx = 'B97.29' and coalesce(dx_date,admit_date) < to_date('2020-04-01','YYYY-MM-DD')  then :dx_strong_positive
			when dx = 'B97.29' and coalesce(dx_date,admit_date) >= to_date('2020-04-01','YYYY-MM-DD') then :dx_weak_positive
			else dxq.orig_dx_category
		end as dx_category        
    from
    (
        select
            diagnosis.patid,
            diagnosis.encounterid,
            diagnosis.dx,
            diagnosis.admit_date,
            diagnosis.dx_date,
            covid_icd10.dx_category as orig_dx_category
        from
            diagnosis
            join covid_icd10 on diagnosis.dx like covid_icd10.icd10_code
        where
            coalesce(dx_date,admit_date) >= to_date(:start_date,'YYYY-MM-DD')
    ) dxq
),
-- patients with strong positive DX included
dx_strong as
(
    select distinct
        patid
    from
        covid_diagnosis
    where
        dx_category=:dx_strong_positive    
        
),
-- patients with two different weak DX in same encounter and/or on same date included
dx_weak as
(
    -- two different DX at same encounter
    select distinct patid from
    (
        select
            patid,
            encounterid,
            count(*) as dx_count
        from
        (
            select distinct
                patid, encounterid, dx
            from
                covid_diagnosis
            where
                dx_category=:dx_weak_positive
        ) subq
        group by
            patid,
            encounterid
        having
            count(*) >= 2
    ) dx_same_encounter
    
    UNION
    
    -- or two different DX on same date
    select distinct patid from
    (
        select
            patid,
            best_dx_date,
            count(*) as dx_count
        from
        (
            select distinct
                patid, best_dx_date, dx
            from
                covid_diagnosis
            where
                dx_category=:dx_weak_positive
        ) subq
        group by
            patid,
            best_dx_date
        having
            count(*) >= 2
    ) dx_same_date
),
-- patients with a covid related procedure since start_date
covid_procedures as
(
    select
        procedures.*
    from
        procedures
        join covid_proc_codes on procedures.px = covid_proc_codes.procedure_code
    where
        procedures.px_date >=  to_date(:start_date,'YYYY-MM-DD')

),
covid_cohort as
(
    select distinct patid from dx_strong
    UNION
    select distinct patid from dx_weak
    UNION
    select distinct patid from covid_procedures
    UNION
    select distinct patid from covid_lab_result_cm
)
select patid from covid_cohort
