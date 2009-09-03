#include "MultipartParser.hpp"

#include "abyss_session.h"
#include "abyss_conn.h"

#include <cctype>
#include <string.h>
#include <iostream>

#include <assert.h>


MultipartParser::MultipartParser (HTTPServer::Request *request)
    : m_request(request), m_max_size(0), m_input(NULL)
{
}

MultipartParser::~MultipartParser ()
{
    if (m_input) {
        delete m_input;
    }
}

bool
MultipartParser::parse_init ()
{
    // Ensure this is really multipart/form-data.
    const char *content_type_h = HTTPServer::get_header_value(m_request, "content-type");
    if (content_type_h == NULL || strcasestr(content_type_h, "multipart/form-data") != content_type_h) {
        std::cerr << "Posted content type is not multipart/form-data\n";
        return false;
    }

    // Get the content length and make sure it's acceptable.
    const char *content_length_h = HTTPServer::get_header_value(m_request, "content-length");
    if (content_length_h == NULL) {
        std::cerr << "WARNING: Content length missing.\n";
        return false;
    }

    size_t content_length = strtoul(content_length_h, NULL, 10);
    if (m_max_size > 0 && content_length > m_max_size) {
        std::cerr << "WARNING: Posted content length of " << content_length_h << " exceeds limit of " << m_max_size << "\n";
        return false;
    } else {
        std::cerr << "Content-length: " << content_length << "\n";
    }

    m_input = new MultipartInputStream(m_request, content_length);
    
    // Get the boundary string, which should look something like
    // "------woOowoOOWO".
    std::string boundary = extract_boundary(content_type_h);
    if (boundary == "") {
        std::cerr << "WARNING: multipart/form-data boundary was not specified.\n";
        return false;
    }

    m_content_length = content_length;
    m_boundary = boundary;

    // Read until we hit a boundary.
    do {
        std::string line;
        if (!m_input->read_line(&line)) {
            std::cerr << "ERROR: Corrupt form data; premature ending.\n";
            return false;
        }
        if (line.find(m_boundary) == 0) {
            // Found it.
            break;
        }
    }
    while (true);

    return true;
}


void
dump_sub_headers (const MultipartParser::HeaderList& headers)
{
    for (MultipartParser::HeaderList::const_iterator i = headers.begin(); i != headers.end(); i++) {
        std::cerr << "SUBHDR " << *i << "\n";
    }
}

bool
MultipartParser::read_part_headers (HeaderList *headers)
{
    // std::cerr << "Reading part headers\n";
    std::string line;
    if (!m_input->read_line(&line)) {
        // No parts left, we're done.
        return false;
    }
//    xsnap("FIRST SUB HEADER", (const unsigned char*) line.data(), line.size(), 120);

    if (line.length() == 0) {
        // IE4 on Mac might send an empty line at the end.
        return false;
    }
    
    bool got_line = true;
    while (got_line && line.length() > 0) {
        std::string next_line;
        bool get_next_line = true;
        while (get_next_line) {
            got_line = m_input->read_line(&next_line);
            if (got_line && (next_line.find(" ") == 0 || next_line.find("\t") == 0)) {
                line = line + next_line;
            } else {
                get_next_line = false;
            }
        }

        // Add the line to the header list.
        headers->push_back(line);
        line = next_line;
    }

    
    dump_sub_headers(*headers);


    if (!got_line) {
        return false;
    } else {
        return true;
    }
}


