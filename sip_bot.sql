
DROP TABLE  Calls;

CREATE TABLE  Calls (
    id  INT(11) auto_increment,
    caller_id  VARCHAR(120),
    call_time  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expire_time  TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY (caller_id)
);
