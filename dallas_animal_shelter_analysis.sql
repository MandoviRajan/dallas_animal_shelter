-- *******************
-- BUSINESS QUESTIONS
-- *******************

-- ************
-- QUESTION 1
-- ************
/* HOW MANY ANIMALS OF EACH TYPE ARE CURRENTLY IN THE SHELTER, CONSIDERING ONLY ACTIVE ANIMALS 
(I.E., THOSE THAT HAVE NOT LEFT THE SHELTER OR PASSED AWAY)? 
ADDITIONALLY, WHAT PERCENTAGE OF THE TOTAL CURRENT POPULATION DOES EACH ANIMAL TYPE REPRESENT?
*/

-- Calculating the last outcome date for each animal (since the same animal can enter the shelter multiple times). Then, filtering for animals with no outcome date (Outcome_Date IS NULL) to count only those currently in the shelter.

WITH Last_Outcome AS (
    -- Getting the latest outcome for each animal
    SELECT 
        a.Animal_Id,
        d.Animal_Type,
        MAX(e.Outcome_Date) AS Last_Outcome_Date
    FROM 
        dallasanimalshelter.animaladmission a
    JOIN 
        dallasanimalshelter.animaldetails d
    ON 
        a.Animal_Id = d.Animal_Id
    LEFT JOIN 
        dallasanimalshelter.exitstatus e
    ON 
        a.Impound_Number = e.Impound_Number
    GROUP BY 
        a.Animal_Id, d.Animal_Type
),
Current_Shelter_Animals AS (
    -- Filtering for animals still in the shelter (no outcome date)
    SELECT 
        Animal_Type,
        COUNT(DISTINCT Animal_Id) AS Total_Current_Animals
    FROM 
        Last_Outcome
    WHERE 
        Last_Outcome_Date IS NULL -- No recorded outcome date, meaning the animal is still in the shelter
    GROUP BY 
        Animal_Type
),
Shelter_Population_Percentage AS (
    -- Calculating the percentage of each animal type in the shelter
    SELECT 
        Animal_Type,
        Total_Current_Animals,
        ROUND((Total_Current_Animals * 100.0) / SUM(Total_Current_Animals) OVER (), 2) AS Percentage_Of_Total
    FROM 
        Current_Shelter_Animals
)
-- Final Output
SELECT 
    Animal_Type,
    Total_Current_Animals,
    Percentage_Of_Total
FROM 
    Shelter_Population_Percentage
ORDER BY 
    Total_Current_Animals DESC;


-- ************
-- QUESTION 2
-- ************
/* WHAT ARE THE MONTHLY TRENDS IN ANIMAL INTAKE VOLUMES BY TYPE, AND HOW DO THESE TRENDS VARY 
(HIGH, MODERATE, LOW)?
*/

WITH Monthly_Intake AS (
    -- Counting unique animal intakes by animal type for each month
    SELECT 
        d.Animal_Type,
        DATE_FORMAT(a.Intake_Date, '%Y-%m') AS Intake_Month,
        COUNT(DISTINCT a.Animal_Id) AS Total_Animals
    FROM 
        dallasanimalshelter.animaladmission a
    JOIN 
        dallasanimalshelter.animaldetails d
    ON 
        a.Animal_Id = d.Animal_Id
    LEFT JOIN 
        dallasanimalshelter.exitstatus e
    ON 
        a.Impound_Number = e.Impound_Number
    WHERE 
        e.Outcome_Date IS NULL -- No outcome recorded
        OR e.Outcome_Date > LAST_DAY(a.Intake_Date) -- Ensuring the outcome is after the current month
    GROUP BY 
        d.Animal_Type, DATE_FORMAT(a.Intake_Date, '%Y-%m')
),
Animal_Ranges AS (
    -- Calculating the range of counts for each animal type for classification later
    SELECT 
        Animal_Type,
        MIN(Total_Animals) AS Min_Count,
        MAX(Total_Animals) AS Max_Count,
        MAX(Total_Animals) - MIN(Total_Animals) AS CountRange
    FROM 
        Monthly_Intake
    GROUP BY 
        Animal_Type
),
Classified_Intake AS (
    -- Dynamically classifying each month into High, Moderate, or Low Intake
    SELECT 
        m.Animal_Type,
        m.Intake_Month,
        m.Total_Animals,
        r.Min_Count,
        r.CountRange,
        CASE 
            WHEN m.Total_Animals <= r.Min_Count + (r.CountRange / 3) THEN 'Low Intake'
            WHEN m.Total_Animals <= r.Min_Count + (2 * r.CountRange / 3) THEN 'Moderate Intake'
            ELSE 'High Intake'
        END AS Intake_Classification
    FROM 
        Monthly_Intake m
    JOIN 
        Animal_Ranges r
    ON 
        m.Animal_Type = r.Animal_Type
)
-- Final output
SELECT 
    Animal_Type,
    Intake_Month,
    Total_Animals,
    Intake_Classification
