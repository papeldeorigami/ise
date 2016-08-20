#!/usr/bin/ruby
#
require 'watir-webdriver'
require 'nokogiri'

BASE_URL = ENV['BASE_URL']

class WebScrapper
  def initialize
    @browser = Watir::Browser.new :firefox, :profile => 'default'
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
            empresa['nome'] = nome_empresa.text
            row.css(".center").each do |td|
              link = td.css("a").first
              unless link.nil?
                links.push link['href']
              else
                links.push td.text
              end
            end
            links.each_with_index do |link, i|
              empresa[headers[i]] = link
            end
            empresas.push empresa
          end
        end
      end
    end

    return empresas
  end

  def extrair_relatorios_do_ano(ano)
    begin
      @browser.goto BASE_URL + '&qid=' + ano
      until @browser.div(:class=>"box01").exists? do sleep 1 end

      empresas = extrair_links_relatorios_por_empresa()

      empresas.each do |empresa|
        empresa.keys.each do |key|
          puts key + ": " + empresa[key]
        end
      end

      puts "Foram encontrada(s) " + empresas.length.to_s + " empresas(s)"
    ensure
      @browser.close
    end
  end
end

scrapper = WebScrapper.new
scrapper.extrair_relatorios_do_ano("2015")
