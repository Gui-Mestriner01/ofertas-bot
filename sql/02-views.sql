-- =====================================================================
-- ofertas_bot - views de acompanhamento
-- 30/10/2026
-- =====================================================================
USE ofertas_bot;

DROP VIEW IF EXISTS vw_resumo_hoje;
CREATE VIEW vw_resumo_hoje AS
SELECT
  COUNT(*)                                                AS total_capturado,
  SUM(status = 'ENVIADO')                                 AS enviados,
  SUM(status IN ('NOVO','APROVADO','AGUARDANDO'))         AS na_fila,
  SUM(status = 'ERRO')                                    AS com_erro,
  SUM(status = 'DESCARTADO')                              AS descartados,
  ROUND(AVG(NULLIF(score,0)), 1)                          AS score_medio,
  ROUND(AVG(NULLIF(desconto,0)), 1)                       AS desconto_medio
FROM ofertas
WHERE DATE(criado_em) = CURDATE();

DROP VIEW IF EXISTS vw_por_categoria_semana;
CREATE VIEW vw_por_categoria_semana AS
SELECT
  c.nome                                   AS categoria,
  COUNT(o.id)                              AS capturados,
  SUM(o.status = 'ENVIADO')                AS enviados,
  ROUND(AVG(NULLIF(o.desconto,0)), 1)      AS desconto_medio,
  ROUND(AVG(NULLIF(o.score,0)), 1)         AS score_medio
FROM categorias c
LEFT JOIN ofertas o
       ON o.categoria_id = c.id
      AND o.criado_em >= DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY c.id, c.nome
ORDER BY enviados DESC, capturados DESC;

DROP VIEW IF EXISTS vw_fila_atual;
CREATE VIEW vw_fila_atual AS
SELECT
  o.id,
  o.produto_id,
  LEFT(o.titulo, 60)                       AS titulo,
  c.nome                                   AS categoria,
  o.preco_atual,
  o.desconto,
  o.score,
  o.status,
  o.tentativas,
  o.proxima_tentativa,
  (la.produto_id IS NOT NULL)              AS tem_link,
  o.criado_em
FROM ofertas o
LEFT JOIN categorias      c  ON c.id = o.categoria_id
LEFT JOIN links_afiliados la ON la.produto_id = o.produto_id
WHERE o.status IN ('NOVO','APROVADO','AGUARDANDO','ERRO')
ORDER BY o.score DESC, o.criado_em ASC;

DROP VIEW IF EXISTS vw_erros_recentes;
CREATE VIEW vw_erros_recentes AS
SELECT
  l.data,
  l.workflow,
  l.etapa,
  l.produto_id,
  l.mensagem,
  LEFT(COALESCE(l.erro,''), 300) AS erro
FROM logs_execucao l
WHERE l.status = 'ERRO'
  AND l.data >= DATE_SUB(NOW(), INTERVAL 3 DAY)
ORDER BY l.data DESC;

DROP VIEW IF EXISTS vw_envios_por_destino;
CREATE VIEW vw_envios_por_destino AS
SELECT
  d.nome                                   AS destino,
  d.plataforma,
  d.ativo,
  COUNT(e.id)                              AS tentativas_7d,
  SUM(e.status = 'OK')                     AS ok_7d,
  SUM(e.status = 'ERRO')                   AS erro_7d,
  MAX(e.enviado_em)                        AS ultimo_envio
FROM destinos d
LEFT JOIN envios_destino e
       ON e.destino_id = d.id
      AND e.enviado_em >= DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY d.id, d.nome, d.plataforma, d.ativo
ORDER BY d.ordem;
