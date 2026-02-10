-- ============================================
-- DreamWorks Event Planner - Test Data
-- ============================================
-- This script populates sample events and registrations
-- for testing and demonstration purposes.
-- 
-- Note: Dates are stored as Unix timestamps (bigint)

-- Clear existing test data
DELETE FROM event_planner_registrations WHERE email LIKE '%@example.com' OR email LIKE '%@test.com';
DELETE FROM event_planner_events WHERE event_name LIKE 'Demo:%' OR event_name LIKE 'Test:%';

-- ============================================
-- Sample Event Configurations
-- ============================================
-- Using EXTRACT(EPOCH FROM ...) for Unix timestamps

-- Active Events (registration currently open)
INSERT INTO event_planner_events (
    event_name, category, event_date, 
    registration_start, registration_end, 
    created
) VALUES 
-- Online Workshop - Active (event in 14 days)
(
    'Demo: Introduction to Python Programming',
    'Online Workshop',
    EXTRACT(EPOCH FROM (CURRENT_DATE + INTERVAL '14 days'))::bigint,
    EXTRACT(EPOCH FROM (CURRENT_DATE - INTERVAL '7 days'))::bigint,
    EXTRACT(EPOCH FROM (CURRENT_DATE + INTERVAL '10 days'))::bigint,
    EXTRACT(EPOCH FROM NOW())::bigint
),
-- Hackathon - Active (event in 30 days)
(
    'Demo: AI Innovation Hackathon 2026',
    'Hackathon',
    EXTRACT(EPOCH FROM (CURRENT_DATE + INTERVAL '30 days'))::bigint,
    EXTRACT(EPOCH FROM (CURRENT_DATE - INTERVAL '14 days'))::bigint,
    EXTRACT(EPOCH FROM (CURRENT_DATE + INTERVAL '25 days'))::bigint,
    EXTRACT(EPOCH FROM NOW())::bigint
),
-- Conference - Active (event in 45 days)
(
    'Demo: Tech Summit 2026',
    'Conference',
    EXTRACT(EPOCH FROM (CURRENT_DATE + INTERVAL '45 days'))::bigint,
    EXTRACT(EPOCH FROM (CURRENT_DATE - INTERVAL '30 days'))::bigint,
    EXTRACT(EPOCH FROM (CURRENT_DATE + INTERVAL '40 days'))::bigint,
    EXTRACT(EPOCH FROM NOW())::bigint
),
-- One-day Workshop - Active (event in 7 days)
(
    'Demo: Cloud Computing Fundamentals',
    'One-day Workshop',
    EXTRACT(EPOCH FROM (CURRENT_DATE + INTERVAL '7 days'))::bigint,
    EXTRACT(EPOCH FROM (CURRENT_DATE - INTERVAL '10 days'))::bigint,
    EXTRACT(EPOCH FROM (CURRENT_DATE + INTERVAL '5 days'))::bigint,
    EXTRACT(EPOCH FROM NOW())::bigint
),
-- Multiple events on same category/date for testing dropdowns
(
    'Demo: Advanced Machine Learning',
    'Online Workshop',
    EXTRACT(EPOCH FROM (CURRENT_DATE + INTERVAL '14 days'))::bigint,
    EXTRACT(EPOCH FROM (CURRENT_DATE - INTERVAL '7 days'))::bigint,
    EXTRACT(EPOCH FROM (CURRENT_DATE + INTERVAL '10 days'))::bigint,
    EXTRACT(EPOCH FROM NOW())::bigint
),
(
    'Demo: Web Development Bootcamp',
    'Online Workshop',
    EXTRACT(EPOCH FROM (CURRENT_DATE + INTERVAL '21 days'))::bigint,
    EXTRACT(EPOCH FROM (CURRENT_DATE - INTERVAL '5 days'))::bigint,
    EXTRACT(EPOCH FROM (CURRENT_DATE + INTERVAL '18 days'))::bigint,
    EXTRACT(EPOCH FROM NOW())::bigint
),
-- Past Events (for admin listing - registration closed)
(
    'Demo: Past Conference 2025',
    'Conference',
    EXTRACT(EPOCH FROM (CURRENT_DATE - INTERVAL '60 days'))::bigint,
    EXTRACT(EPOCH FROM (CURRENT_DATE - INTERVAL '90 days'))::bigint,
    EXTRACT(EPOCH FROM (CURRENT_DATE - INTERVAL '65 days'))::bigint,
    EXTRACT(EPOCH FROM (NOW() - INTERVAL '90 days'))::bigint
),
(
    'Demo: Completed Hackathon',
    'Hackathon',
    EXTRACT(EPOCH FROM (CURRENT_DATE - INTERVAL '30 days'))::bigint,
    EXTRACT(EPOCH FROM (CURRENT_DATE - INTERVAL '60 days'))::bigint,
    EXTRACT(EPOCH FROM (CURRENT_DATE - INTERVAL '35 days'))::bigint,
    EXTRACT(EPOCH FROM (NOW() - INTERVAL '60 days'))::bigint
);

