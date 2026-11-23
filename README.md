# Bot de Ofertas — Mercado Livre → Telegram 🛒🤖

Automação em **n8n** que encontra ofertas no Mercado Livre, escreve a chamada com IA e publica no Telegram, com fila, aprovação manual, anti-repetição e tratamento de erros. Tudo usando apenas APIs oficiais.

## Como funciona

| Workflow | O que faz |
|---|---|
| **A – Coletor** | Roda em agenda, busca produtos por palavra-chave (rotação de keywords) ou monitora uma watchlist, calcula o desconto e grava as ofertas no MySQL |
| **B – Publicador** | Pega a melhor oferta da fila, revalida preço e estoque na API logo antes de publicar, gera a frase com IA (OpenAI) e envia para todos os destinos ativos |
| **C – Entrada manual** | Formulário para cadastrar um produto e o link de afiliado na mão |
| **D – Error handler** | Registra qualquer falha no banco e avisa o admin no Telegram |
| **E – Aprovação** | Webhook para aprovar ofertas antes de irem ao ar |

## Decisões de engenharia
- **A IA não escreve número.** Preço e desconto são montados pelo código, e a IA só escreve a frase (validada em um node separado).
- **Anti-repetição em um único SELECT**, com `UNIQUE (produto_id, preco_atual)`: o mesmo produto só volta quando o preço muda.
- **Concorrência em duas camadas**: lock por chave primária em `locks_execucao` para duas execuções não publicarem a mesma oferta.
- **Destinos plugáveis**: a tabela `destinos` decide para onde a oferta vai (Telegram hoje; WhatsApp Cloud API ou Evolution depois, só com um `INSERT`). Cada envio é registrado por destino em `envios_destino`.
- **Revalidação em `/items/{id}`** imediatamente antes de publicar, para não divulgar preço vencido.

## Stack
- n8n (workflows em `workflows/`)
- MySQL 8 + Adminer via Docker Compose (`sql/`: 7 tabelas, 5 views, seeds)
- API do Mercado Livre (OAuth2), Telegram Bot API, OpenAI

## Como rodar
1. `cp .env.example .env` e defina as senhas do MySQL
2. `docker compose up -d` (MySQL na porta 3307, Adminer na 8081)
3. No n8n, importe os arquivos de `workflows/` e crie as credenciais (MySQL, Mercado Livre OAuth2, Telegram, OpenAI)
4. Preencha a tabela `config` (chat do admin, modo de busca etc.)

O passo a passo completo, com testes de cada etapa, está em [`docs/COMO-USAR.md`](docs/COMO-USAR.md).

> Nenhuma credencial, token ou ID de chat está no repositório. Tudo fica nas credenciais do n8n e na tabela `config`.
