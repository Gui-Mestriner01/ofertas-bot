# Bot de Ofertas - Mercado Livre -> Telegram

Projeto na pasta `ofertas-bot`.
Destino das publicacoes: **Telegram**, atraves de uma camada de destinos
pluggavel. Quem decide para onde a oferta sai e a tabela `destinos`, nao o
codigo do workflow - adicionar WhatsApp depois e um `INSERT`, nao um refactor.
Ver "Adicionar WhatsApp depois" no fim deste arquivo.

```
ofertas-bot/
  docker-compose.yml        MySQL 8 na porta 3307 + Adminer na 8081
  sql/01-schema.sql         7 tabelas
  sql/02-views.sql          5 views
  sql/03-seed.sql           categorias, keywords, config
  sql/04-destinos.sql       destinos + envios_destino
  workflows/A-coletor.json
  workflows/B-publicador.json
  workflows/C-manual.json
  workflows/D-error-handler.json
  workflows/E-aprovacao.json
  docs/COMO-USAR.md         este arquivo
```

---

## ETAPA 0 - Subir o banco e o n8n

Copie `.env.example` para `.env` e defina as senhas do MySQL. Depois, no
PowerShell, um comando por vez (sem `&&`):

```powershell
cd ofertas-bot
```

```powershell
docker compose up -d
```

A porta e **3307**, nao 3306, pra nao brigar com MySQL/XAMPP que voce ja tenha.
Os quatro arquivos de `sql/` rodam sozinhos no primeiro boot do volume.

> Se voce **ja rodou** `docker compose up -d` antes de eu ter criado o
> `04-destinos.sql`, o banco nao tem as tabelas novas. O jeito mais limpo,
> como ainda nao ha dado de valor:
>
> ```powershell
> docker compose down -v
> ```
> ```powershell
> docker compose up -d
> ```

Depois:

```powershell
npx n8n
```

### Teste da etapa 0

Abra <http://localhost:8081> (Adminer) e entre com:

| campo | valor |
|---|---|
| Sistema | MySQL |
| Servidor | `mysql` |
| Usuario | `ofertas` |
| Senha | a `MYSQL_PASSWORD` do seu `.env` |
| Base | `ofertas_bot` |

Rode:

```sql
SHOW TABLES;
SELECT COUNT(*) AS keywords FROM keywords;
SELECT COUNT(*) AS configs FROM config;
SELECT * FROM destinos;
```

Esperado: **9 tabelas + 5 views**, 17 keywords, 21 configs e uma linha em
`destinos` com `destino = 'PREENCHER'`.
Se vier vazio, o volume subiu antes dos scripts existirem:

```powershell
docker compose down -v
```

```powershell
docker compose up -d
```

---

## ETAPA 1 - Credencial MySQL no n8n

n8n -> **Credentials** -> **New** -> *MySQL*

| campo | valor |
|---|---|
| Host | `localhost` |
| Port | `3307` |
| Database | `ofertas_bot` |
| User | `ofertas` |
| Password | a `MYSQL_PASSWORD` do seu `.env` |

Nomeie **`MySQL ofertas_bot`** (os imports procuram por esse nome).
Clique em **Test** - tem que dar conexao ok.

---

## ETAPA 2 - Credencial OAuth2 do Mercado Livre

Primeiro crie a aplicacao em <https://developers.mercadolivre.com.br> ->
Minhas aplicacoes.

No n8n: **Credentials** -> **New** -> *OAuth2 API* (a generica), nomeada
**`Mercado Livre OAuth2`**:

| campo | valor |
|---|---|
| Grant Type | `Authorization Code` |
| Authorization URL | `https://auth.mercadolivre.com.br/authorization` |
| Access Token URL | `https://api.mercadolibre.com/oauth/token` |
| Client ID | o da sua aplicacao |
| Client Secret | o da sua aplicacao |
| Scope | `offline_access read` |
| Authentication | `Send credentials in body` |

