# A file part of a multipart/form-data body, read whole into memory.
# Reached as `request.files["avatar"]`; params stay String-valued.
module Tep
  class UploadedFile
    def initialize(filename, type, contents)
      @upload_filename = filename
      @upload_type = type
      @upload_contents = contents
    end

    def filename; @upload_filename; end
    # The part's Content-Type, as Rack calls it.
    def type; @upload_type; end
    def read; @upload_contents; end
    def size; @upload_contents.bytesize; end
  end
end
