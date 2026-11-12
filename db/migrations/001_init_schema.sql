CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS hotel_bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL,
    hotel_id VARCHAR(100) NOT NULL,
    city VARCHAR(100) NOT NULL,
    checkin_date DATE NOT NULL,
    checkout_date DATE NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    status VARCHAR(50) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS booking_events (
    id BIGSERIAL PRIMARY KEY,
    booking_id UUID NOT NULL REFERENCES hotel_bookings(id) ON DELETE CASCADE,
    event_type VARCHAR(100) NOT NULL,
    payload JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
