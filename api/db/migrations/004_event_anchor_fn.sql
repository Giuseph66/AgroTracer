-- core.event é append-only para a aplicação (R7): o papel traceagro_app não tem
-- UPDATE na tabela. Mas duas colunas mudam legitimamente após o aceite —
-- sync_status e blockchain_tx_id, quando a âncora confirma (Doc 8 §5).
--
-- Em vez de conceder UPDATE amplo (que abriria a porta para reescrever peso,
-- data ou autoria), a transição permitida é exposta como uma função estreita:
-- ela só toca essas colunas, só avança para CONFIRMED_ON_BLOCKCHAIN e só a
-- partir de PENDING_BLOCKCHAIN.

CREATE OR REPLACE FUNCTION core.confirm_event_anchor(
  p_event_id uuid,
  p_tx_id    text
) RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
  UPDATE core.event
     SET sync_status = 'CONFIRMED_ON_BLOCKCHAIN',
         blockchain_tx_id = p_tx_id
   WHERE id = p_event_id
     AND sync_status = 'PENDING_BLOCKCHAIN';
$$;

REVOKE ALL ON FUNCTION core.confirm_event_anchor(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION core.confirm_event_anchor(uuid, text) TO traceagro_app;
