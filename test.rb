require 'sinatra'
require 'byebug'

post '/upload' do
  byebug
  puts params
end
