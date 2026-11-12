-- Composite index tailored for the reporting query:
-- Filters by equality on city and range on created_at, then groups by org_id and status.
-- Including amount enables an Index-Only Scan without hitting the heap.
CREATE INDEX IF NOT EXISTS idx_hotel_bookings_city_created_org_status 
ON hotel_bookings (city, created_at, org_id, status) 
INCLUDE (amount);

-- Foreign key lookup index for event history queries
CREATE INDEX IF NOT EXISTS idx_booking_events_booking_id 
ON booking_events (booking_id);
