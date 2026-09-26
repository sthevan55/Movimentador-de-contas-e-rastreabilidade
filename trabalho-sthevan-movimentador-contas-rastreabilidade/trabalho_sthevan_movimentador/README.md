# Movimentador de Contas e Rastreabilidade

Projeto prático da disciplina de **Administração de Banco de Dados (DBA)**, desenvolvido individualmente para aplicar conceitos de provisionamento, modelagem relacional, RBAC, menor privilégio, LGPD, auditoria e análise forense.

A estrutura técnica deste projeto foi desenvolvida tomando como referência a organização apresentada no repositório público **Movimentador de Contas e Rastreabilidade**, mantendo os mesmos seis marcos de implementação exigidos na atividade, porém com identificação, dados fictícios, comentários e documentação adaptados para este trabalho.

**Repositório de referência técnico:**  
https://github.com/kennedy1907big/Movimentador-de-contas-e-rastreabilidade

---

## 1. Identificação

**Instituição:** AEMS – Centro Universitário  
**Curso:** Análise e Desenvolvimento de Sistemas – 4º período  
**Disciplina:** Administração de Banco de Dados (DBA)  
**Aluno:** Sthevan Vinicius de Araujo Martins  
**Projeto:** Movimentador de Contas e Rastreabilidade  
**SGBD:** PostgreSQL 14 ou superior  
**Modalidade:** Individual

---

## 2. Objetivo

O objetivo do projeto é provisionar e proteger uma base própria para o sistema satélite **Movimentador de Contas e Rastreabilidade**.

A ideia é manter no banco somente as informações necessárias ao workflow, como setores, usuários funcionais, contas em trânsito, movimentações e comentários.

A solução foi organizada para que:

- os dados de negócio fiquem separados dos dados de auditoria;
- cada usuário tenha somente os privilégios necessários;
- o histórico de movimentações não possa ser alterado pelo perfil operacional;
- informações de credenciais sejam protegidas;
- operações relevantes sejam registradas em uma trilha de auditoria;
- seja possível identificar quem realizou uma operação e quando ela ocorreu.

O enunciado solicita exatamente essa separação entre dados de negócio e infraestrutura/auditoria, além da implementação das tabelas relacionais e controles de acesso. 

---

## 3. Estrutura do repositório

```text
movimentador-contas-rastreabilidade/
│
├── README.md
│
└── scripts/
    ├── 01setupdatabase.sql
    ├── 02seeddata.sql
    ├── 03securityrbac.sql
    ├── 04auditsetup.sql
    ├── 05attacksimulation.sql
    └── 06forensicqueries.sql
```

A atividade exige os seis scripts separados para provisionamento/modelagem, carga inicial, segurança/RBAC, auditoria, simulação ofensiva e consultas forenses.

---

# 4. Arquitetura

A arquitetura lógica foi dividida em dois schemas:

```text
movimentador_contas
│
├── workflow
│   ├── setores
│   ├── usuarios
│   ├── contas_workflow
│   ├── movimentacoes
│   ├── comentarios
│   ├── vw_gestao_setores
│   └── vw_fluxo_resumido
│
└── audit
    └── logged_actions
```

### Schema workflow

Responsável pelos dados do processo:

- `setores`
- `usuarios`
- `contas_workflow`
- `movimentacoes`
- `comentarios`

### Schema audit

Responsável pela trilha técnica:

- `logged_actions`

Essa divisão facilita a segregação de funções e evita misturar as informações operacionais com os registros usados na investigação.

---

# 5. Modelagem relacional

## SETORES

Armazena os setores participantes do fluxo.

Principais campos:

- `id`
- `nome`
- `status`
- `criado_em`

## USUARIOS

Representa os usuários funcionais da aplicação.

Principais campos:

- `id`
- `login_corporativo`
- `nome_completo`
- `setor_id`
- `credencial_hash`
- `perfil_acesso`
- `status`

A coluna `credencial_hash` existe para demonstrar o tratamento de uma informação que não deve ser disponibilizada aos perfis comuns.

## CONTAS_WORKFLOW

Armazena a referência lógica das contas em trânsito.

Principais campos:

- `id`
- `codigo_conta`
- `convenio`
- `valor_aproximado`
- `setor_atual_id`
- `data_entrada_fluxo`
- `status_conta`

Foi utilizado `NUMERIC(14,2)` para representar valores financeiros sem depender de ponto flutuante.

## MOVIMENTACOES

Mantém o histórico de trânsito das contas.

