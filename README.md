# ISE

Script para tabular relatorios do Indice de Sustentabilidade Empresarial

## Instalação de pré-requisitos

Testado com Ruby version: ruby-2.2.4 em Ubuntu 16.04

gem install foreman

sudo apt-get install npm
sudo ln -s /usr/bin/nodejs /usr/bin/node
sudo npm install -g phantomjs-prebuilt

### Setup

Instalar dependencias:

    bundle install

Ajustar variaveis de ambiente:

    cp .env.example .env

## Como rodar o programa

    foreman start
