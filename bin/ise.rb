#!/usr/bin/ruby
require 'watir-webdriver'
require 'nokogiri'
require 'axlsx'
require 'fileutils'
require 'json'
require 'active_support/core_ext/hash'
require 'logger'

logger = Logger.new('| tee app.log')

BASE_URL = ENV['BASE_URL']
DESTINATION_DIR = ENV['DESTINATION_DIR']
CATEGORIAS = ['Geral','Natureza do Produto','Governança Corporativa','Econômico - Financeira','Ambiental','Social','Mudanças Climáticas']

ANO_URL = {
  "2012" => "/index.php?r=relatorio",
  "2013" => "/?r=relatorio&qid=3",
  "2014" => "/index.php?r=relatorio&qid=4",
  "2015" => "/index.php?r=relatorio&qid=2014",
  "2016" => "/index.php?r=relatorio&qid=2015"
}

class WebScrapper
  attr_accessor :logger

  def initialize(alogger)
    #@browser = Watir::Browser.new :firefox, :profile => 'default'
    @browser = Watir::Browser.new :phantomjs
    @logger = alogger
  end

  def extrair_links_relatorios_por_empresa()
    empresas = []

    page = Nokogiri::HTML.parse(@browser.html)
    empresas_boxes = page.css(".box01 > .box02")

    empresas_boxes.each do |empresa_box|
      headers = empresa_box.css(".tit_table").map{ |th| th.text }
      unless headers.empty?
        rows = empresa_box.css("tr")
        rows.each do |row|
          nome_empresa = row.css(".tit_holding").first
          if nome_empresa.nil?
            nome_empresa = row.css(".tit_controlada").first
          end
          unless nome_empresa.nil?
            links = []
            empresa = {}
            empresa[:nome] = nome_empresa.text
            empresa[:links] = {}
            row.css(".center").each do |td|
              link = td.css("a").first
              unless link.nil?
                links.push link['href']
              else
                links.push td.text
              end
            end
            links.each_with_index do |link, i|
              empresa[:links][headers[i]] = link
            end
            empresas.push empresa
          end
        end
      end
    end

    return empresas
  end

  def extrair_relatorio(link, filename)
    @browser.goto BASE_URL + link
    iframe = @browser.iframe
    until iframe.ol(:id=>"questionnaire").exists? do sleep 1 end
    html = iframe.html.sub('<link rel="stylesheet" type="text/css" href="https://sistema.isebvmf.com.br/css/style_questionnaire2.css">',
                           '<link rel="stylesheet" type="text/css" href="../../css/style_questionnaire.css"><link rel="stylesheet" type="text/css" href="../../css/style_questionnaire2.css"><link rel="stylesheet" type="text/css" href="../../css/bootstrap.css">')

    File.open(filename, 'w') { |f| f.write html }
    page = Nokogiri::HTML.parse(iframe.html)
    relatorio = {}
    page.css('li.category[level="1"]').each do |criterio_block|
      criterio = criterio_block.css('.categoria').first.text.sub(/(CRITÉRIO \w+).*/,'\1')
      criterio_text = criterio_block.css('.categoria').first.text.sub(/CRITÉRIO \w+[–\s]+(.*)/,'\1')
      logger.info criterio + ' ' + criterio_text
      relatorio[criterio] = {}
      relatorio[criterio]["texto"] = criterio_text
      criterio_block.css('li.category[level="2"]').each do |indicador_block|
        indicador = indicador_block.css('.categoria').first.text.sub(/(INDICADOR \d+).*/,'\1')
        indicador_text = indicador_block.css('.categoria').first.text.sub(/INDICADOR \d+[\.\s]+(.*)/,'\1')
        logger.info indicador + ' ' + indicador_text
        relatorio[criterio][indicador] = {}
        relatorio[criterio][indicador]["texto"] = indicador_text
        indicador_block.css('li.question div.block').each do |questao_block|
          questao = questao_block.css('div.number_list').first.text
          questao_text = questao_block.css('h2.nome').first.text
          logger.info questao + ' ' + questao_text
          relatorio[criterio][indicador][questao] = {}
          relatorio[criterio][indicador][questao]["texto"] = questao_text
          questao_block.css('table.choices').each do |alternativa_block|
            niveis = []
            alternativa_block.css('thead > tr > th').each do |nivel_block|
              nivel = nivel_block.text
              unless nivel.empty?
                niveis.push nivel
              end
            end
            alternativa_block.css('tbody > tr').each do |alternativa_row_block|
              alternativa_text = ''
              alternativa_row_block.css('td.text-col').each do |alternativa_text_block|
                alternativa_text = alternativa_text_block.text[0,1]
              end
              unless alternativa_text.empty?
                nivel = 0
                alternativa_row_block.css('td').each do |alternativa_resposta_block|
                  if alternativa_resposta_block.css('i').length > 0
                    alternativa = alternativa_text + ' ' + niveis[nivel]
                    #logger.info alternativa
                    if alternativa_resposta_block.css('i.icon-ok').length > 0
                      resposta = 'X'
                    else
                      resposta = ''
                    end
                    #logger.info resposta
                    relatorio[criterio][indicador][questao][alternativa] = resposta
                    nivel = nivel + 1
                  end
                end
              end
            end
          end
          questao_block.css('div.choices > div').each do |alternativa_block|
            alternativa = alternativa_block.css('label').first.text[0,1]
            #logger.info alternativa
            if alternativa_block.css('i.icon-ok').length > 0
              resposta = 'X'
            else
              resposta = ''
            end
            #logger.info resposta
            relatorio[criterio][indicador][questao][alternativa] = resposta
          end
        end
      end
    end
    return relatorio
  end

  def extrair_relatorios_do_ano(ano)
    empresas = []
    begin
      @browser.goto BASE_URL + ANO_URL[ano]
      until @browser.div(:class=>"box01").exists? do sleep 1 end

      empresas = extrair_links_relatorios_por_empresa()

      #logger.info "Foram encontrada(s) " + empresas.length.to_s + " empresas(s)"

      empresas.each do |empresa|
        links = empresa[:links]
        empresa[:relatorios] = {}
        links.keys.each do |categoria|
          link = links[categoria]
          dir = DESTINATION_DIR + ano + "/"
          FileUtils.mkdir_p dir
          nome_empresa = empresa[:nome]
          filename = dir + nome_empresa + '_' + categoria + '.html'
          logger.info "Empresa: " + nome_empresa + ', Categoria: ' + categoria + ', link: ' + link
          if link != 'N/A'
            relatorio = extrair_relatorio(link, filename)
            empresa[:relatorios][categoria] = relatorio
            File.write('relatorios/' + ano + '/relatorio_' + nome_empresa + '_' + categoria + '.json', relatorio.to_json)
          end
        end
        #break
      end

      empresas.each do |empresa|
        empresa.delete(:links)
      end
      File.write('relatorios_' + ano + '.json', empresas.to_json)

    ensure
      @browser.close
    end

    return empresas
  end
