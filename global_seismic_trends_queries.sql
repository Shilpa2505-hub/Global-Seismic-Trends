/*
GLOBAL SEISMIC TRENDS — SQL ANALYSIS QUERIES
Database: global_seismic_trends
Main table: earthquakes
MySQL: 8.x

How to use:
1. Open this file in MySQL Workbench or a text editor.
2. Run one query at a time after selecting the global_seismic_trends database.
3. Country/continent questions require the optional mapping table described below.
4. Casualty, economic-loss, and alert-level questions cannot be answered from the current
   USGS schema because those fields are not present. Do not invent values.

Current earthquakes table fields include:
id, time, updated, latitude, longitude, depth_km, mag, magType, place, status,
tsunami, sig, net, nst, dmin, rms, gap, magError, depthError, magNst,
locationSource, magSource, types, ids, sources, type, year, month, day,
day_of_week, location_region, depth_category, strong_earthquake, major_earthquake
*/

USE global_seismic_trends;

-- Q01. Top 10 strongest earthquakes
SELECT id, time, place, mag, depth_km
FROM earthquakes
WHERE mag IS NOT NULL
ORDER BY mag DESC, time DESC
LIMIT 10;

-- Q02. Top 10 deepest earthquakes
SELECT id, time, place, mag, depth_km
FROM earthquakes
WHERE depth_km IS NOT NULL
ORDER BY depth_km DESC, time DESC
LIMIT 10;

-- Q03. Shallow earthquakes (depth < 50 km) with magnitude > 7.5
SELECT id, time, place, mag, depth_km
FROM earthquakes
WHERE depth_km < 50 AND mag > 7.5
ORDER BY mag DESC, time DESC;

-- Q04. Average depth per continent
-- Requires earthquake_country_mapping(earthquake_id, country, continent),
-- with one row per mapped earthquake. The mapping table is not in the original schema.
-- SELECT m.continent, COUNT(*) AS event_count, ROUND(AVG(e.depth_km), 2) AS avg_depth_km
-- FROM earthquakes e
-- JOIN earthquake_country_mapping m ON m.earthquake_id = e.id
-- WHERE e.depth_km IS NOT NULL AND m.continent IS NOT NULL
-- GROUP BY m.continent ORDER BY avg_depth_km DESC;

-- Q05. Average magnitude per magnitude type
SELECT magType, COUNT(*) AS earthquake_count,
       ROUND(AVG(mag), 2) AS average_magnitude
FROM earthquakes
WHERE magType IS NOT NULL AND mag IS NOT NULL
GROUP BY magType
ORDER BY average_magnitude DESC;

-- Q06. Year with the most earthquake records
SELECT year, COUNT(*) AS earthquake_count
FROM earthquakes
WHERE year IS NOT NULL
GROUP BY year
ORDER BY earthquake_count DESC;

-- Q07. Month with the most earthquake records (all years combined)
SELECT month, COUNT(*) AS earthquake_count
FROM earthquakes
WHERE month BETWEEN 1 AND 12
GROUP BY month
ORDER BY earthquake_count DESC;

-- Q08. Earthquake count by day of week
SELECT day_of_week, COUNT(*) AS earthquake_count
FROM earthquakes
WHERE day_of_week IS NOT NULL
GROUP BY day_of_week
ORDER BY earthquake_count DESC;

-- Q09. Earthquake count by UTC hour of day
SELECT HOUR(time) AS utc_hour, COUNT(*) AS earthquake_count
FROM earthquakes
WHERE time IS NOT NULL
GROUP BY HOUR(time)
ORDER BY utc_hour;

-- Q10. Most active reporting networks by record count
SELECT net, COUNT(*) AS earthquake_count
FROM earthquakes
WHERE net IS NOT NULL
GROUP BY net
ORDER BY earthquake_count DESC
LIMIT 10;

-- Q11. Top 5 places with highest casualties
-- NOT CALCULABLE from the current schema: no casualties field or linked casualty source.
-- After adding a verified source/table, join it by earthquake ID and aggregate casualties.

-- Q12. Total estimated economic loss per continent
-- NOT CALCULABLE from the current schema: no economic_loss field/source.
-- Also requires the country/continent mapping table described in Q04.

-- Q13. Average economic loss by alert level
-- NOT CALCULABLE from the current schema: neither economic_loss nor alert is present.

-- Q14. Reviewed vs automatic event counts
SELECT status, COUNT(*) AS event_count
FROM earthquakes
WHERE status IS NOT NULL
GROUP BY status
ORDER BY event_count DESC;

-- Q15. Event count by event type
SELECT type AS event_type, COUNT(*) AS event_count
FROM earthquakes
WHERE type IS NOT NULL
GROUP BY type
ORDER BY event_count DESC;

