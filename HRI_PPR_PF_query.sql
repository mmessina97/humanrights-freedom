-- Growth or decrease percentage of HRI from 2000 to 2023 and average PF
WITH FirstLast AS (
    SELECT 
        h.Entity,
        MIN(h.Year) AS FirstYear,
        MAX(h.Year) AS LastYear
    FROM freedomrights.humanrightsindex h
    GROUP BY h.Entity
),
Growth AS (
    SELECT 
        f.Entity,
        (SELECT h1.HumanRightsIndex FROM freedomrights.humanrightsindex h1 
         WHERE h1.Entity = f.Entity AND h1.Year = f.FirstYear) AS FirstValue,
        (SELECT h2.HumanRightsIndex FROM freedomrights.humanrightsindex h2 
         WHERE h2.Entity = f.Entity AND h2.Year = f.LastYear) AS LastValue
    FROM FirstLast f
)
SELECT 
    g.Entity,
    ROUND(((g.LastValue - g.FirstValue) / NULLIF(g.FirstValue, 0)) * 100, 2) AS GrowthHumanRightsPercentage, 
    ROUND(AVG(p.PressFreedom), 2) AS AvgPressFreedom
FROM Growth g
JOIN freedomrights.pressfreedom p 
ON g.Entity = p.Entity
GROUP BY g.Entity, GrowthHumanRightsPercentage
ORDER BY GrowthHumanRightsPercentage DESC;



-- countries over the HRI average and under the PPR average
WITH PPA as
	(SELECT 
		ROUND(AVG(p.PrisonPopulationRate), 2) AS PrisPopAVG
    FROM freedomrights.prisonpopulationrate AS p),
HRA AS
	(SELECT 
		ROUND(AVG(h.HumanRightsIndex), 2) AS HumRigAVG
    FROM freedomrights.humanrightsindex AS h)
SELECT h.Entity, h.HumanRightsIndex, p.PrisonPopulationRate
FROM freedomrights.humanrightsindex AS h
JOIN freedomrights.prisonpopulationrate AS p
ON h.Entity = p.Entity
CROSS JOIN PPA
CROSS JOIN HRA
WHERE h.Year = 2018 AND p.PrisonPopulationRate < PPA.PrisPopAVG AND h.HumanRightsIndex > HRA.HumRigAVG
ORDER BY p.PrisonPopulationRate ASC;

-- countries under the HRI average and over the PPR average
WITH PPA AS
	(SELECT 
		ROUND(AVG(p.PrisonPopulationRate), 2) AS PrisPopAVG
    FROM freedomrights.prisonpopulationrate AS p),
HRA AS
	(SELECT 
		ROUND(AVG(h.HumanRightsIndex), 2) AS HumRigAVG
    from freedomrights.humanrightsindex AS h)
SELECT h.Entity, h.HumanRightsIndex, p.PrisonPopulationRate
FROM freedomrights.humanrightsindex AS h
JOIN freedomrights.prisonpopulationrate AS p
ON h.Entity = p.Entity
CROSS JOIN PPA
CROSS JOIN HRA
WHERE h.Year = 2018 AND p.PrisonPopulationRate > PPA.PrisPopAVG AND h.HumanRightsIndex < HRA.HumRigAVG
ORDER BY p.PrisonPopulationRate;

-- The worst year/s (in case of same data for multiple years) for HRI and PF
-- (adding the two data points by country and by year, and then finding the smaller value)
WITH somma AS (
    SELECT 
        h.Entity, 
        h.Year, 
        (MIN(h.HumanRightsIndex) + MIN(p.PressFreedom)) AS HRPF
    FROM freedomrights.humanrightsindex AS h
    JOIN freedomrights.pressfreedom AS p
        ON h.Entity = p.Entity AND h.Year = p.Year
    GROUP BY h.Entity, h.Year
), ranked AS (
    SELECT 
        s.Entity, 
        s.Year, 
        s.HRPF,
        RANK() OVER (PARTITION BY s.Entity ORDER BY s.HRPF ASC) AS rnk
    FROM somma s
)
SELECT 
    h.Entity, 
    h.Year, 
    h.HumanRightsIndex, 
    p.PressFreedom
FROM ranked r
JOIN freedomrights.humanrightsindex h 
    ON r.Entity = h.Entity AND r.Year = h.Year
JOIN freedomrights.pressfreedom p 
    ON r.Entity = p.Entity AND r.Year = p.Year
WHERE r.rnk = 1  -- Seleziona solo l'anno con la somma minima per ogni Entity
ORDER BY r.HRPF;


-- query that shows the join between press freedom, human rights, and the number of prisoners for the most recent available year for each individual data point

WITH latest_h AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY Entity ORDER BY Year DESC) AS rn
    FROM freedomrights.humanrightsindex
),
latest_p AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY Entity ORDER BY Year DESC) AS rn
    FROM freedomrights.pressfreedom
),
latest_pp AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY Entity ORDER BY Year DESC) AS rn
    FROM freedomrights.prisonpopulationrate
)
SELECT 
    h.Entity, 
    h.Year AS HumanRightsYear, 
    h.HumanRightsIndex, 
    p.Year AS PressFreedomYear, 
    p.PressFreedom, 
    pp.Year AS PrisonPopulationYear, 
    pp.PrisonPopulationRate
FROM latest_h h
LEFT JOIN latest_p p ON h.Entity = p.Entity AND p.rn = 1
LEFT JOIN latest_pp pp ON h.Entity = pp.Entity AND pp.rn = 1
WHERE h.rn = 1
ORDER BY h.HumanRightsIndex ASC;



