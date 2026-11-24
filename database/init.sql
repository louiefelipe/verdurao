SET NAMES utf8mb4;
DROP DATABASE IF EXISTS vistaVerdurao;
CREATE DATABASE vistaVerdurao CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE vistaVerdurao;

CREATE TABLE fonte_dados (
  fonte_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  nome_arquivo TINYTEXT NOT NULL,
  tipo_dado VARCHAR(255) NOT NULL,
  formato VARCHAR(10) NOT NULL,
  data_upload TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status_validacao VARCHAR(20) NOT NULL,
  qtd_registros INT,
  qtd_rejeitados INT
);

CREATE TABLE cliente (
  cliente_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(255) NOT NULL,
  email VARCHAR(255),
  telefone VARCHAR(11),
  endereco VARCHAR(255),
  regiao_administrativa VARCHAR(60),
  latitude NUMERIC(9,6),
  longitude NUMERIC(9,6),
  id_fonte INT,
  INDEX idx_cliente_regiao (regiao_administrativa),
  CONSTRAINT fk_cliente_fonte_dados FOREIGN KEY (id_fonte) REFERENCES fonte_dados(fonte_id)
);

CREATE TABLE venda (
  venda_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  data_venda TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  valor_total NUMERIC(12,2) NOT NULL,
  canal VARCHAR(255),
  status_venda VARCHAR(20) DEFAULT 'Pendente',
  id_cliente INT NOT NULL,
  id_fonte INT,
  INDEX idx_venda_data (data_venda),
  CONSTRAINT fk_venda_cliente FOREIGN KEY (id_cliente) REFERENCES cliente(cliente_id),
  CONSTRAINT fk_venda_fonte_dados FOREIGN KEY (id_fonte) REFERENCES fonte_dados(fonte_id)
);

CREATE TABLE produto (
  produto_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  nome_produto VARCHAR(255) NOT NULL,
  colecao VARCHAR(255) NOT NULL,
  tamanho VARCHAR(5) NOT NULL,
  categoria VARCHAR(255),
  preco NUMERIC(12,2) NOT NULL
);

CREATE TABLE item_venda (
  id_venda INT NOT NULL,
  id_produto INT NOT NULL,
  quantidade INT NOT NULL,
  preco_unitario NUMERIC(12,2),
  PRIMARY KEY (id_venda, id_produto),
  CONSTRAINT fk_item_venda_venda FOREIGN KEY (id_venda) REFERENCES venda(venda_id),
  CONSTRAINT fk_item_venda_produto FOREIGN KEY (id_produto) REFERENCES produto(produto_id)
);

CREATE TABLE estoque (
  estoque_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  quantidade INT NOT NULL,
  data_atualizacao TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  id_produto INT NOT NULL,
  id_fonte INT,
  CONSTRAINT fk_estoque_produto FOREIGN KEY (id_produto) REFERENCES produto(produto_id),
  CONSTRAINT fk_estoque_fonte_dados FOREIGN KEY (id_fonte) REFERENCES fonte_dados(fonte_id)
);

CREATE TABLE modelo_ia (
  modelo_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  nome_modelo VARCHAR(255) NOT NULL,
  tipo VARCHAR(20) NOT NULL,
  provedor VARCHAR(60),
  versao VARCHAR(20) NOT NULL,
  ativo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE execucao_processamento (
  execucao_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  tipo VARCHAR(20) NOT NULL,
  status_execucao VARCHAR(20) NOT NULL,
  data_inicio TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  data_fim TIMESTAMP NULL,
  log_correcoes TEXT,
  versao_prompt VARCHAR(10),
  mensagem_erro TEXT,
  id_fonte INT NOT NULL,
  id_modelo INT NOT NULL,
  CONSTRAINT fk_execucao_fonte_dados FOREIGN KEY (id_fonte) REFERENCES fonte_dados(fonte_id),
  CONSTRAINT fk_execucao_modelo_ia FOREIGN KEY (id_modelo) REFERENCES modelo_ia(modelo_id)
);

CREATE TABLE resultado_processado (
  resultado_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  tipo VARCHAR(20) NOT NULL,
  conteudo TEXT,
  dados_origem JSON NOT NULL,
  periodo_inicio DATE,
  periodo_fim DATE,
  status_resultado VARCHAR(20) NOT NULL,
  confiabilidade VARCHAR(10) NOT NULL,
  data_geracao TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  id_execucao INT NOT NULL,
  CONSTRAINT fk_resultado_execucao FOREIGN KEY (id_execucao) REFERENCES execucao_processamento(execucao_id)
);

-- NOVAS: usadas pelo agente de atendimento
CREATE TABLE prazo_entrega (
  regiao_administrativa VARCHAR(60) NOT NULL PRIMARY KEY,
  prazo_texto VARCHAR(60) NOT NULL
);

CREATE TABLE politica (
  chave VARCHAR(40) NOT NULL PRIMARY KEY,
  texto TEXT NOT NULL
);

CREATE TABLE mensagem_chat (
  mensagem_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  sessao_id VARCHAR(64) NOT NULL,
  papel VARCHAR(10) NOT NULL,
  conteudo TEXT NOT NULL,
  transferido_humano BOOLEAN NOT NULL DEFAULT FALSE,
  data_envio TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_chat_sessao (sessao_id, mensagem_id)
);

-- Estoque mais recente de cada produto
CREATE VIEW vw_estoque_atual AS
SELECT p.produto_id, p.nome_produto, p.colecao, p.tamanho, p.categoria, p.preco,
       COALESCE(e.quantidade, 0) AS quantidade
FROM produto p
LEFT JOIN estoque e
  ON e.id_produto = p.produto_id
 AND e.data_atualizacao = (
       SELECT MAX(e2.data_atualizacao) FROM estoque e2 WHERE e2.id_produto = p.produto_id
     );

-- DADOS DE TESTE (fictícios; apague quando importar os dados reais)
INSERT INTO fonte_dados (nome_arquivo, tipo_dado, formato, status_validacao, qtd_registros, qtd_rejeitados)
VALUES ('seed_dev.sql', 'estoque', 'sql', 'VALIDADO', 2, 0);

INSERT INTO produto (nome_produto, colecao, tamanho, categoria, preco) VALUES
  ('Camisa Algodão Orgânico', 'Flona', 'M', 'Camisetas', 119.90),
  ('Bermuda Reciclada', 'Upcycling', 'G', 'Calças & Shorts', 149.90);

INSERT INTO estoque (quantidade, id_produto, id_fonte) VALUES (45, 1, 1), (12, 2, 1);

INSERT INTO prazo_entrega (regiao_administrativa, prazo_texto) VALUES
  ('Plano Piloto', '1 dia útil'),
  ('Águas Claras', '2 dias úteis'),
  ('Taguatinga', '2 dias úteis');

INSERT INTO politica (chave, texto) VALUES
  ('troca', 'Prazo de 30 dias após o recebimento. Sem custo para a primeira troca na região do DF.');