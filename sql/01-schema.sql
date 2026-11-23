-- =====================================================================
-- ofertas_bot - schema completo
-- 30/10/2026
-- =====================================================================

CREATE DATABASE IF NOT EXISTS ofertas_bot
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ofertas_bot;

-- ---------------------------------------------------------------------
-- config: muda o comportamento do bot sem editar node
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS config (
  chave        VARCHAR(60)  NOT NULL PRIMARY KEY,
  valor        TEXT         NOT NULL,
  tipo         ENUM('int','decimal','bool','string') NOT NULL DEFAULT 'string',
  descricao    VARCHAR(255) NULL,
  atualizado_em TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
                              ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- categorias
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS categorias (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  nome         VARCHAR(40)  NOT NULL UNIQUE,
  emoji        VARCHAR(10)  NULL,
  frase_padrao VARCHAR(200) NOT NULL,
  ativo        TINYINT(1)   NOT NULL DEFAULT 1
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- keywords: rotacionadas por ultima_busca
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS keywords (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  termo        VARCHAR(120) NOT NULL UNIQUE,
  categoria_id INT          NOT NULL,
  ultima_busca DATETIME     NULL,
  ativo        TINYINT(1)   NOT NULL DEFAULT 1,
  CONSTRAINT fk_keywords_categoria
    FOREIGN KEY (categoria_id) REFERENCES categorias(id),
  INDEX idx_keywords_rotacao (ativo, ultima_busca)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- watchlist: usada quando MODO_BUSCA = 'monitor'
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS watchlist (
  produto_id       VARCHAR(20)   NOT NULL PRIMARY KEY,
  categoria_id     INT           NULL,
  preco_referencia DECIMAL(10,2) NULL,
  titulo           VARCHAR(255)  NULL,
  ativo            TINYINT(1)    NOT NULL DEFAULT 1,
  ultima_checagem  DATETIME      NULL,
  criado_em        TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_watchlist_categoria
    FOREIGN KEY (categoria_id) REFERENCES categorias(id),
  INDEX idx_watchlist_ativo (ativo, ultima_checagem)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- ofertas: fila E historico na mesma tabela
-- UNIQUE (produto_id, preco_atual) permite repostar o mesmo item
-- quando o preco mudou, e bloqueia duplicata do mesmo preco.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ofertas (
  id                INT AUTO_INCREMENT PRIMARY KEY,
  produto_id        VARCHAR(20)   NOT NULL,
  titulo            VARCHAR(255)  NOT NULL,
  categoria_id      INT           NULL,
  preco_atual       DECIMAL(10,2) NOT NULL,
  preco_original    DECIMAL(10,2) NULL,
  desconto          INT           NULL,
  frete_gratis      TINYINT(1)    NOT NULL DEFAULT 0,
  condicao          VARCHAR(20)   NULL,
  catalogo          TINYINT(1)    NOT NULL DEFAULT 0,
  vendidos          INT           NULL,
  avaliacao         DECIMAL(3,2)  NULL,
  link_produto      VARCHAR(500)  NOT NULL,
  imagem            VARCHAR(500)  NULL,
  score             INT           NOT NULL DEFAULT 0,
  score_detalhe     JSON          NULL,
  status            ENUM('NOVO','APROVADO','AGUARDANDO','PROCESSANDO',
                          'ENVIADO','ERRO','DESCARTADO','REJEITADO')
                    NOT NULL DEFAULT 'NOVO',
  tentativas        INT           NOT NULL DEFAULT 0,
  proxima_tentativa DATETIME      NULL,
  frase             VARCHAR(255)  NULL,
  mensagem          TEXT          NULL,
  motivo            VARCHAR(255)  NULL,
  lock_owner        VARCHAR(80)   NULL,
  criado_em         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  atualizado_em     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,
  enviado_em        DATETIME      NULL,
  CONSTRAINT uq_produto_preco UNIQUE (produto_id, preco_atual),
  CONSTRAINT fk_ofertas_categoria
    FOREIGN KEY (categoria_id) REFERENCES categorias(id),
  INDEX idx_fila      (status, score, proxima_tentativa),
  INDEX idx_produto   (produto_id, enviado_em),
  INDEX idx_enviado   (enviado_em)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- links_afiliados: abastecida manualmente (nao ha API oficial)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS links_afiliados (
  produto_id   VARCHAR(20)  NOT NULL PRIMARY KEY,
  url_afiliado VARCHAR(500) NOT NULL,
  observacao   VARCHAR(255) NULL,
  criado_em    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- logs_execucao
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS logs_execucao (
  id         BIGINT AUTO_INCREMENT PRIMARY KEY,
  data       TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  workflow   VARCHAR(40) NOT NULL,
  etapa      VARCHAR(60) NULL,
  status     ENUM('OK','AVISO','ERRO') NOT NULL DEFAULT 'OK',
  produto_id VARCHAR(20) NULL,
  mensagem   VARCHAR(500) NULL,
  erro       TEXT        NULL,
  INDEX idx_logs_data (data),
  INDEX idx_logs_status (status, data)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- locks_execucao: concorrencia por PRIMARY KEY, expira em 10 min
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS locks_execucao (
  nome      VARCHAR(60) NOT NULL PRIMARY KEY,
  dono      VARCHAR(80) NOT NULL,
  criado_em DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expira_em DATETIME    NOT NULL
) ENGINE=InnoDB;
