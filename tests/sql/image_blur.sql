BEGIN;

CREATE EXTENSION anon CASCADE;

SELECT anon.init();

CREATE SCHEMA shipping;

-- Delivery_address
CREATE TABLE shipping.delivery_address (
  oid SERIAL PRIMARY KEY,
  sensitive_barcode BYTEA,
  image_data BYTEA
);

ALTER TABLE shipping.delivery_address CLUSTER ON delivery_address_pkey;
GRANT SELECT ON TABLE shipping.delivery_address TO PUBLIC;

COMMENT ON TABLE shipping.delivery_address IS 'Fake Adresses with barcode';
COMMENT ON COLUMN shipping.delivery_address.sensitive_barcode IS 'This Barcode represents sensitive data.';

\! cp tests/sql/barcode1* /tmp

INSERT INTO shipping.delivery_address (sensitive_barcode) VALUES
  (pg_read_binary_file('/tmp/barcode1.jpg')),
  (pg_read_binary_file('/tmp/barcode1.gif')),
  (pg_read_binary_file('/tmp/barcode1.png')),
  (pg_read_binary_file('/tmp/barcode1.bmp')),
  (pg_read_binary_file('/tmp/barcode1.exr')),
  (pg_read_binary_file('/tmp/barcode1.tiff'));

SECURITY LABEL FOR anon ON COLUMN shipping.delivery_address.sensitive_barcode
IS 'MASKED WITH FUNCTION anon.image_blur(sensitive_barcode,1.0)';

INSERT INTO shipping.delivery_address (image_data) VALUES
  (pg_read_binary_file('/tmp/barcode1.jpg')),
  (pg_read_binary_file('/tmp/barcode1.gif')),
  (pg_read_binary_file('/tmp/barcode1.png')),
  (pg_read_binary_file('/tmp/barcode1.bmp')),
  (pg_read_binary_file('/tmp/barcode1.exr')),
  (pg_read_binary_file('/tmp/barcode1.tiff'));

SECURITY LABEL FOR anon ON COLUMN shipping.delivery_address.image_data
IS 'MASKED WITH FUNCTION anon.image_blur(image_data)';


SELECT anon.anonymize_table('shipping.delivery_address');

DROP TABLE shipping.delivery_address;
DROP SCHEMA shipping;

DROP EXTENSION anon CASCADE;

ROLLBACK;
