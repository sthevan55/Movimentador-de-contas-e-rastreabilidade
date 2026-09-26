-- ============================================================================
-- PROJETO: Movimentador de Contas e Rastreabilidade
-- ALUNO: Sthevan Vinicius de Araujo Martins
-- ARQUIVO: 05attacksimulation.sql
-- Testes ofensivos e operações válidas
-- ============================================================================
-- Os comandos de bloqueio devem ser executados em sessões separadas,
-- conectadas com o usuário indicado. Não transformar os testes negados
-- em comentários se a intenção for gerar as evidências reais.

\connect movimentador_contas

\echo '=============================================================='
\echo 'CENARIO A - usr_auditor_op - DELETE indevido'
\echo 'Resultado esperado: permission denied'
\echo '=============================================================='

-- Conecte como usr_auditor_op e execute:
-- DELETE FROM workflow.movimentacoes WHERE id = 1;

\echo '=============================================================='
\echo 'CENARIO A - usr_auditor_op - UPDATE indevido'
\echo 'Resultado esperado: permission denied'
\echo '=============================================================='

-- UPDATE workflow.movimentacoes
-- SET observacoes = 'ALTERACAO INDEVIDA'
-- WHERE id = 1;

\echo '=============================================================='
\echo 'CENARIO B - usr_auditor_op - coluna restrita'
\echo 'Resultado esperado: permission denied'
\echo '=============================================================='

-- SELECT id, login_corporativo, nome_completo, credencial_hash
-- FROM workflow.usuarios;

\echo 'Consulta operacional permitida:'

-- SELECT id, login_corporativo, nome_completo, setor_id, status
-- FROM workflow.usuarios;

\echo '=============================================================='
\echo 'CENARIO C - operacao valida'
\echo 'Executar como usr_auditor_op'
\echo '=============================================================='

-- INSERT INTO workflow.movimentacoes
-- (conta_id, setor_origem_id, setor_destino_id, usuario_executor_id, observacoes)
-- VALUES (
--     (SELECT id FROM workflow.contas_workflow
--      WHERE codigo_conta = 'CT-2026-001'),
--     (SELECT id FROM workflow.setores WHERE nome = 'Auditoria'),
--     (SELECT id FROM workflow.setores WHERE nome = 'Central de Guias'),
--     (SELECT id FROM workflow.usuarios
--      WHERE login_corporativo = 'usr_auditor_op'),
--     'Movimentacao válida realizada durante homologacao.'
-- );

-- INSERT INTO workflow.comentarios
-- (conta_id, usuario_autor_id, descricao)
-- VALUES (
--     (SELECT id FROM workflow.contas_workflow
--      WHERE codigo_conta = 'CT-2026-001'),
--     (SELECT id FROM workflow.usuarios
--      WHERE login_corporativo = 'usr_auditor_op'),
--     'Conta encaminhada para a Central de Guias após conferência.'
-- );

\echo 'Observacao: bloqueios de privilegio ocorrem antes do trigger.'
\echo 'As tentativas negadas devem ser comprovadas pela mensagem do PostgreSQL'
\echo 'e, quando disponível, pelo log do servidor.'