Principais campos:

- `id`
- `conta_id`
- `setor_origem_id`
- `setor_destino_id`
- `usuario_executor_id`
- `movimentado_em`
- `observacoes`

É a principal tabela utilizada nos testes de imutabilidade.

## COMENTARIOS

Registra ocorrências e observações associadas às contas.

---

# 6. Integridade dos dados

A modelagem utiliza:

- `PRIMARY KEY`;
- `FOREIGN KEY`;
- `UNIQUE`;
- `NOT NULL`;
- `CHECK`;
- índices;
- `TIMESTAMPTZ`;
- `NUMERIC(14,2)`.

As chaves estrangeiras garantem que os relacionamentos entre contas, setores e usuários sejam válidos.

---

# 7. Carga inicial

O script `02seeddata.sql` cria:

| Entidade | Quantidade |
|---|---:|
| Setores | 4 |
| Usuários | 4 |
| Contas | 3 |
| Movimentações | 3 |
| Comentários | 3 |

Os nomes e valores são fictícios e foram usados apenas para a homologação acadêmica.

---

# 8. RBAC

O controle de acesso foi implementado utilizando **Role-Based Access Control**.

Foram criadas três roles funcionais:

```text
role_operacional
role_gestao
role_admin_workflow
```

As roles funcionais possuem `NOLOGIN`. Os usuários de banco recebem as permissões por meio dessas roles.

## 8.1 Perfil operacional

Usuário:

```text
usr_auditor_op
```

Role:

```text
role_operacional
```

Permissões:

- consultar setores;
- consultar contas;
- consultar movimentações;
- consultar comentários;
- consultar somente colunas públicas da tabela `usuarios`;
- inserir movimentações;
- inserir comentários.

Não possui:

- `UPDATE` em movimentações;
- `DELETE` em movimentações;
- acesso ao schema `audit`;
- acesso à coluna `credencial_hash`.

---

## 8.2 Perfil de gestão

Usuário:

```text
usr_coordenador_gestao
```

Role:

```text
role_gestao
```

A gestão não recebe acesso direto às tabelas operacionais.

Seu acesso é direcionado para:

```text
workflow.vw_gestao_setores
workflow.vw_fluxo_resumido
```

Isso permite acompanhar informações consolidadas sem liberar dados desnecessários.

---

## 8.3 Perfil administrativo

Usuário:

```text
usr_dba_admin
```

Role:

```text
role_admin_workflow
```

Possui os privilégios administrativos necessários para o banco do sistema satélite e acesso de leitura à trilha de auditoria.

---

# 9. LGPD e minimização

A proteção de dados foi aplicada diretamente no SGBD.

Para o perfil operacional, a tabela `workflow.usuarios` libera somente:

```text
id
login_corporativo
nome_completo
setor_id
status
```

A coluna:

```text
credencial_hash
```

não é liberada.

Também foram criadas views gerenciais para que a gestão receba informações agregadas.

O projeto não utiliza dados reais de pacientes, CPF, diagnóstico ou prontuário.

---

# 10. Views seguras

## `workflow.vw_gestao_setores`

Apresenta:

- setor;
- status;
- total de contas;
- contas em fluxo;
- valor total aproximado;
- tempo médio em horas.

## `workflow.vw_fluxo_resumido`

Apresenta:

- setor de origem;
- setor de destino;
- quantidade de movimentações;
- primeira movimentação;
- última movimentação.

As views não apresentam hashes de credenciais nem dados pessoais desnecessários.

---

# 11. Auditoria

O script `04auditsetup.sql` cria:

```text
audit.logged_actions
```

A tabela registra:

- schema;
- tabela;
- `session_user`;
- usuário efetivo;
- transação;
- timestamp;
- operação;
- `OLD`;
- `NEW`;
- endereço do cliente;
- aplicação utilizada, quando disponível.

As operações são representadas por:

```text
I = INSERT
U = UPDATE
D = DELETE
```

---

# 12. SECURITY DEFINER

A função:

```text
audit.fn_log_workflow_changes()
```

foi criada com:

```sql
SECURITY DEFINER
```

Isso permite que o trigger grave na tabela de auditoria utilizando privilégios controlados, sem entregar ao usuário operacional acesso direto à tabela de logs.

Também foi definido um `search_path` fixo dentro da função para reduzir riscos de resolução indevida de objetos.

---

# 13. Triggers

Os triggers são aplicados em:

```text
workflow.contas_workflow
workflow.movimentacoes
```