end

def gerar_excel(empresas, filename)
  xlsx = Axlsx::Package.new
  primeiro_relatorio = empresas.first[:relatorios]
  textos_sheet = xlsx.workbook.add_worksheet(:name => "Textos")
  textos_sheet.add_row ["categoria","criterio","indicador","questao","texto"]
  CATEGORIAS.each do |categoria|
    logger.info "Categoria " + categoria
    sheet = xlsx.workbook.add_worksheet(:name => categoria)
    criterios = primeiro_relatorio[categoria]
    criterios.keys.drop(1).each do |criterio|
      logger.info "Criterio " + criterio
      logger.info criterios[criterio]["texto"]
      textos_sheet.add_row [categoria,criterio,"","",criterios[criterio]["texto"]]
      indicadores = criterios[criterio]
      indicadores.keys.drop(1).each do |indicador|
        logger.info "Indicador " + indicador
        questoes = indicadores[indicador]
        if questoes.nil?
          next
        end
        logger.info indicadores[indicador]["texto"]
        textos_sheet.add_row [categoria,criterio,indicador,"",indicadores[indicador]["texto"]]
        questoes.keys.drop(1).each do |questao|
          logger.info "Questao " + questao
          alternativas = questoes[questao]
          unless alternativas.nil?
            logger.info questoes[questao]["texto"]
            textos_sheet.add_row [categoria,criterio,indicador,questao,questoes[questao]["texto"]]
            alternativas_array = alternativas.keys.drop(1)
            #logger.info "Alternativas " + alternativas_array
            sheet.add_row [indicador,criterio,questao,questoes[questao]["texto"]] + alternativas_array
            empresas.each do |empresa|
              unless empresa[:relatorios].nil? || empresa[:relatorios][categoria].nil?
                #logger.info empresa[:nome]
                respostas = []
                unless alternativas.nil?
                  alternativas.keys.drop(1).each do |alternativa|
                    criterios = empresa[:relatorios][categoria]
                    indicadores = criterios[criterio]
                    questoes = indicadores[indicador]
                    alternativas = questoes[questao]
                    unless alternativas.nil?
                      respostas.push alternativas[alternativa]
                    end
                  end
                end
                #logger.info respostas.to_s
                sheet.add_row [indicador,criterio,questao,empresa[:nome]] + respostas
              end
            end
          end
        end
      end
    end
  end
  xlsx.serialize(filename)
end

def load_empresas_from_file(ano)
  file = File.read('relatorios_' + ano + '.json')
  empresas = JSON.parse(file)
  empresas.each(&:symbolize_keys!)
  return empresas
end

$stdout.sync = true
#%w(2012 2013 2014 2015 2016).each do |ano|
%w(2015).each do |ano|
  logger.info "Extraindo carteira " + ano
  empresas = WebScrapper.new(logger).extrair_relatorios_do_ano(ano)
  #empresas = load_empresas_from_file(ano)
  gerar_excel(empresas, ano + '.xlsx')
end