-- Q16. Count of each stored `types` combination
-- This counts combinations as stored by USGS, not individual tokens inside each combination.
SELECT types, COUNT(*) AS event_count
FROM earthquakes
WHERE types IS NOT NULL
GROUP BY types
ORDER BY event_count DESC
LIMIT 20;

-- Q17. Average RMS and gap by continent
-- Requires earthquake_country_mapping(earthquake_id, country, continent).
-- SELECT m.continent, COUNT(*) AS event_count,
--        ROUND(AVG(e.rms), 3) AS average_rms,
--        ROUND(AVG(e.gap), 2) AS average_gap
-- FROM earthquakes e
-- JOIN earthquake_country_mapping m ON m.earthquake_id = e.id
-- WHERE m.continent IS NOT NULL
-- GROUP BY m.continent ORDER BY event_count DESC;

-- Q18. Events with high station coverage; threshold 20 is a project-defined choice
SELECT id, time, place, mag, nst
FROM earthquakes
WHERE nst > 20
ORDER BY nst DESC
LIMIT 20;

-- Q19. Tsunami-flagged events per year
-- tsunami=1 is the USGS event flag; it does not prove a damaging tsunami occurred.
SELECT year, COUNT(*) AS tsunami_flagged_events
FROM earthquakes
WHERE tsunami = 1 AND year IS NOT NULL
GROUP BY year
ORDER BY year;

-- Q20. Event counts by alert level
-- NOT CALCULABLE from the current schema: there is no alert column in the table.

-- Q21. Top 5 countries by average magnitude over the available period
-- Requires earthquake_country_mapping(earthquake_id, country, continent).
-- The >=100 event cutoff is a project-defined minimum sample size.
-- SELECT m.country, COUNT(*) AS earthquake_count,
--        ROUND(AVG(e.mag), 2) AS average_magnitude
-- FROM earthquakes e
-- JOIN earthquake_country_mapping m ON m.earthquake_id = e.id
-- WHERE e.mag IS NOT NULL AND m.country IS NOT NULL
-- GROUP BY m.country
-- HAVING COUNT(*) >= 100
-- ORDER BY average_magnitude DESC LIMIT 5;

-- Q22. Countries with both shallow (<50 km) and deep (>=50 km) earthquakes in the same month
-- Requires earthquake_country_mapping(earthquake_id, country, continent).
-- SELECT m.country, e.year, e.month,
--        SUM(e.depth_km < 50) AS shallow_count,
--        SUM(e.depth_km >= 50) AS deep_count
-- FROM earthquakes e
-- JOIN earthquake_country_mapping m ON m.earthquake_id = e.id
-- WHERE e.depth_km IS NOT NULL AND m.country IS NOT NULL
-- GROUP BY m.country, e.year, e.month
-- HAVING SUM(e.depth_km < 50) > 0 AND SUM(e.depth_km >= 50) > 0
-- ORDER BY e.year, e.month, m.country;

-- Q23. Year-over-year growth in global earthquake record counts
-- Partial first/last calendar years should not be compared as full years.
WITH yearly_counts AS (
    SELECT year, COUNT(*) AS earthquake_count
    FROM earthquakes
    WHERE year IS NOT NULL
    GROUP BY year
)
SELECT year, earthquake_count,
       LAG(earthquake_count) OVER (ORDER BY year) AS previous_year_count,
       ROUND(
           100.0 * (earthquake_count - LAG(earthquake_count) OVER (ORDER BY year))
           / NULLIF(LAG(earthquake_count) OVER (ORDER BY year), 0), 2
       ) AS yoy_growth_percent
FROM yearly_counts
ORDER BY year;

-- Q24. Top 3 active regions combining frequency and average magnitude
-- Uses location_region as provided/derived in this project. The score is a project-defined
-- equal-weight normalized score, not an official seismological metric.
WITH region_stats AS (
    SELECT location_region, COUNT(*) AS event_count, AVG(mag) AS avg_mag
    FROM earthquakes
    WHERE location_region IS NOT NULL AND mag IS NOT NULL
    GROUP BY location_region
    HAVING COUNT(*) >= 100
),
normalized AS (
    SELECT *,
           (event_count - MIN(event_count) OVER ())
             / NULLIF(MAX(event_count) OVER () - MIN(event_count) OVER (), 0) AS freq_norm,
           (avg_mag - MIN(avg_mag) OVER ())
             / NULLIF(MAX(avg_mag) OVER () - MIN(avg_mag) OVER (), 0) AS mag_norm
    FROM region_stats
)
SELECT location_region, event_count, ROUND(avg_mag, 3) AS average_magnitude,
       ROUND(0.5 * COALESCE(freq_norm, 0) + 0.5 * COALESCE(mag_norm, 0), 3)
           AS activity_score
FROM normalized
ORDER BY activity_score DESC
LIMIT 3;

