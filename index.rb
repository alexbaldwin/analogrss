require 'sinatra'
require 'redis'

get '/' do
	"Hello World!"
end

get '/analogprocess.rss' do
	content_type 'text/xml'
	redis = Redis.new(url: "redis://:p119783d3705854696d68cbbe3e8218b1f2312d40dc40de730a7ff0ba065e9eed@ec2-35-172-46-76.compute-1.amazonaws.com:6999")
	redis.get("rss")
end
