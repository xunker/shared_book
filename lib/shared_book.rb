# order of calls
#
# s = SharedBook.new { ... }
# s.get_session_token .. or .. pass :get_session_token => true to .new
# s.bmscreate_init('test book', {:chapterTitle => 'chapter 1', :chapterText => 'text'})
#   ... or ...
# s.bmscreate_init('test book', [{:chapterTitle => 'chapter 1', :chapterText => 'text'}, {:chapterTitle => 'chapter 2', :chapterText => 'text'}])
# s.bmscreate_publish
# s.bms_addComment { ... }
# s.bms_addPhoto_by_url { ... }
# s.bms_addPhoto_by_handle { ... }
# s.bms_setFrontCoverPhoto { ... }
# s.bms_setBackCoverPhoto { ... }
# s.bms_publish
# s.bookcreate_init
# s.bookcreate_setDedication { ... }
# s.bookcreate_publish
# s.book_preview

class SharedBookError < StandardError; end
class MissingCredentialError < SharedBookError; end
class MissingAuthTokenError < MissingCredentialError; def to_s; "Please supply auth_token given from '/auth/login'"; end; end
class MissingSessionTokenError < MissingCredentialError; end
class MissingProductApiKeyError < MissingCredentialError; def to_s; "Please supply product_api_key"; end; end
class MissingProductSecretWordError < MissingCredentialError; def to_s; "Please supply product_secret_word"; end; end
class ResponseError < SharedBookError; end

