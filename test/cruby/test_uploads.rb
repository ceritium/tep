require_relative "helper"

# multipart/form-data file parts land in request.files, whole and
# binary-safe; text parts stay in params.
module UploadsTests
  APP = <<~RB
    post '/upload' do
      f = request.files["doc"]
      if f.nil?
        "no file"
      else
        data = f.read
        f.filename + "|" + f.type + "|" + f.size.to_s + "|" + data[0, 4] + "|" + data[data.bytesize - 4, 4] + "|" + params["title"]
      end
    end
  RB

  def multipart(contents)
    b = "----tepboundary42"
    body = "--#{b}\r\nContent-Disposition: form-data; name=\"title\"\r\n\r\nHello\r\n" \
           "--#{b}\r\nContent-Disposition: form-data; name=\"doc\"; filename=\"a.bin\"\r\n" \
           "Content-Type: application/x-test\r\n\r\n".b + contents + "\r\n--#{b}--\r\n".b
    [body, "multipart/form-data; boundary=#{b}"]
  end

  def test_binary_file_over_64k_arrives_whole
    contents = "HEAD".b + ("\x00\x01\xffz".b * 50_000) + "TAIL".b
    body, type = multipart(contents)
    res = Net::HTTP.start("127.0.0.1", @port, read_timeout: 10) do |h|
      h.post("/upload", body, "Content-Type" => type)
    end
    assert_equal "a.bin|application/x-test|200008|HEAD|TAIL|Hello", res.body.strip
  end
end

class TestUploads < TepTest
  include UploadsTests
  app_source "require 'sinatra'\n" + UploadsTests::APP
end

class TestUploadsScheduled < TepTest
  include UploadsTests
  app_source "require 'sinatra'\nset :scheduler, :scheduled\n" + UploadsTests::APP
end
