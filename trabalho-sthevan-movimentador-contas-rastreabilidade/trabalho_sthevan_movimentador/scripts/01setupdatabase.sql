-- ============================================================================
-- PROJETO: Movimentador de Contas e Rastreabilidade
-- ALUNO: Sthevan Vinicius de Araujo Martins
-- ETAPA 1: Provisionamento e modelagem física
-- ARQUIVO: 01setupdatabase.sql
-- SGBD: PostgreSQL 14 ou superior
-- ============================================================================

\set ON_ERROR_STOP on

-- O banco é criado somente se ainda não existir.
SELECT 'CREATE DATABASE movimentador_contas
WITH ENCODING = ''UTF8'' TEMPLATE = template0'
WHERE NOT EXISTS (
    SELECT 1 FROM pg_database WHERE datname = 'movimentador_contas'
) \gexec

\connect movimentador_contas

SET client_encoding = 'UTF8';
SET TIME ZONE 'America/Campo_Grande';

CREATE EXTENSION IF NOT EXISTS pgcrypto;

BEGIN;

CREATE SCHEMA IF NOT EXISTS workflow;
CREATE SCHEMA IF NOT EXISTS audit;

COMMENT ON SCHEMA workflow IS
'Dados operacionais do sistema Movimentador de Contas e Rastreabilidade.';

COMMENT ON SCHEMA audit IS
'Infraestrutura destinada à auditoria e investigação forense.';

-- SETORES
CREATE TABLE IF NOT EXISTS workflow.setores (
    id BIGINT GENERATED ALWAYS AS IDENTITY,
    nome VARCHAR(100) NOT NULL,
    status VARCHAR(10) NOT NULL DEFAULT 'ATIVO',
    criado_em TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_setores PRIMARY KEY (id),
    CONSTRAINT uq_setores_nome UNIQUE (nome),
    CONSTRAINT ck_setores_status CHECK (status IN ('ATIVO', 'INATIVO'))
);

-- USUARIOS
CREATE TABLE IF NOT EXISTS workflow.usuarios (
    id BIGINT GENERATED ALWAYS AS IDENTITY,
    login_corporativo VARCHAR(100) NOT NULL,
    nome_completo VARCHAR(150) NOT NULL,
    setor_id BIGINT NOT NULL,
    credencial_hash TEXT NOT NULL,
    perfil_acesso VARCHAR(20) NOT NULL,
    status VARCHAR(10) NOT NULL DEFAULT 'ATIVO',
    criado_em TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_usuarios PRIMARY KEY (id),
    CONSTRAINT uq_usuarios_login UNIQUE (login_corporativo),

    CONSTRAINT fk_usuarios_setor
        FOREIGN KEY (setor_id)
        REFERENCES workflow.setores(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_usuarios_perfil
        CHECK (perfil_acesso IN ('OPERACIONAL', 'GESTAO', 'ADMINISTRADOR')),

    CONSTRAINT ck_usuarios_status
        CHECK (status IN ('ATIVO', 'INATIVO')),

    CONSTRAINT ck_usuarios_login_nao_vazio
        CHECK (btrim(login_corporativo) <> ''),

    CONSTRAINT ck_usuarios_nome_nao_vazio
        CHECK (btrim(nome_completo) <> '')
);

COMMENT ON COLUMN workflow.usuarios.credencial_hash IS
'Hash da credencial. O acesso a esta coluna será restrito na etapa de segurança.';

-- CONTAS_WORKFLOW
CREATE TABLE IF NOT EXISTS workflow.contas_workflow (
    id BIGINT GENERATED ALWAYS AS IDENTITY,
    codigo_conta VARCHAR(30) NOT NULL,
    convenio VARCHAR(100) NOT NULL,
    valor_aproximado NUMERIC(14,2) NOT NULL,
    setor_atual_id BIGINT NOT NULL,
    data_entrada_fluxo TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status_conta VARCHAR(25) NOT NULL DEFAULT 'RECEBIDA',

    CONSTRAINT pk_contas_workflow PRIMARY KEY (id),
    CONSTRAINT uq_contas_workflow_codigo UNIQUE (codigo_conta),

    CONSTRAINT fk_contas_workflow_setor
        FOREIGN KEY (setor_atual_id)
        REFERENCES workflow.setores(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_contas_workflow_valor
        CHECK (valor_aproximado >= 0),

    CONSTRAINT ck_contas_workflow_status CHECK (
        status_conta IN (
            'RECEBIDA',
            'EM_ANALISE',
            'PENDENTE',
            'AGUARDANDO_GUIA',
            'EM_CONFERENCIA',
            'ENCAMINHADA',
            'DEVOLVIDA',
            'FINALIZADA'
        )
    )
);

-- MOVIMENTACOES
CREATE TABLE IF NOT EXISTS workflow.movimentacoes (
    id BIGINT GENERATED ALWAYS AS IDENTITY,
    conta_id BIGINT NOT NULL,
    setor_origem_id BIGINT NOT NULL,
    setor_destino_id BIGINT NOT NULL,
    usuario_executor_id BIGINT NOT NULL,
    movimentado_em TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    observacoes TEXT,

    CONSTRAINT pk_movimentacoes PRIMARY KEY (id),

    CONSTRAINT fk_movimentacoes_conta
        FOREIGN KEY (conta_id)
        REFERENCES workflow.contas_workflow(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_movimentacoes_origem
        FOREIGN KEY (setor_origem_id)
        REFERENCES workflow.setores(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_movimentacoes_destino
        FOREIGN KEY (setor_destino_id)
        REFERENCES workflow.setores(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_movimentacoes_usuario
        FOREIGN KEY (usuario_executor_id)
        REFERENCES workflow.usuarios(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_movimentacoes_setores_diferentes
        CHECK (setor_origem_id <> setor_destino_id)
);

-- COMENTARIOS
CREATE TABLE IF NOT EXISTS workflow.comentarios (
    id BIGINT GENERATED ALWAYS AS IDENTITY,
    conta_id BIGINT NOT NULL,
    usuario_autor_id BIGINT NOT NULL,
    comentado_em TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    descricao TEXT NOT NULL,

    CONSTRAINT pk_comentarios PRIMARY KEY (id),

    CONSTRAINT fk_comentarios_conta
        FOREIGN KEY (conta_id)
        REFERENCES workflow.contas_workflow(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT fk_comentarios_usuario
        FOREIGN KEY (usuario_autor_id)
        REFERENCES workflow.usuarios(id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CONSTRAINT ck_comentarios_descricao
        CHECK (btrim(descricao) <> '')
);

-- Índices para consultas frequentes e chaves estrangeiras.
CREATE INDEX IF NOT EXISTS idx_usuarios_setor
    ON workflow.usuarios(setor_id);

CREATE INDEX IF NOT EXISTS idx_contas_setor_atual
    ON workflow.contas_workflow(setor_atual_id);

CREATE INDEX IF NOT EXISTS idx_movimentacoes_conta_data
    ON workflow.movimentacoes(conta_id, movimentado_em);

CREATE INDEX IF NOT EXISTS idx_movimentacoes_origem_destino
    ON workflow.movimentacoes(setor_origem_id, setor_destino_id);

CREATE INDEX IF NOT EXISTS idx_comentarios_conta_data
    ON workflow.comentarios(conta_id, comentado_em);

COMMIT;

\echo 'ETAPA 1 concluída: banco, schemas, tabelas, constraints e índices criados.'
