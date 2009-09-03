require 'image_db'

require 'net/http'
require 'uri'
require 'multipart'
require 'yaml'


# Based on code at http://kfahlgren.com/blog/2006/11/01/multipart-post-in-ruby-2/

TIMEOUT_SECONDS=30

class HTTPImageDB < ImageDB

  def add_image(image_path, image_label)
    def post_form(url, query, headers)
      Net::HTTP.start(url.host, url.port) {|con|
        con.read_timeout = TIMEOUT_SECONDS
        begin
          return con.post(url.path, query, headers)
        rescue => e
          puts "POSTING Failed #{e}... #{Time.now}"
        end
      }
    end 

    params = Hash.new
  
    # Open the actually file I want to send
    file = File.open(image_path, "rb")
  
    # set the params to meaningful values
    params["image"] = file
    params["label"] = image_label
  
    # make a MultipartPost
    mp = Multipart::MultipartPost.new
  
    # Get both the headers and the query ready, given the new
    # MultipartPost and the params Hash
    query, headers = mp.prepare_query(params)
  
    # done with file now
    file.close
    
    # Do the actual POST, given the right inputs
    res = post_form(URI.parse("#{@db}add"), query, headers)
    
    # res holds the response to the POST
    case res
    when Net::HTTPSuccess
      return true
    else
      puts "Unknown error #{res}: #{res.inspect} #{res.body}"
      return false
    end
  end

  def remove_image(image_label)
    def post_form(url, query, headers)
      Net::HTTP.start(url.host, url.port) {|con|
        con.read_timeout = TIMEOUT_SECONDS
        begin
          return con.post(url.path, query, headers)
        rescue => e
          puts "POSTING Failed #{e}... #{Time.now}"
        end
      }
    end 

    params = Hash.new
  
    params["label"] = image_label
  
    # make a MultipartPost
    mp = Multipart::MultipartPost.new
  
    # Get both the headers and the query ready, given the new
    # MultipartPost and the params Hash
    query, headers = mp.prepare_query(params)
  
    # Do the actual POST, given the right inputs
    res = post_form(URI.parse("#{@db}del"), query, headers)
    # res holds the response to the POST
    case res
    when Net::HTTPSuccess
      return true
    else
      puts "Unknown error #{res}: #{res.inspect} #{res.body}"
      return false
    end
  end

  def match_image(image_path)
    def post_form(url, query, headers)
      Net::HTTP.start(url.host, url.port) {|con|
        con.read_timeout = TIMEOUT_SECONDS
        begin
          return con.post(url.path, query, headers)
        rescue => e
          puts "POSTING Failed #{e}... #{Time.now}"
        end
      }
    end 

    # my server expects the params of the POST to use the rails-like
    # "blah[bar]” syntax, and I need to send two things other than the
    # file itself. These are stored in the params Hash
    params = Hash.new
    
    # Open the actually file I want to send
    file = File.open(image_path, "rb")
    
    # set the params to meaningful values
    params["image"] = file
  
    # make a MultipartPost
    mp = Multipart::MultipartPost.new
    
    # Get both the headers and the query ready, given the new
    # MultipartPost and the params Hash
    query, headers = mp.prepare_query(params)
    
    # done with file now
    file.close
    
    # Do the actual POST, given the right inputs
    res = post_form(URI.parse("#{@db}match"), query, headers)
    
    # We are going to attempt to populate this and will always return it
    results = []

    # res holds the response to the POST
    case res
    when Net::HTTPSuccess
      # The image server returns results as YAML.
      matches = YAML.load(res.body)
      return results if !matches
      matches.each do |m|
        # We need to clean up the image DB labels so we don't need
        # this .to_s.split... garbage.
        result = ImageMatchResult.new(m['label'].to_s.split("/").last.to_i, m['score'], m['percentage'])
        results.push(result)
      end
    else
      puts "Unknown error #{res}: #{res.inspect} #{res.body}"
    end
    return results
  end

  def list
    response = Net::HTTP.get(URI.parse("#{@db}list"))
    list = YAML.load(response)
    entries = []
    list.each do |l|
      entry = ImageDBEntry.new(l['label'], l['num_features'])
      entries.push(entry)
    end
    return entries
  end

end