FROM 
    Classified_Intake
ORDER BY 
    Animal_Type, Intake_Month;

-- ************
-- QUESTION 3
-- ************
/* WHICH ANIMAL_BREED HAS THE HIGHEST NUMBER OF OWNER SURRENDERS FOR EACH ANIMAL_TYPE, 
AND WHAT IS THE TOTAL COUNT OF OWNER SURRENDERS FOR THAT ANIMAL_BREED?
*/

WITH Surrender_Data AS (
    -- Filtering for owner surrenders and group by Animal_Type and Animal_Breed
    SELECT 
        d.Animal_Type,
        d.Animal_Breed,
        COUNT(*) AS Total_Surrenders
    FROM 
        dallasanimalshelter.animaladmission a
    JOIN 
        dallasanimalshelter.animaldetails d
    ON 
        a.Animal_Id = d.Animal_Id
    WHERE 
        a.Intake_Type = 'OWNER SURRENDER' -- Filter for owner surrenders
    GROUP BY 
        d.Animal_Type, d.Animal_Breed
),
Total_By_Type AS (
    -- Getting total surrenders for each Animal_Type
    SELECT 
        Animal_Type,
        SUM(Total_Surrenders) AS Total_Surrenders_By_Type
    FROM 
        Surrender_Data
    GROUP BY 
        Animal_Type
),
Surrender_Percentage AS (
    -- Calculating percentage of surrenders for each breed within its type
    SELECT 
        sd.Animal_Type,
        sd.Animal_Breed,
        sd.Total_Surrenders,
        tb.Total_Surrenders_By_Type,
        ROUND((sd.Total_Surrenders * 100.0) / tb.Total_Surrenders_By_Type, 2) AS Surrender_Percentage
    FROM 
        Surrender_Data sd
    JOIN 
        Total_By_Type tb
    ON 
        sd.Animal_Type = tb.Animal_Type
),
Ranked_Surrenders AS (
    -- Ranking breeds by percentage within each type
    SELECT 
        Animal_Type,
        Animal_Breed,
        Total_Surrenders,
        Surrender_Percentage,
        RANK() OVER (PARTITION BY Animal_Type ORDER BY Surrender_Percentage DESC) AS SurrenderRank
    FROM 
        Surrender_Percentage
)
-- Retrieving only the top breed for each type
SELECT 
    Animal_Type,
    Animal_Breed,
    Total_Surrenders,
    Surrender_Percentage
FROM 
    Ranked_Surrenders
WHERE 
    SurrenderRank = 1
ORDER BY 
    Animal_Type;
    
-- ************
-- QUESTION 4
-- ************
/* WHO ARE THE TOP 5 STAFF MEMBERS WHO HANDLED THE MOST ANIMALS IN OCTOBER 2024, 
AND HOW MANY ANIMALS DID EACH OF THEM HANDLE?
*/ 

