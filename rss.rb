require 'httparty'
require 'json'
require "awesome_print"
require 'htmlentities'
require 'date'
require "ferrum"
require "nokogiri"
require 'open-uri'
require 'rss'
require 'redis'

analog_uri = "https://www.reddit.com/r/analog/top.json"

response = HTTParty.get(analog_uri, {headers: {"User-Agent" => "Httparty Analog RSS Feed"}})

analog_json = response.body
data_hash = JSON.parse(analog_json)

analog_items = data_hash["data"]["children"]

def fetch_ig_from_reddit(reddit_username)
	browser = Ferrum::Browser.new(timeout: 30, process_timeout: 60, browser_options: { 'no-sandbox': nil })
	browser.go_to("https://www.reddit.com/user/#{reddit_username}/")
	html = browser.body

	browser.quit

	@doc = Nokogiri::XML(html)
	ig_result = @doc.xpath("//img[contains(@src, 'instagram')]")

	if ig_result[0] != nil
		ig_result[0].text.to_s.downcase.strip
	else 
		nil
	end
end


def ig_from_flair(flair)
	flair_handle = flair
			.downcase
			.gsub('https://', '')
			.gsub('http://', '')
			.gsub('www.', '')
			.gsub('instagram.com/', '')
			.gsub(/\@(\w+)/, '\1')
			.gsub(/\insta: (\w+)/, '\1')
			.gsub(/\ig: (\w+)/, '\1')
			.gsub('/', '')
			.gsub(' ', '')
	if flair_handle != ""
		flair_handle
	else
		nil
	end

end

def verify_ig(ig_handle)
	# Verify the account is good
	ap "Testing #{ig_handle}"

	browser = Ferrum::Browser.new(timeout: 30, process_timeout: 60, browser_options: { 'no-sandbox': nil })
        browser.go_to("https://www.instagram.com/#{ig_handle}/")
	ap browser.inspect
        html = browser.body

        browser.quit

        @doc = Nokogiri::XML(html)
        username_result = @doc.xpath("//title")

	puts html

	ap username_result

	if username_result[0]
		ap username_result[0].text.downcase
		# return true if the reporting-endpoint exists
		return username_result[0].text.downcase.include? ig_handle.downcase
	else
		# return false if we don't get a result
		return false
	end
end


approved_posts = Array.new

analog_items.each do |item|
	id = item["data"]["id"].to_s
	title = HTMLEntities.new.decode(item["data"]["title"].to_s)
	author =  item["data"]["author"].to_s
	created_at = DateTime.strptime(item["data"]["created_utc"].to_s, '%s').to_s
	nsfw = item["data"]["over_18"].to_s
	next if nsfw == "true"

	upvotes = item["data"]["ups"].to_i
	next if upvotes <= 200

	ratio = item["data"]["upvote_ratio"].to_f
	next if ratio <= 0.95

	permalink = "https://reddit.com" + item["data"]["permalink"].to_s
	image_url = if item["data"]["preview"]
			item["data"]["url_overridden_by_dest"].to_s
		else
			nil
		end

	next if image_url == nil

	reddit_ig_handle = fetch_ig_from_reddit(author)

	flair = item["data"]["author_flair_text"].to_s
	flair_ig_handle = ig_from_flair(flair)

	ig_handle =
		if reddit_ig_handle != nil
			reddit_ig_handle
		elsif flair_ig_handle != nil
			flair_ig_handle
		else
			nil
		end
	next if ig_handle == nil

	verified = 
		if ig_handle != nil
			verify_ig(ig_handle)
		else
			false
		end
	next if verified == false

	description = "#{title} ???? Photo credit: @#{ig_handle}"
	imgix_url = image_url.gsub('https://i.redd.it/', 'https://sc-ig.imgix.net/')

	post_hash = {id: id, title: title, description: description, author: author, ig_handle: ig_handle, verified: verified, created_at: created_at, nsfw: nsfw, upvotes: upvotes, ratio: ratio, permalink: permalink, image_url: image_url, imgix_url: imgix_url}

	ap post_hash
	approved_posts << post_hash

	# ap approved_posts
end

	rss = RSS::Maker.make("atom") do |maker|
		maker.channel.author = "analogprocess"
		maker.channel.updated = Time.now.to_s
		maker.channel.about = "https://analogrss.herokuapp.com/analogprocess.rss"
		maker.channel.title = "@analogprocess"
	
		approved_posts.each do |post|
			maker.items.new_item do |item|
				item.id = post[:permalink]
				item.link = post[:permalink]
				item.title = post[:description]
				item.summary = post[:imgix_url]
				item.updated = post[:created_at]
			end
		end
	end

	# File.open('analogprocess.rss', 'w') { |file| file.write(rss) }

	redis = Redis.new(url: "redis://:p119783d3705854696d68cbbe3e8218b1f2312d40dc40de730a7ff0ba065e9eed@ec2-35-172-46-76.compute-1.amazonaws.com:6999")
	redis.set("rss", rss.to_s)
	
	puts "See results at -> https://analogrss.herokuapp.com/feed.xml"



