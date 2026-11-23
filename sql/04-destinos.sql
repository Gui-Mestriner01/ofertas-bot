-- =====================================================================
-- ofertas_bot - camada de destinos
-- 30/10/2026
-- destinos = onde a oferta sai. config = como o bot se comporta.
-- Adicionar WhatsApp depois e um INSERT aqui, nao um refactor.
-- =====================================================================
USE ofertas_bot;

CREATE TABLE IF NOT EXISTS destinos (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  nome       VARCHAR(40)  NOT NULL UNIQUE,
  plataforma ENUM('telegram','whatsapp_cloud','whatsapp_evolution')
             NOT NULL,
  -- chat id (@canal ou -100...), numero E.164 ou JID, conforme a plataforma
  destino    VARCHAR(120) NOT NULL,
  -- html       = Telegram parse_mode HTML
  -- markdown_wa = *negrito* _italico_ ~riscado~, link cru
  -- texto      = sem formatacao nenhuma
  formato    ENUM('html','markdown_wa','texto') NOT NULL DEFAULT 'html',
  ativo      TINYINT(1)   NOT NULL DEFAULT 1,
  ordem      INT          NOT NULL DEFAULT 0,
  criado_em  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_destinos_ativo (ativo, ordem)
) ENGINE=InnoDB;

-- Com fan-out, ofertas.status='ENVIADO' significa "saiu em pelo menos um
-- destino". Qual destino recebeu e qual falhou fica aqui.
CREATE TABLE IF NOT EXISTS envios_destino (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  oferta_id  INT          NOT NULL,
  destino_id INT          NOT NULL,
  status     ENUM('OK','ERRO') NOT NULL,
  erro       VARCHAR(500) NULL,
  enviado_em TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_oferta_destino UNIQUE (oferta_id, destino_id),
  CONSTRAINT fk_envio_oferta
    FOREIGN KEY (oferta_id) REFERENCES ofertas(id) ON DELETE CASCADE,
  CONSTRAINT fk_envio_destino
    FOREIGN KEY (destino_id) REFERENCES destinos(id),
  INDEX idx_envios_data (enviado_em)
) ENGINE=InnoDB;

-- PREENCHER o campo destino com o chat id do seu canal.
INSERT INTO destinos (nome, plataforma, destino, formato, ordem)
VALUES ('telegram-canal', 'telegram', 'PREENCHER', 'html', 1)
ON DUPLICATE KEY UPDATE plataforma = VALUES(plataforma);

-- Exemplos para quando voce decidir o WhatsApp. Deixados comentados
-- de proposito: nenhum dos dois esta implementado no publicador ainda.
--
-- INSERT INTO destinos (nome, plataforma, destino, formato, ativo, ordem)
-- VALUES ('wa-inscritos', 'whatsapp_cloud', 'template:ofertas_v1', 'texto', 0, 2);
--
-- INSERT INTO destinos (nome, plataforma, destino, formato, ativo, ordem)
-- VALUES ('wa-grupo', 'whatsapp_evolution', '1203630000000@g.us', 'markdown_wa', 0, 3);