Assim, alterações feitas nessas tabelas podem gerar registros automáticos na auditoria.

Exemplo de fluxo:

```text
Usuário
   ↓
Tabela workflow
   ↓
Trigger
   ↓
Função SECURITY DEFINER
   ↓
audit.logged_actions
```

---

# 14. Simulação ofensiva

O arquivo:

```text
05attacksimulation.sql
```

foi organizado para testar três grupos de situações.

## Cenário A – adulteração de histórico

Conectar como:

```text
usr_auditor_op
```

Executar:

```sql
DELETE FROM workflow.movimentacoes
WHERE id = 1;
```

e:

```sql
UPDATE workflow.movimentacoes
SET observacoes = 'ALTERACAO INDEVIDA'
WHERE id = 1;
```

Resultado esperado:

```text
ERROR: permission denied for table movimentacoes
```

---

## Cenário B – acesso à coluna restrita

Como `usr_auditor_op`:

```sql
SELECT
    id,
    login_corporativo,
    nome_completo,
    credencial_hash
FROM workflow.usuarios;
```

A operação deve ser rejeitada.

Uma consulta permitida é:

```sql
SELECT
    id,
    login_corporativo,
    nome_completo,
    setor_id,
    status
FROM workflow.usuarios;
```

---

## Cenário C – operação válida

O usuário operacional pode inserir uma movimentação:

```sql
INSERT INTO workflow.movimentacoes
(
    conta_id,
    setor_origem_id,
    setor_destino_id,
    usuario_executor_id,
    observacoes
)
VALUES
(
    (SELECT id
     FROM workflow.contas_workflow
     WHERE codigo_conta = 'CT-2026-001'),

    (SELECT id
     FROM workflow.setores
     WHERE nome = 'Auditoria'),

    (SELECT id
     FROM workflow.setores
     WHERE nome = 'Central de Guias'),

    (SELECT id
     FROM workflow.usuarios
     WHERE login_corporativo = 'usr_auditor_op'),

    'Movimentacao valida realizada durante homologacao.'
);
```

Depois:

```sql
INSERT INTO workflow.comentarios
(
    conta_id,
    usuario_autor_id,
    descricao
)
VALUES
(
    (SELECT id
     FROM workflow.contas_workflow
     WHERE codigo_conta = 'CT-2026-001'),

    (SELECT id
     FROM workflow.usuarios
     WHERE login_corporativo = 'usr_auditor_op'),

    'Conta encaminhada para a Central de Guias após conferência.'
);
```

Essas operações devem ser registradas automaticamente pela auditoria.

---

# 15. Consultas forenses

O script `06forensicqueries.sql` permite investigar:

### Quem realizou a operação

```sql
SELECT
    id,
    table_name,
    operation,
    session_user_name,
    event_time,
    transaction_id
FROM audit.logged_actions
ORDER BY event_time DESC;
```

### OLD e NEW

```sql
SELECT
    id,
    session_user_name,
    event_time,
    operation,
    row_old,
    row_new
FROM audit.logged_actions
WHERE operation IN ('U', 'D')
ORDER BY event_time DESC;
```

### Operações de movimentação

```sql
SELECT
    id,
    session_user_name,
    event_time,
    row_new
FROM audit.logged_actions
WHERE table_name = 'movimentacoes'
  AND operation = 'I'
ORDER BY event_time DESC;
```

---

# 16. Ponto importante sobre as tentativas bloqueadas

Uma tentativa que é rejeitada pelo mecanismo de privilégios do PostgreSQL não chega a executar o comando na tabela.

Por consequência, o trigger da tabela não é acionado.

Então a comprovação fica dividida:

```text
Tentativa indevida
        ↓
PostgreSQL
        ↓
permission denied
```

A evidência deve ser o erro apresentado pelo SGBD e, quando disponível, o log do servidor.

Já uma operação autorizada segue:

```text
INSERT/UPDATE/DELETE
        ↓
Trigger
        ↓
logged_actions
```

Por isso a tabela de auditoria comprova principalmente as operações que chegaram ao trigger.

---

# 17. Passo a passo de execução

## Pré-requisitos

- PostgreSQL 14 ou superior;
- `psql` ou SQL Shell;
- usuário administrativo;
- ambiente local de laboratório.

## Ordem obrigatória

```text
01setupdatabase.sql
        ↓
02seeddata.sql
        ↓
03securityrbac.sql
        ↓
04auditsetup.sql
        ↓
05attacksimulation.sql
        ↓
06forensicqueries.sql
```

