BEGIN;

CREATE EXTENSION IF NOT EXISTS anon;

-- Table test
CREATE TABLE tb_pessoas (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(100),
    telefone VARCHAR(15),
    cpf VARCHAR(14),
    direccion VARCHAR(100),
    email VARCHAR(100)
);

ALTER TABLE tb_pessoas DROP COLUMN direccion;


-- Data fake for simulation
INSERT INTO tb_pessoas (id, nome, telefone, cpf, email) VALUES
(1, 'Daniel Campos Matos', '11999887766', '123.456.789-01','daniel.matos@alo.com.br'),
(2, 'Maria Luísa Pereira', '31888884455', '234.567.890-12', 'maria.oliveira@alo.com.br'),
(3, 'Carlos Magalhães', '21898989899', '345.678.901-23', 'carlos.pereira@alo.com.br'),
(4, 'Zé do Email Nulo', '47997885544', '987.454.741-14', NULL);

-- Anonymized User
CREATE ROLE usuario_restrito WITH
  NOSUPERUSER
  NOCREATEDB
  NOCREATEROLE
  INHERIT
  LOGIN
  NOREPLICATION
  NOBYPASSRLS
  CONNECTION LIMIT -1;

COMMENT ON ROLE usuario_restrito IS 'Anonymized User';

GRANT SELECT ON TABLE tb_pessoas TO usuario_restrito;

SET anon.transparent_dynamic_masking TO true;

SECURITY LABEL FOR anon ON ROLE usuario_restrito IS 'MASKED';

SECURITY LABEL FOR anon ON COLUMN tb_pessoas.nome
  IS 'MASKED WITH VALUE $$CONFIDENCIAL$$';

SECURITY LABEL FOR anon ON COLUMN tb_pessoas.telefone
  IS 'MASKED WITH FUNCTION anon.partial(telefone, 0, ''******'', 4)';

SECURITY LABEL FOR anon ON COLUMN tb_pessoas.cpf
  IS 'MASKED WITH FUNCTION anon.partial(cpf, 3, ''XXXXXXXXXXX'', 0)';

SECURITY LABEL FOR anon ON COLUMN tb_pessoas.email
  IS 'MASKED WITH FUNCTION anon.partial_email(email)';

SELECT attisdropped
FROM pg_attribute
WHERE attrelid = 'tb_pessoas'::regclass
  AND attnum = 5
ORDER BY attnum;


SET ROLE usuario_restrito;

SELECT TRUE AS masking_subquery_is_ok
FROM (SELECT * FROM tb_pessoas) AS t
LIMIT 1;

SELECT bool_and(nome = 'CONFIDENCIAL')  FROM tb_pessoas;

ROLLBACK;