bool
MultipartParser::begin_next_part (bool *more_parts_remain, PartInfo *part_info)
{
    // Read the headers; they look like this (not all may be present):
    // 
    // Content-Disposition: form-data; name="field1"; filename="file1.txt"
    // Content-Type: type/subtype
    // Content-Transfer-Encoding: binary

    *more_parts_remain = false;

    // Read the part headers;
    HeaderList headers;
    if (!read_part_headers(&headers)) {
        return true;
    }
    
    std::string name;
    std::string filename;
    std::string origname;
    std::string content_type("text/plain");
    
    for (HeaderList::const_iterator i = headers.begin(); i != headers.end(); i++) {
        std::string header_line(*i);
        std::transform(header_line.begin(), header_line.end(), header_line.begin(), tolower);

        std::cerr << "** HEADER: " << header_line << "\n";
        if (header_line.find("content-disposition:") == 0) {
            // Parse the content-disposition line.
            if (!extract_disposition_info(header_line, part_info)) {
                return false;
            }
        }
        else if (header_line.find("content-type:") == 0) {
            content_type = extract_content_type(header_line, content_type);
        }
    }

    *more_parts_remain = true;
    return true;
}

const char* my_memmem(const char *s1, int l1, const char *s2, int l2)
{
    if (!l2) return s1;
    while (l1 >= l2) {
        l1--;
        if (!memcmp(s1,s2,l2))
            return s1;
        s1++;
    }
    return NULL;
}

bool
MultipartParser::process_part (const PartInfo& part_info, ProcessPartCallback callback)
{
    bool keep_reading = true;
    char *data;
    int data_len;

    std::string delimiter = std::string(CRLF) + m_boundary;
    
    // std::cerr << "delimiter: '" << delimiter << "\n";
    int raw_buffer_size = 8192;
    char raw_buffer[raw_buffer_size];
    char *buffer = raw_buffer + delimiter.size();

    char *buffer_to_process = buffer;
    memset(raw_buffer, 0xff, delimiter.size());

    int bytes_processed = 0;

    while (keep_reading)
    {
        //std::cerr << "Reading part data.\n";
        if (!m_input->read_data(&data, &data_len)) {
            std::cerr << "Failed to read part data, finishing processing.\n";
            return false;
        }
        // std::cerr << "Read " << data_len << " bytes.\n";
        memcpy(buffer, data, data_len);
        char *last_buffer_bytes = buffer + data_len - delimiter.size();

        // look for the boundary.
        char *boundary_ptr = (char *) my_memmem(buffer, data_len, delimiter.data(), delimiter.size());
        if (!boundary_ptr)
        {
            // std::cerr << "Did not find boundary.\n";

            // Process data.
            if (!((*callback)(part_info, buffer_to_process, (data_len - (buffer_to_process - raw_buffer))))) {
                std::cerr << "Mutipart callback returned error indication.\n";
                return false;
            }

            bytes_processed += (data_len - (buffer_to_process - raw_buffer));
            // Copy last N bytes of buffer to beginning for
            // cross-buffer boundary detection.
            memcpy(raw_buffer, last_buffer_bytes, delimiter.size());
        }
        else
        {
            // std::cerr << "Found boundary: " << boundary_ptr - buffer_to_process << " buffer: " << buffer - raw_buffer << "\n";
            // Process last few bytes.
            (*callback)(part_info, buffer_to_process, (boundary_ptr - buffer_to_process));
            bytes_processed += (boundary_ptr - buffer_to_process);
            // Rewind the stream to the end of the delimiter.
            m_input->rewind_buffer(data_len - (boundary_ptr - buffer) - m_boundary.size() - 2);
            keep_reading = false;
        }
        if (data_len == 0) {
            std::cerr << "zero byte read--peer closed connection?\n";
            keep_reading = false;
        }
        buffer_to_process = raw_buffer;
    }

    {
        std::string line;
        m_input->read_line(&line);
        if (line == std::string("--"))
        {
            // std::cerr << "Looks like we've hit the end of the data.";
        }

        assert(line.size() == 0 || line == std::string("--"));
    }

    // std::cerr << "Returning from process_part.\n";

    return true;
}



std::string
MultipartParser::extract_content_type (const std::string& header_line, const std::string& default_content_type)
{
    return default_content_type;
}


template <typename T> T max(T a, T b)
{
    if (a > b) {
        return a;
    } else {
        return b;
    }
}

