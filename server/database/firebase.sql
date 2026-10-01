CREATE TABLE IF NOT EXISTS firebase_devices (
 token_hash CHAR(64) PRIMARY KEY, user_id BIGINT NOT NULL,
 token TEXT NOT NULL, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS firebase_push_delivery (
 notification_id BIGINT NOT NULL, token_hash CHAR(64) NOT NULL,
 PRIMARY KEY (notification_id, token_hash)
);
CREATE TABLE IF NOT EXISTS firebase_profiles (
 user_id BIGINT PRIMARY KEY, avatar_url TEXT
);
CREATE TABLE IF NOT EXISTS firebase_room_photos (
 room_id BIGINT PRIMARY KEY, photo_url TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS firebase_google_links (
 google_uid VARCHAR(128) PRIMARY KEY, user_id BIGINT NOT NULL UNIQUE
);
CREATE TABLE IF NOT EXISTS firebase_invoice_reminders (
 invoice_id BIGINT NOT NULL, reminder_date DATE NOT NULL,
 PRIMARY KEY (invoice_id, reminder_date)
);
