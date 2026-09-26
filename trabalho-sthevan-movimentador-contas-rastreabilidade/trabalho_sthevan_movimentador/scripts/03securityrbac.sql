-- ============================================================================
-- PROJETO: Movimentador de Contas e Rastreabilidade
-- ALUNO: Sthevan Vinicius de Araujo Martins
-- ARQUIVO: 03securityrbac.sql
-- RBAC + menor privilégio + LGPD
-- ============================================================================

\set ON_ERROR_STOP on
\connect movimentador_contas

-- Higienização do acesso padrão.
REVOKE ALL ON SCHEMA workflow FROM PUBLIC;
REVOKE ALL ON SCHEMA audit FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA workflow FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA workflow FROM PUBLIC;

-- Roles funcionais sem login.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'role_operacional') THEN
        CREATE ROLE role_operacional NOLOGIN;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'role_gestao') THEN
        CREATE ROLE role_gestao NOLOGIN;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'role_admin_workflow') THEN
        CREATE ROLE role_admin_workflow NOLOGIN;
    END IF;
END $$;

-- OPERACIONAL
GRANT USAGE ON SCHEMA workflow TO role_operacional;

GRANT SELECT ON
    workflow.setores,
    workflow.contas_workflow,
    workflow.movimentacoes,
    workflow.comentarios
TO role_operacional;

-- Somente colunas necessárias da tabela de usuários.
GRANT SELECT (id, login_corporativo, nome_completo, setor_id, status)
ON workflow.usuarios TO role_operacional;

GRANT INSERT ON workflow.movimentacoes TO role_operacional;
GRANT INSERT ON workflow.comentarios TO role_operacional;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA workflow
TO role_operacional;

-- Histórico: sem UPDATE e DELETE.
REVOKE UPDATE, DELETE ON workflow.movimentacoes FROM role_operacional;

-- GESTAO: somente views seguras.
GRANT USAGE ON SCHEMA workflow TO role_gestao;

-- ADMIN
GRANT USAGE, CREATE ON SCHEMA workflow TO role_admin_workflow;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA workflow TO role_admin_workflow;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA workflow TO role_admin_workflow;

-- View 1: consolidado por setor.
CREATE OR REPLACE VIEW workflow.vw_gestao_setores AS
SELECT
    s.nome AS setor,
    s.status,
    COUNT(DISTINCT c.id) AS total_contas,
    COUNT(DISTINCT CASE
        WHEN c.status_conta <> 'FINALIZADA' THEN c.id
    END) AS contas_em_fluxo,
    COALESCE(SUM(c.valor_aproximado), 0)::NUMERIC(14,2)
        AS valor_total_aproximado,
    ROUND(
        COALESCE(
            AVG(EXTRACT(EPOCH FROM
                (CURRENT_TIMESTAMP - c.data_entrada_fluxo)
            ) / 3600.0),
            0
        )::NUMERIC,
        2
    ) AS tempo_medio_horas
FROM workflow.setores s
LEFT JOIN workflow.contas_workflow c
    ON c.setor_atual_id = s.id
GROUP BY s.id, s.nome, s.status;

-- View 2: fluxo resumido sem credenciais ou PII.
CREATE OR REPLACE VIEW workflow.vw_fluxo_resumido AS
SELECT
    so.nome AS setor_origem,
    sd.nome AS setor_destino,
    COUNT(*) AS total_movimentacoes,
    MIN(m.movimentado_em) AS primeira_movimentacao,
    MAX(m.movimentado_em) AS ultima_movimentacao
FROM workflow.movimentacoes m
JOIN workflow.setores so ON so.id = m.setor_origem_id
JOIN workflow.setores sd ON sd.id = m.setor_destino_id
GROUP BY so.nome, sd.nome;

GRANT SELECT ON
    workflow.vw_gestao_setores,
    workflow.vw_fluxo_resumido
TO role_gestao;

-- Logins do laboratório.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_auditor_op') THEN
        CREATE ROLE usr_auditor_op LOGIN PASSWORD 'Sthevan_Auditor_2026!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_coordenador_gestao') THEN
        CREATE ROLE usr_coordenador_gestao LOGIN PASSWORD 'Sthevan_Gestao_2026!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'usr_dba_admin') THEN
        CREATE ROLE usr_dba_admin LOGIN PASSWORD 'Sthevan_Dba_2026!';
    END IF;
END $$;

GRANT role_operacional TO usr_auditor_op;
GRANT role_gestao TO usr_coordenador_gestao;
GRANT role_admin_workflow TO usr_dba_admin;

-- Gestão não recebe acesso às tabelas-base.
REVOKE ALL ON ALL TABLES IN SCHEMA workflow FROM usr_coordenador_gestao;
GRANT USAGE ON SCHEMA workflow TO usr_coordenador_gestao;
GRANT SELECT ON
    workflow.vw_gestao_setores,
    workflow.vw_fluxo_resumido
TO usr_coordenador_gestao;

-- Auditoria não é acessível diretamente aos perfis comuns.
REVOKE ALL ON SCHEMA audit FROM usr_auditor_op;
REVOKE ALL ON SCHEMA audit FROM usr_coordenador_gestao;

\echo 'ETAPA 2 concluída: RBAC, menor privilégio e views LGPD configurados.'
