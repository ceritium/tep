# Tep::Multipart -- text-field parsing for multipart/form-data bodies.
#
# Browser forms submitted via `new FormData(form)` (or any form
# carrying file inputs) use `Content-Type: multipart/form-data`
# instead of urlencoded. tep's request layer treats those bodies
# as String fields here. File-upload parts (any part with a
# `filename=` header) don't land in `req.params`: parse_files
# returns them as Tep::UploadedFile, reached as `req.files`.
#
# Public API mirrors SpinelKit::Url.parse_query: pass the raw body + the
# request's Content-Type header value; get back a string-keyed
# string-valued hash, ready to merge into `req.params`.
module Tep
  module Multipart
    # Parse `body` against the boundary embedded in `content_type`.
    # Returns an empty hash when the boundary can't be extracted
    # (defensive: caller already checked `req.multipart?`).
    def self.parse(body, content_type)
      h = Tep.str_hash
      bnd = Tep::Multipart.extract_boundary(content_type)
      if bnd.length == 0
        return h
      end
      delim = "--" + bnd
      parts = body.split(delim)
      i = 1   # parts[0] is the prologue before the first delimiter
      while i < parts.length
        part = parts[i]
        # Terminator: a part that starts with "--" is the closing
        # boundary "--<bnd>--<crlf>"; nothing meaningful after it.
        if part.length >= 2 && part[0, 2] == "--"
          return h
        end
        # Strip the CRLF that follows every interior delimiter.
        if part.length >= 2 && part[0, 2] == "\r\n"
          part = part[2, part.length - 2]
        end
        # Strip the CRLF that precedes the next delimiter (every
        # interior part ends with \r\n before the next "--<bnd>").
        if part.length >= 2 && part[part.length - 2, 2] == "\r\n"
          part = part[0, part.length - 2]
        end
        sep = Tep.str_find(part, "\r\n\r\n", 0)
        if sep >= 0
          headers = part[0, sep]
          value   = part[sep + 4, part.length - sep - 4]
          name = Tep::Multipart.extract_field_name(headers)
          has_filename = Tep.str_find(headers, "filename=", 0) >= 0
          if name.length > 0 && !has_filename
            h[name] = value
          end
        end
        i += 1
      end
      h
    end

    # The file parts of `body` (those with a `filename=`), by field name.
    def self.parse_files(body, content_type)
      files = { "" => Tep::UploadedFile.new("", "", "") }
      files.delete("")
      bnd = Tep::Multipart.extract_boundary(content_type)
      if bnd.length == 0
        return files
      end
      parts = body.split("--" + bnd)
      i = 1
      while i < parts.length
        part = parts[i]
        if part.length >= 2 && part[0, 2] == "--"
          return files
        end
        if part.length >= 2 && part[0, 2] == "\r\n"
          part = part[2, part.length - 2]
        end
        if part.length >= 2 && part[part.length - 2, 2] == "\r\n"
          part = part[0, part.length - 2]
        end
        sep = Tep.str_find(part, "\r\n\r\n", 0)
        if sep >= 0
          headers = part[0, sep]
          name = Tep::Multipart.extract_field_name(headers)
          if name.length > 0 && Tep.str_find(headers, "filename=", 0) >= 0
            files[name] = Tep::UploadedFile.new(Tep::Multipart.extract_quoted(headers, "filename=\""),
                                                Tep::Multipart.extract_part_type(headers),
                                                part[sep + 4, part.length - sep - 4])
          end
        end
        i += 1
      end
      files
    end

    # The value of `key"..."` in a part's headers, "" when absent.
    def self.extract_quoted(headers, key)
      at = Tep.str_find(headers, key, 0)
      if at < 0
        return ""
      end
      start = at + key.length
      end_q = Tep.str_find(headers, "\"", start)
      if end_q < 0
        return ""
      end
      headers[start, end_q - start]
    end

    # A part's own Content-Type, "application/octet-stream" when absent.
    def self.extract_part_type(headers)
      lower = headers.downcase
      at = Tep.str_find(lower, "content-type:", 0)
      if at < 0
        return "application/octet-stream"
      end
      start = at + 13
      stop = Tep.str_find(headers, "\r\n", start)
      if stop < 0
        stop = headers.length
      end
      headers[start, stop - start].strip
    end

    # Extract `boundary=...` from a Content-Type value. Handles
    # quoted (`boundary="x"`) and unquoted (`boundary=x;` or
    # `boundary=x` at end of string).
    def self.extract_boundary(content_type)
      at = Tep.str_find(content_type, "boundary=", 0)
      if at < 0
        return ""
      end
      rest = content_type[at + 9, content_type.length - at - 9]
      if rest.length > 0 && rest[0, 1] == "\""
        end_q = Tep.str_find(rest, "\"", 1)
        if end_q < 0
          return ""
        end
        return rest[1, end_q - 1]
      end
      semi = Tep.str_find(rest, ";", 0)
      if semi >= 0
        return rest[0, semi]
      end
      rest
    end

    # Extract the `name="..."` value from a part's headers blob.
    # Returns "" when no name found.
    def self.extract_field_name(headers)
      at = Tep.str_find(headers, "name=\"", 0)
      if at < 0
        return ""
      end
      start = at + 6
      end_q = Tep.str_find(headers, "\"", start)
      if end_q < 0
        return ""
      end
      headers[start, end_q - start]
    end
  end
end
