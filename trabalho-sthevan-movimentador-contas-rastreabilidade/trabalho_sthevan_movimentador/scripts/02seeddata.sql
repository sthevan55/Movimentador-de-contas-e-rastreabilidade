-- ============================================================================
-- PROJETO: Movimentador de Contas e Rastreabilidade
-- ALUNO: Sthevan Vinicius de Araujo Martins
-- ARQUIVO: 02seeddata.sql
-- ============================================================================

\set ON_ERROR_STOP on
\connect movimentador_contas

BEGIN;

-- Limpeza somente para laboratório, permitindo repetir a carga.
TRUNCATE TABLE
    workflow.comentarios,
    workflow.movimentacoes,
    workflow.contas_workflow,
    workflow.usuarios,
    workflow.setores
RESTART IDENTITY CASCADE;

-- 4 setores
INSERT INTO workflow.setores (nome, status) VALUES
('Auditoria', 'ATIVO'),
('Central de Guias', 'ATIVO'),
('Faturamento', 'ATIVO'),
('Recurso de Glosa', 'ATIVO');

-- 4 usuários funcionais.
INSERT INTO workflow.usuarios
(login_corporativo, nome_completo, setor_id, credencial_hash, perfil_acesso)
VALUES
(
    'usr_auditor_op',
    'Sthevan Operacional Auditoria',
    (SELECT id FROM workflow.setores WHERE nome = 'Auditoria'),
    crypt('HashDemo_01', gen_salt('bf')),
    'OPERACIONAL'
),
(
    'usr_coordenador_gestao',
    'Mariana Coordenacao Gestao',
    (SELECT id FROM workflow.setores WHERE nome = 'Faturamento'),
    crypt('HashDemo_02', gen_salt('bf')),
    'GESTAO'
),
(
    'usr_dba_admin',
    'Rafael DBA Administrador',
    (SELECT id FROM workflow.setores WHERE nome = 'Auditoria'),
    crypt('HashDemo_03', gen_salt('bf')),
    'ADMINISTRADOR'
),
(
    'usr_faturamento',
    'Lucas Analista Faturamento',
    (SELECT id FROM workflow.setores WHERE nome = 'Faturamento'),
    crypt('HashDemo_04', gen_salt('bf')),
    'OPERACIONAL'
);

-- 3 contas em trânsito.
INSERT INTO workflow.contas_workflow
(codigo_conta, convenio, valor_aproximado, setor_atual_id,
 data_entrada_fluxo, status_conta)
VALUES
(
    'CT-2026-001',
    'Convenio Vida Plena',
    12850.90,
    (SELECT id FROM workflow.setores WHERE nome = 'Auditoria'),
    CURRENT_TIMESTAMP - INTERVAL '3 days',
    'EM_ANALISE'
),
(
    'CT-2026-002',
    'Convenio Saude Integrada',
    7640.50,
    (SELECT id FROM workflow.setores WHERE nome = 'Central de Guias'),
    CURRENT_TIMESTAMP - INTERVAL '2 days',
    'AGUARDANDO_GUIA'
),
(
    'CT-2026-003',
    'Convenio Hospitalar Brasil',
    21980.00,
    (SELECT id FROM workflow.setores WHERE nome = 'Faturamento'),
    CURRENT_TIMESTAMP - INTERVAL '1 day',
    'EM_CONFERENCIA'
);

-- Movimentações iniciais.
INSERT INTO workflow.movimentacoes
(conta_id, setor_origem_id, setor_destino_id, usuario_executor_id, observacoes)
VALUES
(
    (SELECT id FROM workflow.contas_workflow WHERE codigo_conta = 'CT-2026-001'),
    (SELECT id FROM workflow.setores WHERE nome = 'Auditoria'),
    (SELECT id FROM workflow.setores WHERE nome = 'Central de Guias'),
    (SELECT id FROM workflow.usuarios WHERE login_corporativo = 'usr_auditor_op'),
    'Conta encaminhada para conferência da documentação.'
),
(
    (SELECT id FROM workflow.contas_workflow WHERE codigo_conta = 'CT-2026-002'),
    (SELECT id FROM workflow.setores WHERE nome = 'Central de Guias'),
    (SELECT id FROM workflow.setores WHERE nome = 'Faturamento'),
    (SELECT id FROM workflow.usuarios WHERE login_corporativo = 'usr_faturamento'),
    'Guia conferida e conta encaminhada ao faturamento.'
),
(
    (SELECT id FROM workflow.contas_workflow WHERE codigo_conta = 'CT-2026-003'),
    (SELECT id FROM workflow.setores WHERE nome = 'Faturamento'),
    (SELECT id FROM workflow.setores WHERE nome = 'Recurso de Glosa'),
    (SELECT id FROM workflow.usuarios WHERE login_corporativo = 'usr_faturamento'),
    'Conta enviada para análise de recurso de glosa.'
);

-- Comentários iniciais.
INSERT INTO workflow.comentarios
(conta_id, usuario_autor_id, descricao)
VALUES
(
    (SELECT id FROM workflow.contas_workflow WHERE codigo_conta = 'CT-2026-001'),
    (SELECT id FROM workflow.usuarios WHERE login_corporativo = 'usr_auditor_op'),
    'Aguardando documentação complementar.'
),
(
    (SELECT id FROM workflow.contas_workflow WHERE codigo_conta = 'CT-2026-002'),
    (SELECT id FROM workflow.usuarios WHERE login_corporativo = 'usr_faturamento'),
    'Guia recebida para conferência.'
),
(
    (SELECT id FROM workflow.contas_workflow WHERE codigo_conta = 'CT-2026-003'),
    (SELECT id FROM workflow.usuarios WHERE login_corporativo = 'usr_faturamento'),
    'Divergência identificada no processo de faturamento.'
);

COMMIT;

\echo 'ETAPA 2 - carga inicial concluída.'
\echo 'Foram cadastrados 4 setores, 4 usuários, 3 contas, 3 movimentações e 3 comentários.'