WITH Monthly_Staff_Animal_Count AS (
    -- Counting the number of animals handled by each staff member in October 2024
    SELECT 
        s.Staff_Id,
        COUNT(DISTINCT a.Animal_Id) AS Total_Animals_Handled
    FROM 
        dallasanimalshelter.shelterstaydetails s
    JOIN 
        dallasanimalshelter.animaladmission a
    ON 
        s.Impound_Number = a.Impound_Number
    WHERE 
        DATE_FORMAT(a.Intake_Date, '%Y-%m') = '2024-10'
    GROUP BY 
        s.Staff_Id
),
Ranked_Staff AS (
    -- Ranking staff members by the total number of animals they handled
    SELECT 
        Staff_Id,
        Total_Animals_Handled,
        RANK() OVER (ORDER BY Total_Animals_Handled DESC) AS StaffRank
    FROM 
        Monthly_Staff_Animal_Count
)
-- Retrieving the top 5 staff members
SELECT 
    Staff_Id,
    Total_Animals_Handled
FROM 
    Ranked_Staff
WHERE 
    StaffRank <= 5 
ORDER BY 
    StaffRank;
 
 
-- ************
-- QUESTION 5
-- ************
/* HOW HAVE DOG ADOPTIONS EVOLVED OVER THE LAST 12 MONTHS, 
AND DOES THE TREND SUGGEST A GROWING SHIFT TOWARD ADOPTION AS A PREFERRED OPTION?
*/
    
WITH Monthly_Dog_Adoptions AS (
    -- Counting the number of dog adoptions for each month in the last 12 months
    SELECT 
        DATE_FORMAT(e.Outcome_Date, '%Y-%m') AS Adoption_Month,
        COUNT(*) AS Total_Dog_Adoptions
    FROM 
        dallasanimalshelter.exitstatus e
    JOIN 
        dallasanimalshelter.animaladmission a
    ON 
        e.Impound_Number = a.Impound_Number 
    JOIN 
        dallasanimalshelter.animaldetails d
    ON 
        a.Animal_Id = d.Animal_Id 
    WHERE 
        UPPER(d.Animal_Type) = 'DOG'
        AND UPPER(e.Outcome_Type) = 'ADOPTION' -- Filter for adoption outcomes
        AND e.Outcome_Date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH) -- Last 12 months
    GROUP BY 
        DATE_FORMAT(e.Outcome_Date, '%Y-%m')
),
Adoption_Trend AS (
    -- Using LAG to calculate the previous month's adoptions
    SELECT 
        Adoption_Month,
        Total_Dog_Adoptions,
        LAG(Total_Dog_Adoptions) OVER (ORDER BY Adoption_Month) AS Previous_Month_Adoptions,
        Total_Dog_Adoptions - LAG(Total_Dog_Adoptions) OVER (ORDER BY Adoption_Month) AS Month_to_Month_Change
    FROM 
        Monthly_Dog_Adoptions
)
-- Final Output
SELECT 
    Adoption_Month,
    Total_Dog_Adoptions,
    Previous_Month_Adoptions,
    Month_to_Month_Change,
    CASE 
        WHEN Month_to_Month_Change > 0 THEN 'Increase'
        WHEN Month_to_Month_Change < 0 THEN 'Decrease'
        ELSE 'No Change'
    END AS Trend
FROM 
    Adoption_Trend
ORDER BY 
    Adoption_Month;
 
-- ************
-- QUESTION 6
-- ************
/*  WHAT PERCENTAGE OF ANIMALS ADMITTED UNDER CRITICAL CONDITIONS 
RESULTED IN EUTHANASIA COMPARED TO OTHER OUTCOMES?
*/