bool
MultipartParser::extract_disposition_info (const std::string& header_line, PartInfo *part_info)
{
    // Convert the line to a lowercase string without the ending \r\n
    // Keep the original line for error messages and for variable names.
    std::string line(header_line);
    std::transform(line.begin(), line.end(), line.begin(), tolower);
    // Get the content disposition, should be "form-data"
    std::string::size_type start = line.find("content-disposition: ");
    std::string::size_type end = line.find(";");
    if (start == std::string::npos || end == std::string::npos) {
        std::cerr << "Content disposition corrupt: '" << header_line << "'\n";
        return false;
    }
    std::string disposition(line.substr(start + 21, (end - (start + 21))));
    if (disposition != "form-data") {
        std::cerr << "Invalid content disposition: '" << disposition << "'\n";
        return false;
    }
    
    // Get the field name
    start = line.find("name=\"", end);  // start at last semicolon
    end = line.find("\"", start + 7);   // skip name=\"
    int start_offset = 6;
    if (start == std::string::npos || end == std::string::npos)
    {
      // Some browsers like lynx don't surround with ""
      // Thanks to Deon van der Merwe, dvdm@truteq.co.za, for noticing
      start = line.find("name=", end);
      end = line.find(";", start + 6);
      if (start == std::string::npos) {
          std::cerr << "Content disposition corrupt: '" << header_line << "'\n";
          return false;
      } else if (end == std::string::npos) {
        end = line.length();
      }
      start_offset = 5;  // without quotes we have one fewer char to skip
    }
    std::string name(header_line.substr(start + start_offset, (end - (start + start_offset))));

    // Get the filename, if given
    std::string filename("");
    std::string origname("");
    start = line.find("filename=\"", end + 2);  // start after name
    end = line.find("\"", start + 10);          // skip filename=\"
    if (start != std::string::npos && end != std::string::npos)  // note the !=
    {
        filename = header_line.substr(start + 10, (end - (start + 10)));
        origname = filename;
        // The filename may contain a full path.  Cut to just the filename.
        std::string::size_type slash = max(filename.rfind('/'), filename.rfind('\\'));
        if (slash != std::string::npos)
        {
            filename = filename.substr(slash + 1);  // past last slash
        }
    }

    part_info->disposition = disposition;
    part_info->name = name;
    part_info->filename = filename;
    part_info->origname = origname;

    return true;
}


std::string
MultipartParser::extract_boundary (const std::string& type_header)
{
    
    std::string::size_type index = type_header.rfind("boundary=");
    if (index == std::string::npos)
    {
        return "";
    }
    std::string boundary = type_header.substr(index + 9);
    if (boundary[0] == '"')
    {
        // boundary is enclosed in quotes, strip them.
        index = boundary.rfind('"');
        boundary = boundary.substr(1, index - 1);
    }
    
    // The real boundary is always preceded by an extra "--"
    boundary = "--" + boundary;
    return boundary;
}



MultipartParser::PartInfo::PartInfo ()
    : disposition(""), name(""), filename(""), origname(""), user_data(NULL)
{
}

MultipartParser::PartInfo::PartInfo (const PartInfo& part_info)
    : disposition(part_info.disposition), name(part_info.name), filename(part_info.filename), origname(part_info.filename),
      user_data(part_info.user_data)
{
}

MultipartParser::PartInfo&
MultipartParser::PartInfo::operator= (const PartInfo& part_info)
{
    if (&part_info != this)
    {
        disposition = part_info.disposition;
        name = part_info.name;
        filename = part_info.filename;
        origname = part_info.origname;
        user_data = part_info.user_data;
    }
    return *this;
}

void MultipartParser::PartInfo::dump() const
{
    std::cerr << "PART\n";
    std::cerr << "  disposition: " << disposition << "\n";
    std::cerr << "  name: " << name << "\n";
    std::cerr << "  filename: " << filename << "\n";
    std::cerr << "  origname: " << origname << "\n";
}


MultipartInputStream::MultipartInputStream(HTTPServer::Request *request,
                                           size_t content_length)
    : m_request(request), m_content_length(content_length), m_bytes_read(0)
{
}