-- ============================================
-- Sample Registrations
-- ============================================

-- Get event IDs for registrations using a DO block
DO $$
DECLARE
    python_event_id INT;
    python_event_date BIGINT;
    hackathon_event_id INT;
    hackathon_event_date BIGINT;
    conference_event_id INT;
    conference_event_date BIGINT;
    cloud_event_id INT;
    cloud_event_date BIGINT;
    ml_event_id INT;
    ml_event_date BIGINT;
BEGIN
    -- Get event IDs and dates
    SELECT id, event_date INTO python_event_id, python_event_date 
    FROM event_planner_events WHERE event_name = 'Demo: Introduction to Python Programming' LIMIT 1;
    
    SELECT id, event_date INTO hackathon_event_id, hackathon_event_date 
    FROM event_planner_events WHERE event_name = 'Demo: AI Innovation Hackathon 2026' LIMIT 1;
    
    SELECT id, event_date INTO conference_event_id, conference_event_date 
    FROM event_planner_events WHERE event_name = 'Demo: Tech Summit 2026' LIMIT 1;
    
    SELECT id, event_date INTO cloud_event_id, cloud_event_date 
    FROM event_planner_events WHERE event_name = 'Demo: Cloud Computing Fundamentals' LIMIT 1;
    
    SELECT id, event_date INTO ml_event_id, ml_event_date 
    FROM event_planner_events WHERE event_name = 'Demo: Advanced Machine Learning' LIMIT 1;

    -- Insert registrations for Python Workshop
    IF python_event_id IS NOT NULL THEN
        INSERT INTO event_planner_registrations (event_id, full_name, email, college_name, department, category, event_date, event_name, created)
        VALUES 
            (python_event_id, 'Alice Johnson', 'alice.johnson@example.com', 'MIT', 'Computer Science', 'Online Workshop', python_event_date, 'Demo: Introduction to Python Programming', EXTRACT(EPOCH FROM (NOW() - INTERVAL '5 days'))::bigint),
            (python_event_id, 'Bob Smith', 'bob.smith@example.com', 'Stanford University', 'Information Technology', 'Online Workshop', python_event_date, 'Demo: Introduction to Python Programming', EXTRACT(EPOCH FROM (NOW() - INTERVAL '4 days'))::bigint),
            (python_event_id, 'Carol Williams', 'carol.williams@example.com', 'Harvard University', 'Data Science', 'Online Workshop', python_event_date, 'Demo: Introduction to Python Programming', EXTRACT(EPOCH FROM (NOW() - INTERVAL '3 days'))::bigint);
    END IF;

    -- Insert registrations for Hackathon
    IF hackathon_event_id IS NOT NULL THEN
        INSERT INTO event_planner_registrations (event_id, full_name, email, college_name, department, category, event_date, event_name, created)
        VALUES 
            (hackathon_event_id, 'David Brown', 'david.brown@example.com', 'Caltech', 'Artificial Intelligence', 'Hackathon', hackathon_event_date, 'Demo: AI Innovation Hackathon 2026', EXTRACT(EPOCH FROM (NOW() - INTERVAL '10 days'))::bigint),
            (hackathon_event_id, 'Eva Martinez', 'eva.martinez@example.com', 'UC Berkeley', 'Machine Learning', 'Hackathon', hackathon_event_date, 'Demo: AI Innovation Hackathon 2026', EXTRACT(EPOCH FROM (NOW() - INTERVAL '8 days'))::bigint),
            (hackathon_event_id, 'Frank Lee', 'frank.lee@example.com', 'Princeton', 'Computer Engineering', 'Hackathon', hackathon_event_date, 'Demo: AI Innovation Hackathon 2026', EXTRACT(EPOCH FROM (NOW() - INTERVAL '6 days'))::bigint),
            (hackathon_event_id, 'Grace Kim', 'grace.kim@example.com', 'Yale University', 'Software Engineering', 'Hackathon', hackathon_event_date, 'Demo: AI Innovation Hackathon 2026', EXTRACT(EPOCH FROM (NOW() - INTERVAL '2 days'))::bigint);
    END IF;

    -- Insert registrations for Conference
    IF conference_event_id IS NOT NULL THEN
        INSERT INTO event_planner_registrations (event_id, full_name, email, college_name, department, category, event_date, event_name, created)
        VALUES 
            (conference_event_id, 'Henry Wilson', 'henry.wilson@example.com', 'Columbia University', 'Information Systems', 'Conference', conference_event_date, 'Demo: Tech Summit 2026', EXTRACT(EPOCH FROM (NOW() - INTERVAL '20 days'))::bigint),
            (conference_event_id, 'Ivy Chen', 'ivy.chen@example.com', 'Cornell University', 'Computer Science', 'Conference', conference_event_date, 'Demo: Tech Summit 2026', EXTRACT(EPOCH FROM (NOW() - INTERVAL '15 days'))::bigint);
    END IF;

    -- Insert registrations for Cloud Workshop
    IF cloud_event_id IS NOT NULL THEN
        INSERT INTO event_planner_registrations (event_id, full_name, email, college_name, department, category, event_date, event_name, created)
        VALUES 
            (cloud_event_id, 'Jack Taylor', 'jack.taylor@example.com', 'Duke University', 'Cloud Computing', 'One-day Workshop', cloud_event_date, 'Demo: Cloud Computing Fundamentals', EXTRACT(EPOCH FROM (NOW() - INTERVAL '3 days'))::bigint),
            (cloud_event_id, 'Karen Davis', 'karen.davis@example.com', 'Northwestern', 'DevOps', 'One-day Workshop', cloud_event_date, 'Demo: Cloud Computing Fundamentals', EXTRACT(EPOCH FROM (NOW() - INTERVAL '1 day'))::bigint);
    END IF;

    -- Insert registrations for ML Workshop
    IF ml_event_id IS NOT NULL THEN
        INSERT INTO event_planner_registrations (event_id, full_name, email, college_name, department, category, event_date, event_name, created)
        VALUES 
            (ml_event_id, 'Leo Anderson', 'leo.anderson@example.com', 'UCLA', 'Machine Learning', 'Online Workshop', ml_event_date, 'Demo: Advanced Machine Learning', EXTRACT(EPOCH FROM (NOW() - INTERVAL '2 days'))::bigint),
            (ml_event_id, 'Maria Garcia', 'maria.garcia@test.com', 'USC', 'Data Engineering', 'Online Workshop', ml_event_date, 'Demo: Advanced Machine Learning', EXTRACT(EPOCH FROM NOW())::bigint);
    END IF;