WITH Critical_Admissions AS (
    -- Filtering animals admitted under critical conditions
    SELECT 
        mh.Animal_Id,
        d.Animal_Type,
        mh.Intake_Condition,
        e.Outcome_Type
    FROM 
        dallasanimalshelter.medicalhistory mh
    JOIN 
        dallasanimalshelter.animaldetails d
    ON 
        mh.Animal_Id = d.Animal_Id
    LEFT JOIN 
        dallasanimalshelter.exitstatus e
    ON 
        mh.Impound_Number = e.Impound_Number
    WHERE 
        UPPER(mh.Intake_Condition) = 'CRITICAL' -- Filter for critical intake conditions
),
Outcome_Counts AS (
    -- Counting outcomes for animals admitted under critical conditions
    SELECT 
        Outcome_Type,
        COUNT(*) AS Total_Outcomes
    FROM 
        Critical_Admissions
    GROUP BY 
        Outcome_Type
),
Outcome_Percentage AS (
    -- Calculating the percentage of each outcome
    SELECT 
        Outcome_Type,
        Total_Outcomes,
        ROUND((Total_Outcomes * 100.0) / SUM(Total_Outcomes) OVER (), 2) AS Outcome_Percentage
    FROM 
        Outcome_Counts
)
-- Final Output
SELECT 
    Outcome_Type,
    Total_Outcomes,
    Outcome_Percentage
FROM 
    Outcome_Percentage
ORDER BY 
    Outcome_Percentage DESC;


-- ************
-- QUESTION 7
-- ************
/*  AS OF THE LATEST LOG ENTRY FOR EACH KENNEL, HOW MANY KENNELS ARE AVAILABLE, 
AND DOES THE SHELTER HAVE ENOUGH SPACE?
*/

WITH Latest_Kennel_Status AS (
    -- Identifying the latest log entry (Log_Id) for each kennel
    SELECT 
        Kennel_Number,
        MAX(Log_Id) AS Latest_Log_Id
    FROM 
        dallasanimalshelter.kennelstatuslog
    GROUP BY 
        Kennel_Number
)
-- Joining with the original table to get the status of the latest log entry
SELECT 
    k.Kennel_Status,
    COUNT(*) AS Total_Available_Kennels
FROM 
    dallasanimalshelter.kennelstatuslog k
JOIN 
    Latest_Kennel_Status lks
ON 
    k.Kennel_Number = lks.Kennel_Number
    AND k.Log_Id = lks.Latest_Log_Id
WHERE k.Kennel_Status = 'AVAILABLE'
GROUP BY 
    k.Kennel_Status
ORDER BY 
    Total_Available_Kennels DESC;

-- ************
-- QUESTION 8
-- ************
/*  WHICH 10 ANIMALS HAVE BEEN STAYING IN THE SHELTER FOR THE LONGEST TIME 
AND WHAT IS THEIR CURRENT MEDICAL CONDITION?
*/

WITH Animal_Stay_Duration AS (
    -- Calculating the number of days each animal has stayed in the shelter
    SELECT 
        a.Animal_Id,
        MIN(a.Intake_Date) AS Intake_Date, -- Earliest intake date
        DATEDIFF(CURDATE(), MIN(a.Intake_Date)) AS Days_Stayed
    FROM 
        dallasanimalshelter.animaladmission a
    LEFT JOIN 
        dallasanimalshelter.exitstatus e
    ON 
        a.Impound_Number = e.Impound_Number
    WHERE 
        e.Outcome_Date IS NULL -- Animal is still in the shelter
    GROUP BY 
        a.Animal_Id
),
Top_Animals AS (
    -- Getting the top 10 animals with the longest stay
    SELECT 
        Animal_Id,
        Intake_Date,
        Days_Stayed
    FROM 
        Animal_Stay_Duration
    ORDER BY 
        Days_Stayed DESC
    LIMIT 10
)
-- Joining to include additional details: Type, Breed, and Current Medical Condition
SELECT 
    t.Animal_Id,
	d.Animal_Type,
    d.Animal_Breed,
    t.Intake_Date,
    t.Days_Stayed,
    mh.Intake_Condition AS Current_Medical_Condition
FROM 
    Top_Animals t
JOIN 
    dallasanimalshelter.animaldetails d
ON 
    t.Animal_Id = d.Animal_Id
LEFT JOIN 
    dallasanimalshelter.medicalhistory mh
ON 
    t.Animal_Id = mh.Animal_Id
ORDER BY 
    t.Days_Stayed DESC;