bool
MultipartInputStream::read_line (std::string *line)
{
    bool success = true;
    char *data;
    int data_len;
    bool ends_with_CR = false;
    char *CRLF_pos;

//    char CR = 13;
//    char LF = 10;
//    const char *CRLF = {CR, LF, '\0'};

    success = read_data(&data, &data_len);
    *line = "";
    bool got_line = false;

    while (success && data_len > 0 && !got_line)
    {
        if (ends_with_CR)
        {
            if (data[0] == LF)
            {
                std::cerr << "First character finishes CRLF.\n";
                rewind_buffer(data_len - 1);
                got_line = true;
            }
            else
            {
                std::cerr << "Cancelling ends_with_CR\n"; 
                line->append(1, CR);
                ends_with_CR = false;
            }
        }
        if (data[data_len - 1] == CR)
        {
            std::cerr << "Buffer ends with CR\n";
            ends_with_CR = true;
            line->append(data, data_len - 1);
        }
                
        CRLF_pos = (char *) my_memmem(data, data_len, CRLF, 2);
        if (CRLF_pos)
        {
            int line_len = CRLF_pos - data;
            // std::cerr << "Got EOL at position " << line_len << " of " <<  data_len << "\n";
            line->append(data, line_len);
            rewind_buffer(data_len - line_len - 2);
            got_line = true;
        }
        else
        {
            // std::cerr << "Appending " << data_len << " bytes to line\n";
            line->append(data, data_len);
        }
        if (!got_line)
        {
            success = read_data(&data, &data_len);
        }
    }

    // std::cerr << "Returning a fresh hot line of length " << line->size() << ": '" << line << "'\n";
    return success;
}

void
MultipartInputStream::rewind_buffer (int n)
{
    assert (m_request->conn->bufferpos - n >= 0);
    assert (m_bytes_read - n >= 0);

    // std::cerr << "Rewinding buffer " << n << " bytes, to " << m_request->conn->bufferpos - n << "\n";
    m_request->conn->bufferpos -= n;
    m_bytes_read -= n;
}

bool
MultipartInputStream::read_data (char **out_start, int *out_len)
{
    //std::cerr << "bytes_read: " << m_bytes_read
    //          << ", content-length: " << m_content_length << "\n";
    bool success = true;
    if (m_bytes_read >= m_content_length)
    {
        return false;
    }
    if (m_request->conn->bufferpos >= m_request->conn->buffersize)
    {
        success = HTTPServer::refill_buffer_from_connection(m_request);
    }
    if (success)
    {
        int max = m_content_length - m_bytes_read;
        HTTPServer::get_buffer_data(m_request, max, out_start, out_len);
        m_bytes_read += *out_len;
    }
    return success;
}



void
xsnap (const char *header, const char *data, size_t data_len, int width, int offset)
{
    xsnap(header, (const unsigned char*) data, data_len, width, offset);
}



void
xsnap (const char *header, const unsigned char *data, size_t data_len, int width, int offset)
{
    fprintf(stderr,"%s\n", header);

    size_t len_to_show = data_len;
    int bytes_per_row = (width - 10) / 4;
    
    for (size_t line_start = 0; line_start < len_to_show; line_start += bytes_per_row)
    {
        fprintf(stderr, "%06x ", offset + line_start);
        for (size_t p = line_start; p < line_start + bytes_per_row; p++)
        {
            if (p < data_len)
            {
                fprintf(stderr, "%02x ", data[p]);
            }
            else
            {
                fprintf(stderr, "   ");
            }
        }
        
        for (size_t p = line_start; p < line_start + bytes_per_row; p++)
        {
            if (p < data_len)
            {
                if (isprint(data[p]))
                    fprintf(stderr, "%c", data[p]);
                else
                    fprintf(stderr, ".");
            }
            else
            {
                break;
            }
        }
        fprintf(stderr, "\n");
    }
}
