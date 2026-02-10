CREATE TABLE event_planner_events (
  id SERIAL PRIMARY KEY,
  registration_start INTEGER NOT NULL,
  registration_end INTEGER NOT NULL,
  event_date INTEGER NOT NULL,
  event_name VARCHAR(255) NOT NULL,
  category VARCHAR(64) NOT NULL,
  created INTEGER NOT NULL
);

CREATE INDEX event_planner_events_category_date_idx ON event_planner_events (category, event_date);
CREATE INDEX event_planner_events_registration_window_idx ON event_planner_events (registration_start, registration_end);

CREATE TABLE event_planner_registrations (
  id SERIAL PRIMARY KEY,
  event_id INTEGER NOT NULL,
  full_name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL,
  college_name VARCHAR(255) NOT NULL,
  department VARCHAR(255) NOT NULL,
  category VARCHAR(64) NOT NULL,
  event_date INTEGER NOT NULL,
  event_name VARCHAR(255) NOT NULL,
  created INTEGER NOT NULL
);

CREATE INDEX event_planner_registrations_event_email_date_idx ON event_planner_registrations (event_id, email, event_date);
CREATE INDEX event_planner_registrations_event_date_name_idx ON event_planner_registrations (event_date, event_name);
