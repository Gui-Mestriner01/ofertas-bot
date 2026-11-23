-- =====================================================================
-- ofertas_bot - dados iniciais
-- 30/10/2026
-- =====================================================================
USE ofertas_bot;

-- ---------------------------------------------------------------------
-- categorias (frase_padrao = fallback quando a IA reprova no validador)
-- ---------------------------------------------------------------------
INSERT INTO categorias (nome, emoji, frase_padrao) VALUES
  ('GAMES',        '🎮', 'Boa pedida pra quem joga.'),
  ('INFORMATICA',  '💻', 'Item de informatica com preco interessante.'),
  ('CELULARES',    '📱', 'Opcao de celular e acessorios pra conferir.'),
  ('ELETRONICOS',  '🔌', 'Eletronico com desconto no Mercado Livre.'),
  ('CASA',         '🏠', 'Util pra casa e pro dia a dia.'),
  ('FERRAMENTAS',  '🔧', 'Ferramenta pra quem gosta de resolver em casa.'),
  ('ACESSORIOS',   '🎧', 'Acessorio simples e com bom custo.')
ON DUPLICATE KEY UPDATE emoji = VALUES(emoji);

-- ---------------------------------------------------------------------
-- keywords iniciais
-- ---------------------------------------------------------------------
INSERT INTO keywords (termo, categoria_id) VALUES
  ('headset gamer',        (SELECT id FROM categorias WHERE nome='GAMES')),
  ('controle xbox',        (SELECT id FROM categorias WHERE nome='GAMES')),
  ('cadeira gamer',        (SELECT id FROM categorias WHERE nome='GAMES')),
  ('ssd nvme 1tb',         (SELECT id FROM categorias WHERE nome='INFORMATICA')),
  ('memoria ram ddr4',     (SELECT id FROM categorias WHERE nome='INFORMATICA')),
  ('teclado mecanico',     (SELECT id FROM categorias WHERE nome='INFORMATICA')),
  ('monitor 24 polegadas', (SELECT id FROM categorias WHERE nome='INFORMATICA')),
  ('carregador turbo usb c',(SELECT id FROM categorias WHERE nome='CELULARES')),
  ('capa de celular',      (SELECT id FROM categorias WHERE nome='CELULARES')),
  ('smartwatch',           (SELECT id FROM categorias WHERE nome='ELETRONICOS')),
  ('caixa de som bluetooth',(SELECT id FROM categorias WHERE nome='ELETRONICOS')),
  ('air fryer',            (SELECT id FROM categorias WHERE nome='CASA')),
  ('aspirador de po vertical',(SELECT id FROM categorias WHERE nome='CASA')),
  ('parafusadeira furadeira',(SELECT id FROM categorias WHERE nome='FERRAMENTAS')),
  ('jogo de chaves',       (SELECT id FROM categorias WHERE nome='FERRAMENTAS')),
  ('fone bluetooth',       (SELECT id FROM categorias WHERE nome='ACESSORIOS')),
  ('mochila notebook',     (SELECT id FROM categorias WHERE nome='ACESSORIOS'))
ON DUPLICATE KEY UPDATE categoria_id = VALUES(categoria_id);

-- ---------------------------------------------------------------------
-- config
-- ---------------------------------------------------------------------
INSERT INTO config (chave, valor, tipo, descricao) VALUES
  ('MODO_BUSCA',            'search',  'string',  'search = /sites/MLB/search | monitor = /items?ids='),
  ('KEYWORDS_POR_EXECUCAO', '3',       'int',     'quantas keywords por rodada do coletor'),
  ('LIMIT_BUSCA',           '50',      'int',     'limit do /search'),
  ('PRECO_MINIMO',          '30.00',   'decimal', 'ignora abaixo disso'),
  ('PRECO_MAXIMO',          '3000.00', 'decimal', 'ignora acima disso'),
  ('DESCONTO_MINIMO',       '15',      'int',     'percentual minimo'),
  ('EXIGIR_DESCONTO',       '1',       'bool',    '1 = descarta item sem original_price'),
  ('SCORE_MINIMO',          '35',      'int',     'score minimo pra publicar'),
  ('DIAS_SEM_REPETIR',      '20',      'int',     'janela anti-repeticao do mesmo produto'),
  ('QUEDA_MINIMA_REPOST',   '10',      'int',     'percentual de queda pra repostar dentro da janela'),
  ('TOLERANCIA_PRECO',      '2.00',    'decimal', 'diferenca aceita na revalidacao, em reais'),
  ('MAX_TENTATIVAS',        '3',       'int',     'retries antes de ERRO definitivo'),
  ('MODO_APROVACAO',        '1',       'bool',    '1 = manda previa pro admin antes de publicar'),
  ('AFILIADO_MODO',         'tabela',  'string',  'tabela = so publica com link cadastrado'),
  ('AFILIADO_TEMPLATE',     '',        'string',  'reservado; vazio enquanto o modo for tabela'),
  ('IA_ATIVA',              '1',       'bool',    '1 = chama a IA pra frase de apoio'),
  ('IA_MODELO',             'gpt-4o-mini','string','modelo usado no node de IA'),
  ('CAPTION_MAX',           '1024',    'int',     'limite de legenda de foto do Telegram'),
  -- TELEGRAM_CHAT_CANAL saiu: o destino do canal mora na tabela destinos
  ('TELEGRAM_CHAT_ADMIN',   '',        'string',  'PREENCHER: seu chat id numerico'),
  ('N8N_BASE_URL',          'http://localhost:5678','string','base dos webhooks de aprovacao'),
  ('APROVACAO_SECRET',      '',        'string',  'PREENCHER: string aleatoria do link de aprovacao')
ON DUPLICATE KEY UPDATE descricao = VALUES(descricao);
