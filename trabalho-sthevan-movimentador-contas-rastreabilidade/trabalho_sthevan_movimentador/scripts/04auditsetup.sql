-- ============================================================================
-- PROJETO: Movimentador de Contas e Rastreabilidade
-- ALUNO: Sthevan Vinicius de Araujo Martins
-- ARQUIVO: 04auditsetup.sql
-- Auditoria com OLD/NEW, usuário, timestamp e SECURITY DEFINER
-- ============================================================================

\set ON_ERROR_STOP on
\connect movimentador_contas

CREATE TABLE IF NOT EXISTS audit.logged_actions (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    schema_name TEXT NOT NULL,
    table_name TEXT NOT NULL,
    session_user_name TEXT NOT NULL,
    current_user_name TEXT NOT NULL,
    transaction_id BIGINT,
    event_time TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    operation CHAR(1) NOT NULL,
    row_old JSONB,
    row_new JSONB,
    client_addr INET,
    application_name TEXT,

    CONSTRAINT ck_logged_actions_operation
        CHECK (operation IN ('I', 'U', 'D'))
);

CREATE INDEX IF NOT EXISTS idx_logged_actions_event_time
    ON audit.logged_actions(event_time);

CREATE INDEX IF NOT EXISTS idx_logged_actions_table_operation
    ON audit.logged_actions(table_name, operation);

CREATE INDEX IF NOT EXISTS idx_logged_actions_session_user
    ON audit.logged_actions(session_user_name);

CREATE OR REPLACE FUNCTION audit.fn_log_workflow_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, audit
AS $$
BEGIN
    INSERT INTO audit.logged_actions (
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
    )
    VALUES (
        TG_TABLE_SCHEMA,
        TG_TABLE_NAME,
        session_user,
        current_user,
        txid_current(),
        clock_timestamp(),
        LEFT(TG_OP, 1),
        CASE
            WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD)
            ELSE NULL
        END,
        CASE
            WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW)
            ELSE NULL
        END,
        inet_client_addr(),
        current_setting('application_name', true)
    );

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION audit.fn_log_workflow_changes() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_audit_contas ON workflow.contas_workflow;
CREATE TRIGGER trg_audit_contas
AFTER INSERT OR UPDATE OR DELETE
ON workflow.contas_workflow
FOR EACH ROW
EXECUTE FUNCTION audit.fn_log_workflow_changes();

DROP TRIGGER IF EXISTS trg_audit_movimentacoes ON workflow.movimentacoes;
CREATE TRIGGER trg_audit_movimentacoes
AFTER INSERT OR UPDATE OR DELETE
ON workflow.movimentacoes
FOR EACH ROW
EXECUTE FUNCTION audit.fn_log_workflow_changes();

REVOKE ALL ON SCHEMA audit FROM PUBLIC;
REVOKE ALL ON TABLE audit.logged_actions FROM PUBLIC;

GRANT USAGE ON SCHEMA audit TO role_admin_workflow;
GRANT SELECT ON audit.logged_actions TO role_admin_workflow;

\echo 'ETAPA 3 concluída: auditoria e triggers configurados.'
