BEGIN;

CREATE EXTENSION IF NOT EXISTS anon;

SELECT anon.partial('abcdefgh',1,'xxxx',3);

SELECT anon.partial('+33142928100',4,'******',2);

SELECT anon.partial_email('bruce.lee@enter.the.dragon.hk');

ROLLBACK;
