CREATE TABLE list (
  id serial PRIMARY KEY,
  name text NOT NULL UNIQUE
);

CREATE TABLE todo (
  id serial PRIMARY KEY,
  name text NOT NULL,
  list_id int NOT NULL REFERENCES list(id)
    ON DELETE CASCADE,
  is_complete boolean NOT NULL DEFAULT false
);

UPDATE todo SET is_complete = true WHERE list_id = 1 and id = 1;