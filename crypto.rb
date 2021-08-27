# frozen_string_literal: true

require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  ruby ">= 2.4.0"
  gem "tty-prompt"
  gem "cryptocompare"
  gem "binance-ruby"
end

require "tty-prompt"
require "cryptocompare"
require "binance-ruby"

Binance::Api::Configuration.api_key = "Ra8xHhmpVr2yX2h9i6IRec9T6fAwecoq4ZCNEtymXn7MIfuZh9kDkmA3q1LvNm00"
Binance::Api::Configuration.read_info_api_key = "Ra8xHhmpVr2yX2h9i6IRec9T6fAwecoq4ZCNEtymXn7MIfuZh9kDkmA3q1LvNm00"
Binance::Api::Configuration.secret_key = "CxZwXwWW8oDa0EVpCx0BPfE7q8KT0Lra3PBEQ6VIz8recLNkMhPVOaJpaninOeTk"

info = Binance::Api::Account.info!

assets = info[:balances].map { |balance| { symbol: balance[:asset], amount: balance[:free].to_f + balance[:locked].to_f } if balance[:free].to_f + balance[:locked].to_f > 0 }.reject! { |x| x.nil? }
trades = []
puts "Your assets in spot wallet:"
assets.each do |asset|
  price = Cryptocompare::Price.find(asset[:symbol], "USD")
  puts asset[:symbol] + ": " + (asset[:amount] * price[asset[:symbol]]["USD"]).round(2).to_s + "$"
end
assets.each do |asset|
  symbol = asset[:symbol]

  next if symbol == "BUSD" || symbol == "USDT"

  trades_usdt = Binance::Api::Account.trades!(symbol: "#{symbol}USDT")
  begin
    trades_busd = Binance::Api::Account.trades!(symbol: "#{symbol}BUSD")
  rescue Binance::Api::Error::BadSymbol
    puts "-------------------------------------------"
    puts "Warning: pair " + symbol + "BUSD" + " doesn't exist"
    puts "-------------------------------------------"
    next
  end
  trades << trades_usdt
  trades << trades_busd
end

puts trades