No terminal:

```bash
psql -U postgres -f scripts/01setupdatabase.sql
psql -U postgres -f scripts/02seeddata.sql
psql -U postgres -f scripts/03securityrbac.sql
psql -U postgres -f scripts/04auditsetup.sql
```

Depois, os testes devem ser executados com os usuários apropriados.

---

# 18. Usuários do laboratório

| Usuário | Role | Finalidade |
|---|---|---|
| `usr_auditor_op` | `role_operacional` | Testar operação e bloqueios |
| `usr_coordenador_gestao` | `role_gestao` | Testar acesso às views |
| `usr_dba_admin` | `role_admin_workflow` | Administração e perícia |

As senhas presentes nos scripts são exclusivamente para o laboratório acadêmico e devem ser substituídas em qualquer ambiente real.

---

# 19. Evidências da execução

As evidências abaixo precisam ser preenchidas após a execução real.

## Evidência 1 – DELETE bloqueado

```text
[INSERIR PRINT DO POSTGRESQL]
```

Resultado esperado:

```text
permission denied for table movimentacoes
```

## Evidência 2 – UPDATE bloqueado

```text
[INSERIR PRINT DO POSTGRESQL]
```

Resultado esperado:

```text
permission denied for table movimentacoes
```

## Evidência 3 – acesso ao hash bloqueado

```text
[INSERIR PRINT DO POSTGRESQL]
```

Resultado esperado:

```text
permission denied
```

## Evidência 4 – operação válida

```text
[INSERIR PRINT DA INSERÇÃO AUTORIZADA]
```

Resultado esperado:

```text
INSERT 0 1
```

## Evidência 5 – auditoria

```text
[INSERIR PRINT DA CONSULTA audit.logged_actions]
```

Deve ser possível visualizar:

```text
usuário
data/hora
operação
OLD
NEW
```

Não devem ser colocados nos prints valores reais ou informações sensíveis.

---

# 20. Parecer técnico

A solução implementada atende aos principais requisitos da atividade ao separar os dados operacionais da infraestrutura de auditoria e aplicar permissões de acordo com o perfil de cada usuário.

O perfil operacional consegue realizar as atividades necessárias para o fluxo, mas não possui privilégios para excluir ou alterar o histórico de movimentações.

O perfil de gestão possui acesso somente às informações consolidadas disponibilizadas pelas views, reduzindo a exposição de dados desnecessários.

O perfil administrativo possui os privilégios necessários para administração do banco e investigação da trilha de auditoria.

A utilização de triggers e da função `SECURITY DEFINER` permite registrar automaticamente operações realizadas nas tabelas monitoradas, incluindo usuário, horário, operação e estado anterior/posterior.

Dessa forma, o banco passa a ter mecanismos de:

- controle de acesso;
- menor privilégio;
- segregação de funções;
- integridade referencial;
- minimização de dados;
- rastreabilidade;
- auditoria;
- investigação forense.

---

# 21. Conclusão

Com a implementação do projeto foi possível aplicar, de forma prática, os conteúdos trabalhados na disciplina de Administração de Banco de Dados.

A modelagem criou uma estrutura relacional organizada, enquanto o RBAC permitiu separar as responsabilidades entre operação, gestão e administração.

A segurança em nível de coluna e as views demonstraram a aplicação da minimização de dados. Já a auditoria permitiu manter uma trilha técnica das operações realizadas nas tabelas mais importantes do workflow.

Os testes ofensivos também permitem verificar que o controle de acesso não fica apenas na aplicação, pois o próprio PostgreSQL impede operações que não fazem parte das permissões do usuário.

---

# 22. Checklist antes da entrega

- [ ] Conferir o nome do aluno.
- [ ] Conferir instituição e disciplina.
- [ ] Executar os scripts na ordem.
- [ ] Testar `usr_auditor_op`.
- [ ] Testar `usr_coordenador_gestao`.
- [ ] Testar `usr_dba_admin`.
- [ ] Capturar o `permission denied` do DELETE.
- [ ] Capturar o `permission denied` do UPDATE.
- [ ] Capturar o bloqueio da coluna `credencial_hash`.
- [ ] Executar uma movimentação válida.
- [ ] Consultar `audit.logged_actions`.
- [ ] Adicionar os prints reais.
- [ ] Conferir se nenhum dado sensível aparece nos prints.
- [ ] Subir `README.md` e a pasta `scripts` para o GitHub.
- [ ] Entregar somente o link do repositório.
