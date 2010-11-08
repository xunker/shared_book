require 'spec_helper'

def gem_root
  File.dirname(__FILE__) + '/../..'
end

def post_should_get_response_error(method, arg=nil)
  @sharedbook.should_receive(:post_url).and_return(@bad_return)
  method_should_get_response_error(method, arg)
end

def get_should_get_response_error(method, arg=nil)
  @sharedbook.should_receive(:get_url).and_return(@bad_return)
  method_should_get_response_error(method, arg)
end

def method_should_get_response_error(method, arg=nil)
  lambda { arg ? @sharedbook.send(method, arg) : @sharedbook.send(method) }.should raise_error(ResponseError)
end

describe SharedBook do
  before(:each) do
    @valid = {:product_api_key => 'x', :product_secret_word => 'x', :auth_token => 'x', :session_token => 'aabbcc'}
    @sharedbook = SharedBook.new(@valid)
    @bad_return = "<p>B0RKEN!</p>"
  end
    
  describe '.new' do
    it 'should require product_api_key, product_secret_word and auth_token' do
      lambda { SharedBook.new(:product_api_key => 'x', :product_secret_word => 'x') }.should raise_error(MissingAuthTokenError)
      
      lambda { SharedBook.new(:product_api_key => 'x', :auth_token => 'x') }.should raise_error(MissingProductSecretWordError)
      
      lambda { SharedBook.new(:auth_token => 'x', :product_secret_word => 'x') }.should raise_error(MissingProductApiKeyError)
    end    
  end
  
  describe '.auth_login_url' do
    it 'should return the login url that the web user should be sent to' do
      SharedBook.auth_login_url.should == "#{SharedBook::URL}/auth/login"
    end
  end
  
  describe '#auth_getSessionToken' do
    before(:each) do
      @sharedbook = SharedBook.new(@valid.merge(:session_token => nil))
    end
    
    it 'should get the session token for a given auth_token' do
      # expect
      @sharedbook.should_receive(:get_url).with("#{SharedBook::URL}/auth/getSessionToken", {:apiKey=>"x", :authToken=>"x"}).and_return(
        "<auth.getSessionToken status=\"ok\">\n\t<sessionToken>a1b2c3</sessionToken>\n</auth.getSessionToken>"
      )
      
      @sharedbook.auth_getSessionToken.should == "a1b2c3"
    end
    
    it "should return the already-known session ID if we already know it" do
      # given
      @sharedbook.stub(:session_token).and_return('xyz')
      
      # expect
      @sharedbook.should_not_receive(:get_url)
      
      # when
      @sharedbook.auth_getSessionToken.should == 'xyz'
    end
    
    it "should raise ResponseError if the response cannot be parsed" do
      # expect
      get_should_get_response_error(:auth_getSessionToken)
    end
  end
  
  describe '#session_token' do
    it "should return the current session token" do
      # given
      sharedbook = SharedBook.new(@valid.merge(:session_token => nil))
      # expect
      sharedbook.session_token.should be_nil
      
      # given
      sharedbook = SharedBook.new(@valid.merge(:session_token => 'abc'))
      # expect
      sharedbook.session_token.should == 'abc'
    end
  end
  
  describe '#bmscreate_init' do
    before(:all) do
      @return = "<bmscreate.init status=\"ok\">\n\t<bms id=\"11235\" />\n</bmscreate.init>"
    end
    context 'with one article' do
      it 'should post to the init url and return a bms_id' do
        # expect
        @sharedbook.should_receive(:post_url).with(
          "#{SharedBook::URL}/bmscreate/init",
          {:bookTitle=>"book title", :chapterTitle=>"chapter 1", :chapterText=>"text"}
        ).and_return(@return)
      
        # given
        @sharedbook.bmscreate_init("book title", {:chapterTitle => 'chapter 1', :chapterText => 'text'}).should == '11235'
        @sharedbook.bms_id.should == "11235"
      end
    end
    context 'with more than one article' do
      it 'should post to the init url and return a bms_id' do
        # expect
        @sharedbook.should_receive(:post_url).with(
          "#{SharedBook::URL}/bmscreate/init",
          {:chapterText1=>"text", :bookTitle=>"book title", :chapterTitle2=>"chapter 2", :chapterText2=>"text", :chapterTitle1=>"chapter 1"}
        ).and_return(@return)
      
        # given
        @sharedbook.bmscreate_init("book title", [
          {:chapterTitle => 'chapter 1', :chapterText => 'text'}, {:chapterTitle => 'chapter 2', :chapterText => 'text'}
        ]).should == '11235'
      end
    end
    
    it 'should raise ResponseError if the return cannot be parsed' do
      # expect
      @sharedbook.should_receive(:post_url).and_return(@bad_return)
      
      # given
      lambda {
        @sharedbook.bmscreate_init("book title", {:chapterTitle => 'chapter 1', :chapterText => 'text'}).should == '11235'
      }.should raise_error(ResponseError)
    end    
  end
  
  describe '#bmscreate_publish' do
    it 'should post the the publish url' do
      # expect
      @sharedbook.should_receive(:post_url).with(
        "#{SharedBook::URL}/bmscreate/publish",
        {:bmsId=>123}
      ).and_return("<publish status=\"ok\" />")
      
      # given
      @sharedbook.bmscreate_publish(123).should be_true
    end
    
    it 'should raise ResponseError if the return cannot be parsed' do
      # expect
      post_should_get_response_error(:bmscreate_publish, 123)
    end
  end
  
  describe '#bms_addComment' do
    it 'should post the add comment url and return a comment id' do
      # expect
      @sharedbook.should_receive(:post_url).with(
        "#{SharedBook::URL}/bms/addComment",
        {:ownerName=>"Joe", :commentTitle=>"title", :bmsId=>123, :commentText=>"text", :chapterNumber=>"1"}
      ).and_return(
        "<bms.addComment status=\"ok\">\n\t<comment id=\"x1y1z1\" />\n</bms.addComment>"
      )
      
      # given
      @sharedbook.bms_addComment({
        :bms_id => 123, :comment_title => 'title', :comment_text => 'text', :chapter_number => 1, :owner_name => 'Joe'
      }).should == 'x1y1z1'
      @sharedbook.comment_ids.should == ["x1y1z1"]
    end
    it 'should raise ResponseError if the return cannot be parsed' do
      # expect
      @sharedbook.should_receive(:post_url).and_return(@bad_return)
      
      # given
      lambda { @sharedbook.bms_addComment({
        :bms_id => 123, :comment_title => 'title', :comment_text => 'text', :chapter_number => 1, :owner_name => 'Joe'
      }) }.should raise_error(ResponseError)
    end
  end
  
  describe '#bms_addPhoto_by_url' do
    before(:each) do
      @image = "http://examp.le/x.jpg"
      @valid_post = {:bms_id => 123, :file_url => @image, :chapter_number => 1, :owner_name => 'Joe'}
    end
    
    it 'should post to the add photo url with the url of the photo to add and return a photo id' do
      # expect
      @sharedbook.should_receive(:post_url).with(
        "#{SharedBook::URL}/bms/addPhoto",
        {:ownerName=>"Joe", :bmsId=>123, :url => @image}
      ).and_return(
        "<bms.addPhoto status=\"ok\">\n\t<photo id=\"q1w2e3\" />\n</bms.addPhoto>"
      )
      
      # given
      @sharedbook.bms_addPhoto_by_url(@valid_post).should == 'q1w2e3'
      @sharedbook.photo_ids.should == ["q1w2e3"]
    end
    it 'should raise ResponseError if the return cannot be parsed' do
      # expect
      @sharedbook.should_receive(:post_url).and_return(@bad_return)
      
      # given
      lambda { @sharedbook.bms_addPhoto_by_url(@valid_post) }.should raise_error(ResponseError)
    end    
  end
  
  describe '#bms_addPhoto_by_handle' do
    before(:each) do
      @image = gem_root+"/spec/images/angry_squirrel.jpg"
      @valid_post = {:bms_id => 123, :file_name => @image, :file_mime => "image/jpeg", :chapter_number => 1, :owner_name => 'Joe'}
      UploadIO.stub!(:new)
    end
    
    it 'should post to the add photo url with the data of the photo to add and return a photo id' do
      # expect
      @sharedbook.should_receive(:post_url_file).with(
        "#{SharedBook::URL}/bms/addPhoto",
        {"photo"=>nil, :ownerName=>"Joe", :file_name=>@image, :file_mime=>"image/jpeg", :bmsId=>123}
      ).and_return(
        "<bms.addPhoto status=\"ok\">\n\t<photo id=\"q1w2e3\" />\n</bms.addPhoto>"
      )
      
      # given
      @sharedbook.bms_addPhoto_by_handle(@valid_post).should == 'q1w2e3'
      @sharedbook.photo_ids.should == ["q1w2e3"]
    end
    it 'should raise ResponseError if the return cannot be parsed' do
      # expect
      @sharedbook.should_receive(:post_url_file).and_return(@bad_return)
      
      # given
      lambda { @sharedbook.bms_addPhoto_by_handle(@valid_post) }.should raise_error(ResponseError)
    end    
  end

  describe '#bms_setFrontCoverPhoto' do
    before(:each) do
      @image = gem_root+"/spec/images/angry_squirrel.jpg"
      @id = "q1w2e3"
      @valid_post = {:bms_id => 123, :file_name => @image, :file_mime => "image/jpeg", :chapter_number => 1, :owner_name => 'Joe'}
      UploadIO.stub!(:new)
    end
    
    it 'should post the image data to the url for setting the front cover and return an id' do
      # expect
      @sharedbook.should_receive(:post_url_file).with(
        "#{SharedBook::URL}/bms/setFrontCoverPhoto",
        {"photo"=>nil, :ownerName=>"Joe", :file_name=>@image, :file_mime=>"image/jpeg", :bmsId=>123}
      ).and_return(
        "<bms.addPhoto status=\"ok\">\n\t<photo id=\"#{@id}\" />\n</bms.addPhoto>"
      )
      
      # given
      @sharedbook.bms_setFrontCoverPhoto(@valid_post).should == @id
      @sharedbook.front_cover_photo_id.should == @id
    end
    it 'should raise ResponseError if the return cannot be parsed' do
      # expect
      @sharedbook.should_receive(:post_url_file).and_return(@bad_return)
      
      # given
      lambda { @sharedbook.bms_setFrontCoverPhoto(@valid_post) }.should raise_error(ResponseError)
    end    
  end
  
  describe '#bms_setBackCoverPhoto' do
    before(:each) do
      @image = gem_root+"/spec/images/angry_squirrel.jpg"
      @id = "q1w2e3"
      @valid_post = {:bms_id => 123, :file_name => @image, :file_mime => "image/jpeg", :chapter_number => 1, :owner_name => 'Joe'}
      UploadIO.stub!(:new)
    end
    
    it 'should post the image data to the url for setting the front cover and return an id' do
      # expect
      @sharedbook.should_receive(:post_url_file).with(
        "#{SharedBook::URL}/bms/setBackCoverPhoto",
        {"photo"=>nil, :ownerName=>"Joe", :file_name=>@image, :file_mime=>"image/jpeg", :bmsId=>123}
      ).and_return(
        "<bms.addPhoto status=\"ok\">\n\t<photo id=\"#{@id}\" />\n</bms.addPhoto>"
      )
      
      # given
      @sharedbook.bms_setBackCoverPhoto(@valid_post).should == @id
      @sharedbook.back_cover_photo_id.should == @id
    end
    it 'should raise ResponseError if the return cannot be parsed' do
      # expect
      @sharedbook.should_receive(:post_url_file).and_return(@bad_return)
      
      # given
      lambda { @sharedbook.bms_setBackCoverPhoto(@valid_post) }.should raise_error(ResponseError)
    end    
  end
  
  describe '#bms_publish' do
    it 'should post the the publish url' do
      # expect
      @sharedbook.should_receive(:post_url).with(
        "#{SharedBook::URL}/bms/publish",
        {:bmsId=>123}
      ).and_return("<bms.publish status=\"ok\" />")
      
      # given
      @sharedbook.bms_publish(123).should be_true
    end
    
    it 'should raise ResponseError if the return cannot be parsed' do
      # expect
      post_should_get_response_error(:bms_publish, 123)
    end
  end
  
  describe '#bookcreate_init' do
    it 'should post the the publish url' do
      # expect
      @sharedbook.should_receive(:post_url).with(
        "#{SharedBook::URL}/bookcreate/init",
        {:bmsId=>123}
      ).and_return("<bookcreate.init status=\"ok\" />")
      
      # given
      @sharedbook.bookcreate_init(123).should be_true
    end
    
    it 'should raise ResponseError if the return cannot be parsed' do
      # expect
      post_should_get_response_error(:bookcreate_init, 123)
    end
  end

  describe '#bookcreate_setDedication' do
    it 'should post the the publish url' do
      # expect
      @sharedbook.should_receive(:post_url).with(
        "#{SharedBook::URL}/bookcreate/setDedication",
        {:dedicationText=>"Dedicated!", :bmsId=>123}
      ).and_return("<bookcreate.setDedication status=\"ok\" />")
      
      # given
      @sharedbook.bookcreate_setDedication({:bms_id => 123, :dedication_text => "Dedicated!"}).should be_true
    end
    
    it 'should raise ResponseError if the return cannot be parsed' do
      # expect
      post_should_get_response_error(:bookcreate_setDedication, 123)
    end
  end  
  
  describe '#bookcreate_publish' do
    it 'should post to the bookcreate publish url and return a book_id' do
      # expect
      @sharedbook.should_receive(:post_url).with(
        "#{SharedBook::URL}/bookcreate/publish",
        {:bmsId=>123}
      ).and_return(
        "<bookcreate.publish status=\"ok\" />\n\t<book id=\"54321\" />\n</bookcreate.init>"
      )
      
      # given
      @sharedbook.bookcreate_publish(123).should == "54321"
      @sharedbook.book_id.should == "54321"
    end
    
    it 'should raise ResponseError if the return cannot be parsed' do
      # expect
      post_should_get_response_error(:bookcreate_publish, 123)
    end
  end
  
  describe '#book_preview' do
    before(:all) do
      @preview_url = 'http://www.examp.le/12345'
    end
    it 'should post to the book preview url and return a preview url' do
      # expect
      @sharedbook.should_receive(:get_url).with(
        "#{SharedBook::URL}/book/preview",
        {:sessionToken=>"aabbcc", :apiKey=>"x", :authToken=>"x", :bookId=>"321", :redirect=>"false", :bmsId=>"123", :signature=>"5949fa652c1dba35111d978541ecb44e"}
      ).and_return(
        "<book.preview status=\"ok\">\n\t<url>#{@preview_url}</url></book.preview>"
      )
      
      # given
      @sharedbook.book_preview(123,321).should == @preview_url
      @sharedbook.book_url.should == @preview_url
      
    end
    
    it 'should raise ResponseError if the return cannot be parsed' do
      # expect
      @sharedbook.should_receive(:get_url).and_return(@bad_return)
      
      # given
      lambda { @sharedbook.book_preview(123,321) }.should raise_error(ResponseError)
      
    end
  end
   
end
