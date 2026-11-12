-- Seed 150 realistic hotel bookings across 4 orgs, 5 cities, and 4 statuses
WITH orgs AS (
    SELECT ARRAY[
        '11111111-1111-1111-1111-111111111111'::UUID,
        '22222222-2222-2222-2222-222222222222'::UUID,
        '33333333-3333-3333-3333-333333333333'::UUID,
        '44444444-4444-4444-4444-444444444444'::UUID
    ] AS ids
),
cities AS (
    SELECT ARRAY['delhi', 'mumbai', 'bengaluru', 'jaipur', 'goa'] AS names
),
statuses AS (
    SELECT ARRAY['CONFIRMED', 'PENDING', 'CANCELLED', 'COMPLETED'] AS vals
)
INSERT INTO hotel_bookings (
    id, org_id, hotel_id, city, checkin_date, checkout_date, amount, status, created_at
)
SELECT
    gen_random_uuid(),
    orgs.ids[1 + floor(random() * 4)::int],
    'HTL-' || lpad((100 + floor(random() * 50)::int)::text, 4, '0'),
    cities.names[1 + floor(random() * 5)::int],
    CURRENT_DATE + (floor(random() * 30)::int),
    CURRENT_DATE + (floor(random() * 30)::int + 1 + floor(random() * 5)::int),
    round((1500 + random() * 18500)::numeric, 2),
    statuses.vals[1 + floor(random() * 4)::int],
    NOW() - (random() * INTERVAL '60 days')
FROM generate_series(1, 150), orgs, cities, statuses;

-- Populate booking_events for roughly 60% of the seeded bookings
INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT
    id,
    CASE status
        WHEN 'CONFIRMED' THEN 'PAYMENT_CAPTURED'
        WHEN 'CANCELLED' THEN 'BOOKING_CANCELLED'
        WHEN 'COMPLETED' THEN 'GUEST_CHECKED_OUT'
        ELSE 'BOOKING_CREATED'
    END,
    jsonb_build_object(
        'source', 'seed_script',
        'amount', amount,
        'city', city
    ),
    created_at + INTERVAL '5 minutes'
FROM hotel_bookings
WHERE random() < 0.6;
