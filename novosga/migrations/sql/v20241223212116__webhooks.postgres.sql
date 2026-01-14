DO $body$
BEGIN

CREATE TABLE webhooks (
    id SERIAL PRIMARY KEY,
    name VARCHAR(80) NOT NULL,
    url VARCHAR(255) NOT NULL,
    headers JSON NOT NULL,
    events JSON NOT NULL,
    enabled BOOLEAN NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT NULL
);

END $body$;
