# frozen_string_literal: true

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  ruby '>= 2.4.0'
  gem 'tty-prompt'
  gem 'cryptocompare'
  gem 'binance-ruby'
  gem 'dotenv'
end

require 'tty-prompt'
require 'cryptocompare'
require 'binance-ruby'
require 'dotenv/load'

info = Binance::Api::Account.info!

assets = info[:balances].map do |balance|
  next if balance[:free].to_f + balance[:locked].to_f <= 0

  price = Cryptocompare::Price.find(balance[:asset], 'USD')[balance[:asset]]['USD']
  {
    symbol: balance[:asset],
    amount: balance[:free].to_f + balance[:locked].to_f,
    value: ((balance[:free].to_f + balance[:locked].to_f) * price),
    price: price
  }
end.reject!(&:nil?)

puts '-------------------------------------------'
puts 'Your assets in spot wallet:'
assets = assets.sort_by! { |k| k[:value] }.reverse!
assets.each do |asset|
  puts "#{asset[:symbol]}: #{asset[:value].round(2)}$, amount: #{asset[:amount]}"
end
puts '-------------------------------------------'
coins = []
assets.each do |asset|
  symbol = asset[:symbol]
  print "            \r"
  print "#{symbol}\r"
  next if %w[BUSD USDT].include?(symbol)

  trades_usdt = Binance::Api::Account.trades!(symbol: "#{symbol}USDT")
  begin
    trades_busd = Binance::Api::Account.trades!(symbol: "#{symbol}BUSD")
  rescue Binance::Api::Error::BadSymbol
    next
  end

  trades = trades_usdt + trades_busd
  buy_amount = 0
  avg_buy_price = 0
  sell_amount = 0
  avg_sell_price = 0
  trades.sort_by! { |k| k[:time] }.each do |trade|
    if trade[:isBuyer]
      avg_buy_price = ((buy_amount * avg_buy_price) + trade[:quoteQty].to_f) / (buy_amount + trade[:qty].to_f)
      buy_amount += trade[:qty].to_f
    else
      avg_sell_price = ((sell_amount * avg_sell_price) + trade[:quoteQty].to_f) / (sell_amount + trade[:qty].to_f)
      sell_amount += trade[:qty].to_f
      buy_amount -= sell_amount if buy_amount.positive?
    end
  end
  avg_buy_price = asset[:price] if avg_buy_price.zero?
  percent = ((asset[:price] - avg_buy_price) / asset[:price]) * 100
  coin = {
    symbol: asset[:symbol],
    amount: buy_amount,
    amount_spot: asset[:amount],
    average_buy_price: avg_buy_price,
    average_sell_price: avg_sell_price,
    current_price: asset[:price],
    value: buy_amount * asset[:price],
    percent: percent
  }
  coins << coin
end

assets = coins.sort_by! { |k| k[:percent] }.reverse!
puts 'Wallet analisis:'
assets.each do |asset|
  puts asset[:symbol]
  puts " Amount: #{asset[:amount]}"
  puts " Average buy price: #{asset[:average_buy_price]}"
  puts " Current price: #{asset[:current_price]}"
  puts " Value: #{asset[:value].round(2)}$"
  puts " #{asset[:percent].round(2)}%"
  puts '|------------------------------------|'
end
