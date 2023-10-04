SELECT COUNT(*) AS downloads
FROM app_downloads;

-- 23608

SELECT COUNT(*) AS users
FROM signups;

-- 17623

SELECT COUNT(*) AS ride_requests
FROM ride_requests;

-- 385477

SELECT COUNT(dropoff_ts) AS completed_trips
FROM ride_requests
WHERE dropoff_ts IS NOT NULL;

-- 223652

SELECT COUNT(DISTINCT user_id) AS unique_users_requested_ride
FROM ride_requests;

-- 12406

SELECT AVG(EXTRACT(EPOCH FROM (dropoff_ts - pickup_ts))) AS average_ride_duration_seconds
FROM ride_requests
WHERE pickup_ts IS NOT NULL AND dropoff_ts IS NOT NULL;

-- 3156.7387727362151915

SELECT COUNT(*) AS accepted_rides
FROM ride_requests
WHERE accept_ts IS NOT NULL;

-- 248379

SELECT 
    COUNT(*) AS successful_transactions,
    SUM(purchase_amount_usd) AS total_amount_collected
FROM transactions
WHERE charge_status = 'Approved';

-- 212628	4251667.609999998
-- Note, the schema uses 'approved' and 'cancelled' but the database uses 'Approved' and 'Decline'

SELECT 
    ad.platform,
    COUNT(rr.ride_id) AS ride_requests_count
FROM ride_requests rr
JOIN signups s ON rr.user_id = s.user_id
JOIN app_downloads ad ON s.session_id = ad.app_download_key
GROUP BY ad.platform;

-- "android"	"112317"
-- "ios"	"234693"
-- "web"	"38467"

WITH SignupCount AS (
    SELECT COUNT(*) AS total_signups
    FROM signups
),

RideRequestCount AS (
    SELECT COUNT(DISTINCT user_id) AS unique_users_requested_ride
    FROM ride_requests
)

SELECT 
    s.total_signups,
    r.unique_users_requested_ride,
    s.total_signups - r.unique_users_requested_ride AS drop_off
FROM SignupCount s, RideRequestCount r;

-- {"total_signups":"17623","unique_users_requested_ride":"12406","drop_off":"5217"}

WITH FunnelSteps AS (
    SELECT 
        'App Download' AS step,
        COUNT(DISTINCT app_download_key) AS count
    FROM app_downloads
    UNION ALL
    SELECT 
        'Signup',
        COUNT(DISTINCT user_id)
    FROM signups
    UNION ALL
    SELECT 
        'Request Ride',
        COUNT(DISTINCT user_id)
    FROM ride_requests
    UNION ALL
    SELECT 
        'Driver Acceptance',
        COUNT(DISTINCT user_id)
    FROM ride_requests
    WHERE accept_ts IS NOT NULL
    UNION ALL
    SELECT 
        'Ride Completed',
        COUNT(DISTINCT user_id)
    FROM ride_requests
    WHERE dropoff_ts IS NOT NULL
    UNION ALL
    SELECT 
        'Payment',
        COUNT(DISTINCT r.user_id)
    FROM transactions t
    JOIN ride_requests r ON t.ride_id = r.ride_id
    WHERE t.charge_status = 'Approved'
    UNION ALL
    SELECT 
        'Review',
        COUNT(DISTINCT user_id)
    FROM reviews
)

SELECT 
    step,
    count,
    ROUND(100.0 * count / FIRST_VALUE(count) OVER (), 2) AS percent_of_top,
    CASE 
        WHEN step = 'App Download' THEN NULL
        ELSE ROUND(100.0 * count / LAG(count) OVER (ORDER BY ordering), 2)
    END AS percent_of_previous
FROM (
    SELECT 
        step,
        count,
        CASE 
            WHEN step = 'App Download' THEN 1
            WHEN step = 'Signup' THEN 2
            WHEN step = 'Request Ride' THEN 3
            WHEN step = 'Driver Acceptance' THEN 4
            WHEN step = 'Ride Completed' THEN 5
            WHEN step = 'Payment' THEN 6
            WHEN step = 'Review' THEN 7
        END AS ordering
    FROM FunnelSteps
) AS OrderedSteps
ORDER BY ordering;

/*
| step              | count | percent_of_top | percent_of_previous |
| ----------------- | ----- | -------------- | ------------------- |
| App Download      | 23608 | 100.00         |                     |
| Signup            | 17623 | 74.65          | 74.65               |
| Request Ride      | 12406 | 52.55          | 70.40               |
| Driver Acceptance | 12278 | 52.01          | 98.97               |
| Ride Completed    | 6233  | 26.40          | 50.77               |
| Payment           | 6233  | 26.40          | 100.00              |
| Review            | 4348  | 18.42          | 69.76               |
 */