END $$;

-- ============================================
-- Verification Queries
-- ============================================
-- Show inserted events
SELECT 
    id,
    SUBSTRING(event_name, 1, 45) as event_name,
    category,
    TO_CHAR(TO_TIMESTAMP(event_date), 'YYYY-MM-DD') as event_date,
    TO_CHAR(TO_TIMESTAMP(registration_start), 'YYYY-MM-DD') as reg_start,
    TO_CHAR(TO_TIMESTAMP(registration_end), 'YYYY-MM-DD') as reg_end
FROM event_planner_events 
WHERE event_name LIKE 'Demo:%'
ORDER BY event_date;

-- Show inserted registrations
SELECT 
    r.id,
    r.full_name,
    r.email,
    SUBSTRING(r.college_name, 1, 20) as college,
    r.category,
    TO_CHAR(TO_TIMESTAMP(r.event_date), 'YYYY-MM-DD') as event_date
FROM event_planner_registrations r
WHERE r.email LIKE '%@example.com' OR r.email LIKE '%@test.com'
ORDER BY r.created DESC;

-- Summary counts
SELECT 'Total Demo Events' as metric, COUNT(*)::text as value FROM event_planner_events WHERE event_name LIKE 'Demo:%'
UNION ALL
SELECT 'Total Test Registrations', COUNT(*)::text FROM event_planner_registrations WHERE email LIKE '%@example.com' OR email LIKE '%@test.com';