O n8n mostra uma **OAuth Redirect URL** no topo da credencial. Copie ela e cole
no campo *URIs de redirect* da sua aplicacao no painel do ML. Depois clique em
**Connect my account**.

> **Ponto a verificar:** o painel do ML pode recusar uma redirect URI em
> `http://localhost`. Se recusar, voce tem duas saidas: rodar `npx n8n` com
> tunel (`N8N_TUNNEL=true`, que gera uma URL https temporaria) ou usar o fluxo
> manual de `refresh_token` via curl. Me diga qual erro aparece e eu monto a
> alternativa.

### Teste da etapa 2

Crie um workflow descartavel com um node **HTTP Request**:

- Method `GET`
- URL `https://api.mercadolibre.com/users/me`
- Authentication: `Generic Credential Type` -> `OAuth2 API` -> `Mercado Livre OAuth2`

Esperado: um JSON com seu `id` e `nickname`.

Depois troque a URL por `https://api.mercadolibre.com/sites/MLB/search?q=fone%20bluetooth&limit=5`
e rode de novo. **Esse e o teste que define a FASE 1:**

- **200 OK** -> deixa `MODO_BUSCA = 'search'` (o padrao do seed)
- **403 Forbidden** -> e a restricao do item 2.1. Troque para o modo monitor:

  ```sql
  UPDATE config SET valor = 'monitor' WHERE chave = 'MODO_BUSCA';
  ```

  No modo monitor o coletor le a tabela `watchlist` e consulta
  `/items?ids=` em lotes de 20. Voce abastece a watchlist com os produtos
  que quer acompanhar:

  ```sql
  INSERT INTO watchlist (produto_id, categoria_id, titulo)
  VALUES ('MLB3456789012', 1, 'Headset que eu quero acompanhar');
  ```

---

## ETAPA 3 - Bot do Telegram

