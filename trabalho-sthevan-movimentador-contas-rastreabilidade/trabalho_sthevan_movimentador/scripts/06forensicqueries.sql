-- ============================================================================
-- PROJETO: Movimentador de Contas e Rastreabilidade
-- ALUNO: Sthevan Vinicius de Araujo Martins
-- ARQUIVO: 06forensicqueries.sql
-- Investigação forense
-- ============================================================================

\set ON_ERROR_STOP on
\connect movimentador_contas

-- 1. Visão geral da trilha.
SELECT
    id,
    schema_name,
    table_name,
    session_user_name,
    current_user_name,
    transaction_id,
    event_time,
    operation,
    row_old,
    row_new,
    client_addr,
    application_name
FROM audit.logged_actions
ORDER BY event_time DESC, id DESC;

-- 2. Autoria das alterações válidas.
SELECT
    id AS evento,
    table_name AS tabela,
    operation AS operacao,
    session_user_name AS usuario_sessao,
    event_time AS data_hora,
    transaction_id
FROM audit.logged_actions
ORDER BY event_time DESC;

-- 3. Movimentações registradas.
SELECT
    id AS evento_auditoria,
    session_user_name AS usuario,
    event_time AS data_hora,
    row_new ->> 'conta_id' AS conta_id,
    row_new ->> 'setor_origem_id' AS setor_origem,
    row_new ->> 'setor_destino_id' AS setor_destino,
    row_new ->> 'usuario_executor_id' AS executor
FROM audit.logged_actions
WHERE table_name = 'movimentacoes'
  AND operation = 'I'
ORDER BY event_time DESC;

-- 4. Comparação OLD/NEW das alterações.
SELECT
    id AS evento,
    session_user_name AS usuario,
    event_time,
    operation,
    row_old,
    row_new
FROM audit.logged_actions
WHERE operation IN ('U', 'D')
ORDER BY event_time DESC;

-- 5. Quantidade de eventos por tabela/operação.
SELECT
    table_name,
    operation,
    COUNT(*) AS quantidade_eventos
FROM audit.logged_actions
GROUP BY table_name, operation
ORDER BY table_name, operation;

-- 6. Atividade por usuário.
SELECT
    session_user_name AS usuario,
    COUNT(*) AS total_eventos,
    MIN(event_time) AS primeiro_evento,
    MAX(event_time) AS ultimo_evento
FROM audit.logged_actions
GROUP BY session_user_name
ORDER BY total_eventos DESC;

-- 7. Estado OLD -> NEW de contas.
SELECT
    id AS evento,
    session_user_name AS usuario,
    event_time,
    row_old ->> 'status_conta' AS status_anterior,
    row_new ->> 'status_conta' AS status_novo,
    row_old ->> 'setor_atual_id' AS setor_anterior,
    row_new ->> 'setor_atual_id' AS setor_novo
FROM audit.logged_actions
WHERE table_name = 'contas_workflow'
  AND operation = 'U'
ORDER BY event_time DESC;

-- 8. Consulta final da investigação.
SELECT
    id,
    table_name,
    operation,
    session_user_name,
    event_time,
    transaction_id,
    row_old,
    row_new
FROM audit.logged_actions
WHERE table_name IN ('contas_workflow', 'movimentacoes')
ORDER BY event_time ASC;