class SharedBook
  require 'rubygems'
  require 'kconv'
  require 'net/http'
  require 'net/http/post/multipart'
  require 'digest/md5'
  require 'uri'
  
  URL = "http://api.sharedbook.com/v0.6"
  DEFAULT_THEME = 'vanilla'
  
  attr_reader :product_api_key, :session_token, :auth_token, :product_secret_word, :bms_id, :book_id, :comment_ids, :photo_ids, :front_cover_photo_id, :back_cover_photo_id, :book_url
  attr_accessor :book_title, :articles 
  
  def initialize(opts = {})
    if opts[:product_api_key]
      @product_api_key = opts[:product_api_key]
    else
      raise MissingProductApiKeyError
    end
    
    if opts[:product_secret_word]
      @product_secret_word = opts[:product_secret_word]
    else
      raise MissingProductSecretWordError
    end
    
    if opts[:auth_token]
      @auth_token = if opts[:auth_token] == 'auto'
        get_new_auth_token
      else
        opts[:auth_token]
      end
    else
      raise MissingAuthTokenError
    end
  
    if opts[:session_token]
      @session_token = opts[:session_token]
    else
      @session_token = auth_getSessionToken if opts[:get_session_token]
    end

  end
  
  def self.auth_login_url
    "#{URL}/auth/login"
  end
    
  def auth_getSessionToken
    return session_token if session_token # you can't call the service twice with the same auth_token
    response = get_url("#{URL}/auth/getSessionToken", :apiKey => @product_api_key, :authToken => @auth_token)
    parse_response(response, /\<sessionToken\>(.*)\<\/sessionToken\>/)
  end
  
  def session_token
    @session_token
  end
    
  def bmscreate_init(book_title=@book_title, articles=@articles, theme=DEFAULT_THEME)
    article_hash = if articles.class == Array
      hh = {}
      articles.each_with_index do |article, i|
        hh["chapterTitle#{i+1}".to_sym] = article[:chapterTitle]
        hh["chapterText#{i+1}".to_sym] = article[:chapterText]
      end
      hh
    else
      articles # expected to be hash with :chapterTitle and :chapterText
    end
    response = post_url("#{URL}/bmscreate/init", {:bookTitle => book_title}.merge(article_hash))
    @bms_id = parse_response(response, /\<bms id=\"(\d+)\"/)
  end
  
  def bmscreate_publish(bms_id = @bms_id) 
    response = post_url("#{URL}/bmscreate/publish", {:bmsId => bms_id})
    parse_response(response, /status=\"ok\"/) { true }
  end
  
  def bms_addComment(opts = {})
    required = {:bmsId => opts[:bms_id] || @bms_id, :commentTitle => opts[:comment_title], :commentText => opts[:comment_text],
    :chapterNumber => opts[:chapter_number].to_s, :ownerName => opts[:owner_name]}
    optional = {:time => opts[:time], :commentId => opts[:comment_id]}.reject{|k,v| v.nil?}
    
    response = post_url("#{URL}/bms/addComment", required.merge(optional))
    
    parse_response(response, /comment id=\"(.*)\"/) do |match|
      @comment_ids ||= []
      @comment_ids << match[1]
      @comment_ids.last
    end
  end
  
  def bms_addPhoto_by_url(opts = {})
    required = {:bmsId => opts[:bms_id] || @bms_id, :url => opts[:file_url], :ownerName => opts[:owner_name]}
    optional = {:time => opts[:time], :caption => opts[:caption], :photoId => opts[:photo_id], :photoOrdinal => opts[:photo_ordinal]}.reject{|k,v| v.nil?}
    
    response = post_url("#{URL}/bms/addPhoto", required.merge(optional))
    parse_response(response, /\<photo id=\"(.*)\"/) do |match|
      @photo_ids ||= []
      @photo_ids << match[1]
      @photo_ids.last
    end
  end
  
  def bms_addPhoto_by_handle(opts = {})
    parse_response(post_photo_data("#{URL}/bms/addPhoto", opts), /\<photo id=\"(.*)\"/) do |match|
      @photo_ids ||= []
      @photo_ids << match[1]
      @photo_ids.last
    end
  end
  
  def bms_setFrontCoverPhoto(opts = {})
    @front_cover_photo_id = set_cover_photo(:front, opts)
  end
  
  def bms_setBackCoverPhoto(opts = {})
    @back_cover_photo_id = set_cover_photo(:back, opts)
  end
    
  def bms_publish(bms_id = @bms_id) 
    response = post_url("#{URL}/bms/publish", {:bmsId => bms_id})
    parse_response(response, /status=\"ok\"/) { true }
  end
  
  def bookcreate_init(bms_id = @bms_id) 
    response = post_url("#{URL}/bookcreate/init", {:bmsId => bms_id})    
    parse_response(response, /status=\"ok\"/) { true }
  end
  
  def bookcreate_setDedication(opts = {})
    response = post_url("#{URL}/bookcreate/setDedication", {:bmsId => opts[:bms_id] || @bms_id, :dedicationText => opts[:dedication_text]})
    parse_response(response, /status=\"ok\"/) { true }    
  end
  
  def bookcreate_publish(bms_id = @bms_id) 
    response = post_url("#{URL}/bookcreate/publish", {:bmsId => bms_id})
    @book_id = parse_response(response, /\<book id=\"(\d+)\" \/\>/)
  end
  
  def book_preview(bms_id = @bms_id, book_id = @book_id)
    query = {
        :bmsId => bms_id.to_s, :bookId => book_id.to_s, :redirect => 'false', :apiKey => @product_api_key,
        :sessionToken => session_token, :authToken => @auth_token
    }
    query.merge!(generate_signature(query))
    response = get_url("#{URL}/book/preview", query)
    @book_url = parse_response(response, /\<url\>(.*)\<\/url\>/).gsub(/&amp\;/, "&")
  end

private

  def parse_response(response, pattern, &block)
    if match = response.match(pattern)
      if block_given?
        yield match
      else
        match[1]
      end
    else
      raise ResponseError, response
    end
  end
    
  def get_url(path, query = {})
    url = URI.parse("#{path}?#{query_params(query)}")

    req = Net::HTTP::Get.new([url.path, url.query].join('?'))
    res = Net::HTTP.start(url.host, url.port) {|http|
      http.request(req)
    }
    res.body
  end
  
  def post_url(path, query = {})
    query.merge!({:apiKey => @product_api_key, :sessionToken => session_token, :authToken => @auth_token})
    query.merge!(generate_signature(query)) # must be added last
    
    res = Net::HTTP.post_form(URI.parse(path), query)

    case res
    when Net::HTTPSuccess, Net::HTTPRedirection
      res.body
    else
      raise ResponseError, res.error! #res.error!?
    end
    
  end
  
  def post_url_file(path, query = {})
    query.merge!({:apiKey => @product_api_key, :sessionToken => session_token, :authToken => @auth_token})
    query.merge!(generate_signature(query)) # must be added last

    url = URI.parse(path)
    req = Net::HTTP::Post::Multipart.new url.path, query
    res = Net::HTTP.start(url.host, url.port) do |http|
      http.request(req)
    end

    case res
    when Net::HTTPSuccess, Net::HTTPRedirection
      res.body
    else
      raise ResponseError, res.error! #res.error!?
    end
    
  end
  
  def query_params(query={})
    query.map{|k,v| [k, v].join('=')}.join('&')
  end
  
  def generate_signature(query)
    str=""
    query.keys.sort{|a,b| a.to_s <=> b.to_s}.each do |key|
      str << key.to_s+query[key] unless query[key].class == File
    end
    
    {:signature => Digest::MD5.hexdigest(@product_secret_word.toutf8+str.toutf8)}
  end
  
  def get_new_auth_token
    if ENV['RAILS_ENV']
      puts "*** YOU SHOULD ONLY USE THIS IN DEVELOPMENT MODE ***" unless ENV['RAILS_ENV'] == 'development'
    end
    
    res = Net::HTTP.post_form(URI.parse(SharedBook.auth_login_url), {:apiKey => @product_api_key})

    case res
    when Net::HTTPSuccess, Net::HTTPRedirection
      res.body.match(/\?authToken=(.*)\"\>/)[1]
    else
      raise ResponseError, res.error! #res.error!?
    end  
  end
  
  def set_cover_photo(cover, opts={})
    raise "only Front or Back cover" unless %w[front back].include?(cover.to_s)
    
    parse_response(post_photo_data("#{URL}/bms/set#{cover.to_s.capitalize}CoverPhoto", opts), /\<photo id=\"(.*)\"/)
  end
  
  def post_photo_data(url, opts={})
    required = {:bmsId => opts[:bms_id] || @bms_id, :file_name => opts[:file_name], :file_mime => opts[:file_mime], :ownerName => opts[:owner_name]}
    optional = {:time => opts[:time], :caption => opts[:caption], :photoId => opts[:photo_id], :photoOrdinal => opts[:photo_ordinal]}.reject{|k,v| v.nil?}
    
    File.open(opts[:file_name]) do |file_upload|
      post_url_file(url, required.merge(optional).merge({"photo" => UploadIO.new(file_upload, opts[:file_mime], opts[:file_name])}))
    end
  end
  
end