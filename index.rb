require 'sinatra'

get '/' do
	"Hello World!"
end

get '/analogprocess.rss' do
	send_file File.join('./analogprocess.rss')
end