1. Fale com o [@BotFather](https://t.me/BotFather) -> `/newbot` -> guarde o token.
2. n8n -> **Credentials** -> **New** -> *Telegram*, cole o token, nomeie
   **`Telegram Bot Ofertas`**.
3. Crie o canal de ofertas e **adicione o bot como administrador** com permissao
   de publicar.
4. Mande qualquer mensagem pro seu proprio bot no privado.

### Pegar os dois chat ids

Abra no navegador (trocando `SEU_TOKEN`):

```
https://api.telegram.org/botSEU_TOKEN/getUpdates
```

Voce precisa de dois ids, e eles vao para lugares diferentes:

- **chat do admin** = o `message.chat.id` da sua conversa privada (numero
  positivo). Vai na **config**, chave `TELEGRAM_CHAT_ADMIN`. E o canal de
  controle: previa de aprovacao e alerta de erro.
- **chat do canal** = `@nomedocanal` se publico, ou o `chat.id` negativo
  (comeca com `-100`) se privado. Vai na **tabela destinos**, nao na config.
  Pra canal privado, publique algo nele e encaminhe pro bot pra o id aparecer
  no `getUpdates`.

A separacao e de proposito: `config` guarda como o bot se comporta, `destinos`
guarda para onde a oferta sai.

---

## ETAPA 4 - Credencial OpenAI

n8n -> **Credentials** -> **New** -> *OpenAI*, nomeada **`OpenAI`**.

Se nao quiser usar IA agora:

```sql
UPDATE config SET valor = '0' WHERE chave = 'IA_ATIVA';
```

O publicador passa a usar a `frase_padrao` da categoria, e o fluxo continua
inteiro. Nada quebra.

---

## ETAPA 5 - Importar os workflows

Importe **nesta ordem** (D primeiro, porque os outros vao apontar pra ele):

1. `workflows/D-error-handler.json`
2. `workflows/E-aprovacao.json`
3. `workflows/A-coletor.json`
4. `workflows/B-publicador.json`
5. `workflows/C-manual.json`

n8n -> **Workflows** -> `...` -> **Import from File**.

### Depois de cada import

Os JSONs vem com `"id": "SELECIONAR"` nas credenciais - de proposito, pra o n8n
marcar visualmente o que falta. Em cada node com icone de alerta, abra e escolha
a credencial certa:

| node usa | credencial |
|---|---|
| MySQL | `MySQL ofertas_bot` |
| HTTP Request do ML | `Mercado Livre OAuth2` |
| Telegram | `Telegram Bot Ofertas` |
| `Gerar Frase IA` | `OpenAI` |

### Ligar o error handler

Em **A**, **B**, **C** e **E**: abra o menu `...` do workflow ->
**Settings** -> **Error Workflow** -> `D - Error Handler`. Sem isso o crash fica
mudo.

---

## ETAPA 6 - Preencher a config

No Adminer:

```sql
UPDATE config SET valor = '123456789'      WHERE chave = 'TELEGRAM_CHAT_ADMIN';
UPDATE config SET valor = 'http://localhost:5678' WHERE chave = 'N8N_BASE_URL';
UPDATE config SET valor = 'troque-por-uma-string-aleatoria-longa' WHERE chave = 'APROVACAO_SECRET';
```

E o destino do canal, que mora na outra tabela:

```sql
UPDATE destinos SET destino = '@seucanal' WHERE nome = 'telegram-canal';
```

O `APROVACAO_SECRET` entra na URL dos botoes APROVAR/REJEITAR. Qualquer pessoa
com o link consegue aprovar, entao use algo longo e aleatorio.

Confira que nao sobrou nada vazio:

```sql
SELECT chave, valor FROM config WHERE valor = '' OR valor IS NULL;
SELECT * FROM destinos WHERE destino = 'PREENCHER';
```

As duas consultas tem que voltar zero linhas.

O node `Montar Config` do publicador **derruba a execucao de proposito** se
alguma dessas chaves estiver vazia, em vez de publicar pela metade.

---

## ETAPA 7 - Cadastrar o primeiro link de afiliado

Nao existe API oficial de afiliados (item 2.2). O publicador **nao publica
produto sem link cadastrado** - e o `AFILIADO_MODO = 'tabela'`.

Jeito rapido, workflow **C**: ative o workflow, abra a URL do Form Trigger, cole
a URL do anuncio e o link que voce gerou no painel. Ele busca o item na API,
grava o link e entra na fila com score 100.

Jeito manual:

```sql
INSERT INTO links_afiliados (produto_id, url_afiliado)
VALUES ('MLB3456789012', 'https://mercadolivre.com/sec/SEULINK');
```

> Valide o link antes: abra numa aba anonima, adicione ao carrinho e veja se o
> rastreio se mantem.

---

## ETAPA 8 - Rodar na mao, na ordem

### A - Coletor

Execute manualmente. Abra o node **Filtrar e Pontuar** e olhe o console:

```
Filtrar e Pontuar: {"entrada":150,"sem_link":0,"sem_imagem":2,
 "fora_de_preco":40,"sem_desconto":88,"desconto_baixo":12,
 "score_baixo":5,"duplicado_na_rodada":1,"aprovado":2}
```

Esse objeto diz exatamente onde cada produto morreu. Confira:

```sql
SELECT * FROM vw_fila_atual;
SELECT produto_id, score, score_detalhe FROM ofertas ORDER BY id DESC LIMIT 5;
```

No `score_detalhe`, `null` = o criterio nao tinha dado (item 2.6),
`0` = tinha dado e nao pontuou. Essa e a **FASE 7**.

Se `aprovado` vier 0: quase sempre e `sem_desconto`, porque muito anuncio nao
preenche `original_price`. Afrouxe:

```sql
UPDATE config SET valor = '0' WHERE chave = 'EXIGIR_DESCONTO';
UPDATE config SET valor = '25' WHERE chave = 'SCORE_MINIMO';
```

### B - Publicador

Com `MODO_APROVACAO = 1` (padrao), a primeira execucao manda a **previa pro seu
privado** com dois botoes e deixa a oferta em `AGUARDANDO`. Clicar em APROVAR
chama o workflow E, que devolve a oferta pra fila como `APROVADO`. **A proxima
execucao do B publica no canal** - e ja nao manda previa de novo, porque a
previa so sai quando o status era `NOVO`.

Isso e a **FASE 11**. Para publicar direto, sem previa:

```sql
UPDATE config SET valor = '0' WHERE chave = 'MODO_APROVACAO';
```

### Teste de erro forcado (FASE 12)

```sql
UPDATE ofertas SET preco_atual = 1.00 WHERE id = (SELECT MAX(id) FROM ofertas);
```

O node `Conferir Preco` vai ver a diferenca estourando a `TOLERANCIA_PRECO`,
mandar a oferta pro caminho de falha com retry de 5 min, e te avisar no
Telegram. Confira:

```sql
SELECT * FROM vw_erros_recentes;
SELECT id, status, tentativas, proxima_tentativa, motivo FROM ofertas ORDER BY id DESC LIMIT 3;
```

---

## ETAPA 9 - Ativar

Ative **A**, **B**, **C** e **E**. O **D** nao se ativa: ele dispara pelo
Error Workflow dos outros.

| workflow | quando roda |
|---|---|
| A - Coletor | `0 * * * *` (toda hora) |
| B - Publicador | `0 9,12,15,18,21 * * *` (5x ao dia) |
| C - Manual | quando voce abre o formulario |
| E - Aprovacao | quando voce clica no botao |

Acompanhamento:

```sql
SELECT * FROM vw_resumo_hoje;
SELECT * FROM vw_por_categoria_semana;
SELECT * FROM vw_envios_por_destino;
```

---

## Adicionar WhatsApp depois

A camada de destinos ja esta pronta pra receber. O que falta pra cada rota:

### O que o WhatsApp permite hoje (verificado em 30/10/2026)

O item 2.3 da sua spec mudou em parte. Existe uma Groups API oficial no Cloud
API: da pra criar grupo, gerar link de convite e mandar mensagem com
`recipient_type: group`. **Mas o limite e 8 participantes por grupo** (grupo
normal do app vai a 1.024). Fora da janela de 24h cada mensagem e cobrada por
destinatario entregue. Pra um canal de ofertas isso nao fecha: 500 pessoas
seriam 63 grupos, pagando como se fosse 1:1.

Canal (newsletter) continua sem API oficial.

### Rota 1 - Cloud API 1:1 para inscritos (oficial)

Nao e grupo: cada pessoa recebe no privado. Precisa de:

1. Tabela de inscritos (quem mandou mensagem pro bot = opt-in).
2. Template aprovado na Meta, com variaveis pra titulo, preco e link.
3. Um destino por inscrito, ou um destino tipo `whatsapp_cloud` que o
   publicador expande sobre a tabela de inscritos.
4. Node de envio novo no `IF Plataforma Implementada?`.

Custo por mensagem na tarifa de marketing do Brasil. Zero risco de ban.

### Rota 2 - Evolution API em grupo (nao-oficial)

Grupo de verdade, ate 1.024, de graca. Roda em cima do WhatsApp Web, entao
**arrisca ban do numero** - chip separado e obrigatorio. Precisa de:

1. Evolution API no Docker + leitura do QR code.
2. `INSERT INTO destinos` com `plataforma = 'whatsapp_evolution'`,
   `formato = 'markdown_wa'` e o JID do grupo em `destino`.
3. Um node HTTP Request pro `/message/sendMedia` no
   `IF Plataforma Implementada?`.

### O que ja esta feito dos dois lados

- O formatador `markdown_wa` existe e esta testado: `*negrito*`, `_italico_`,
  `~riscado~` e link cru (o WhatsApp nao tem ancora com texto).
- O formatador `texto` existe, pra template de Cloud API.
- `envios_destino` registra sucesso e falha **por destino**, entao um destino
  cair nao derruba o outro: `ofertas.status = 'ENVIADO'` significa "saiu em
  pelo menos um", e `motivo` guarda o parcial.
- Destino ativo numa plataforma sem node de envio **nao passa calado**: entra
  em `envios_destino` como ERRO dizendo exatamente isso, e aparece em
  `vw_envios_por_destino`.

Quando voce decidir a rota, o que eu mexo e: um render (se precisar), um node
de envio e a lista `IMPLEMENTADAS` no `Formatar Por Destino`. O resto do fluxo
fica igual.

---

## Decisoes de engenharia que estao no codigo

- **`UNIQUE (produto_id, preco_atual)`**, nao so no produto. E o que permite
  registrar "R$499 ha 20 dias, hoje R$349" como duas linhas.
- **Toda a regra anti-repeticao vive em UM SELECT** no node
  `Montar SQL Selecionar` do B: score minimo, link cadastrado, janela de N dias,
  queda minima de preco e retries pendentes. Nao esta espalhada em IFs.
- **Concorrencia em duas camadas:** lock por PRIMARY KEY em `locks_execucao`
  (com `ON DUPLICATE KEY` que so deixa tomar o lock se expirou, num unico
  statement) e reserva por `WHERE status IN ('NOVO','APROVADO','ERRO')`.
  Se `affectedRows` voltar 0, outra execucao chegou primeiro.
- **SQL montado em Code node com escape manual**, nao pela opcao Query
  Parameters do node MySQL - titulo do ML tem virgula e apostrofo, e aquela
  opcao e uma lista separada por virgula. O escape trata `\`, `'`, byte nulo e
  quebra de linha. Testado com `Fone O'Neill 50% \ "TOP", branco`.
- **A IA nao escreve numero.** Preco e desconto sao montados pelo codigo. O
  validador reprova a frase se vier numero, `R$`, `%`, termo de urgencia, mais
  de 3 emojis ou mais de 200 caracteres - e cai na `frase_padrao` da categoria.
- **Validacao e formatacao sao nodes separados.** `Validar Frase` devolve um
  payload neutro; `Formatar Por Destino` renderiza por plataforma. Sem isso,
  cada destino novo exigiria mexer no node que valida a IA.
- **`destinos` e a fonte da verdade de onde a oferta sai**, nao a config. E o
  que faz "adicionar WhatsApp" ser um INSERT em vez de um refactor.
- **Revalidacao em `/items/{id}` imediatamente antes de publicar**, e dai pra
  frente a mensagem usa so o valor revalidado. Tambem checa `status != active` e
  `available_quantity <= 0`.
- **Imagem por URL** (`pictures[0].secure_url`), sem download e sem binary data.
- **Rotacao de keyword avanca antes da busca**, nao depois: se a API falhar, a
  mesma keyword nao volta na hora seguinte.
- **A watchlist se abastece sozinha** nos dois modos, guardando o menor preco
  visto (`LEAST`). Ou seja: rodando em `search` hoje, voce ja constroi a
  watchlist que o modo `monitor` vai usar se o `/search` comecar a dar 403.

## Limites que nao da pra contornar

- **Nao existe API oficial de afiliados do ML.** Link e manual, via painel.
  Tabela `links_afiliados` + workflow C e a solucao.
- **WhatsApp nao publica em canal por API oficial**, e em grupo publica com
  teto de 8 participantes. Detalhe em "Adicionar WhatsApp depois".
- **`/sites/MLB/search` pode dar 403** mesmo com token valido. Dai o modo
  monitor existir.
- **Nao existe endpoint publico de "ofertas do dia"** nem metrica de clique por
  link de afiliado via API.
- **`sold_quantity`, `reviews` e `original_price` podem vir null.** O score
  simplesmente nao pontua o criterio, e `score_detalhe` registra `null` pra voce
  saber que foi falta de dado e nao nota baixa.

## A verificar na primeira rodada

- Se os botoes inline do Telegram renderizam na previa. Se nao renderizarem, me
  diga e eu troco por links no proprio texto da legenda, que e mais simples e
  funciona igual.
- O resultado do `/sites/MLB/search` (200 ou 403) - e o que define o modo.
- Se o painel do ML aceita a redirect URI em `http://localhost`.