-- Q25. Average depth by country within +/-5 degrees latitude of the equator
-- Requires earthquake_country_mapping(earthquake_id, country, continent).
-- SELECT m.country, COUNT(*) AS event_count,
--        ROUND(AVG(e.depth_km), 2) AS average_depth_km
-- FROM earthquakes e
-- JOIN earthquake_country_mapping m ON m.earthquake_id = e.id
-- WHERE e.latitude BETWEEN -5 AND 5 AND e.depth_km IS NOT NULL
--   AND m.country IS NOT NULL
-- GROUP BY m.country
-- HAVING COUNT(*) >= 10
-- ORDER BY average_depth_km DESC;

-- Q26. Countries with the highest shallow-to-deep earthquake ratio
-- Definitions: shallow <50 km; deep >=50 km. Requires country mapping.
-- SELECT m.country,
--        SUM(e.depth_km < 50) AS shallow_count,
--        SUM(e.depth_km >= 50) AS deep_count,
--        ROUND(SUM(e.depth_km < 50) / NULLIF(SUM(e.depth_km >= 50), 0), 2)
--            AS shallow_to_deep_ratio
-- FROM earthquakes e
-- JOIN earthquake_country_mapping m ON m.earthquake_id = e.id
-- WHERE e.depth_km IS NOT NULL AND m.country IS NOT NULL
-- GROUP BY m.country
-- HAVING SUM(e.depth_km >= 50) >= 10
-- ORDER BY shallow_to_deep_ratio DESC;

-- Q27. Average magnitude difference between tsunami-flagged and non-flagged events
SELECT tsunami, COUNT(*) AS earthquake_count,
       ROUND(AVG(mag), 2) AS average_magnitude
FROM earthquakes
WHERE tsunami IN (0, 1) AND mag IS NOT NULL
GROUP BY tsunami
ORDER BY tsunami;

-- Difference (flagged minus non-flagged), returned as one row
SELECT
    ROUND(AVG(CASE WHEN tsunami = 1 THEN mag END), 2) AS avg_mag_tsunami_flagged,
    ROUND(AVG(CASE WHEN tsunami = 0 THEN mag END), 2) AS avg_mag_not_flagged,
    ROUND(
        AVG(CASE WHEN tsunami = 1 THEN mag END)
        - AVG(CASE WHEN tsunami = 0 THEN mag END), 2
    ) AS magnitude_difference
FROM earthquakes
WHERE tsunami IN (0, 1) AND mag IS NOT NULL;

-- Q28. Events with potentially lower data reliability
-- Project-defined screening thresholds: gap > 180 degrees OR RMS > 1.0.
-- These thresholds are heuristics, not universal USGS reliability rules.
SELECT id, time, place, mag, gap, rms
FROM earthquakes
WHERE (gap > 180 OR rms > 1.0)
ORDER BY COALESCE(gap, 0) DESC, COALESCE(rms, 0) DESC
LIMIT 100;

-- Q29. Distinct event pairs within 50 km and 1 hour
-- CAUTION: this self-join can be expensive on ~740k rows. Run only if needed and preferably
-- after adding indexes on time and id. It returns each pair once using a.id < b.id.
-- ST_Distance_Sphere uses longitude/latitude points and returns metres.
-- CREATE INDEX idx_earthquakes_time ON earthquakes(time);
-- CREATE INDEX idx_earthquakes_id ON earthquakes(id);
-- SELECT a.id AS event_id_1, a.time AS time_1, a.place AS place_1,
--        b.id AS event_id_2, b.time AS time_2, b.place AS place_2,
--        ROUND(ST_Distance_Sphere(
--            POINT(a.longitude, a.latitude),
--            POINT(b.longitude, b.latitude)
--        ) / 1000, 2) AS distance_km,
--        TIMESTAMPDIFF(SECOND, a.time, b.time) AS time_difference_seconds
-- FROM earthquakes a
-- JOIN earthquakes b
--   ON a.id < b.id
--  AND b.time BETWEEN a.time AND DATE_ADD(a.time, INTERVAL 1 HOUR)
-- WHERE a.latitude BETWEEN -90 AND 90 AND b.latitude BETWEEN -90 AND 90
--   AND a.longitude BETWEEN -180 AND 180 AND b.longitude BETWEEN -180 AND 180
--   AND ST_Distance_Sphere(
--       POINT(a.longitude, a.latitude), POINT(b.longitude, b.latitude)
--   ) <= 50000
-- ORDER BY a.time
-- LIMIT 1000;

-- Q30. Regions with most deep-focus earthquakes (depth >300 km)
SELECT location_region, COUNT(*) AS deep_focus_count
FROM earthquakes
WHERE depth_km > 300 AND location_region IS NOT NULL
GROUP BY location_region
ORDER BY deep_focus_count DESC
LIMIT 20;
