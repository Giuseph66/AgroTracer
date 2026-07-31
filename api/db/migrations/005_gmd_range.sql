-- numeric(5,3) comporta no máximo 99,999 kg/dia. O limite é razoável para um
-- GMD real, mas não para o resultado intermediário quando duas pesagens caem
-- no mesmo dia (o denominador vira fração de dia e o valor explode).
--
-- A correção de verdade está na projeção, que passa a exigir intervalo mínimo
-- de um dia entre pesagens para calcular GMD. A coluna é alargada como defesa
-- em profundidade: um dado de campo estranho vira número feio, não erro 500
-- que derruba a ingestão de um evento legítimo.

ALTER TABLE read_model.animal_state
  ALTER COLUMN gmd_kg_day TYPE numeric(7,3);
