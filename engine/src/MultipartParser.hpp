#ifndef MULTIPART_PARSER_HPP
#define MULTIPART_PARSER_HPP


#include "HTTPServer.hpp"


class MultipartInputStream
{
public:
    MultipartInputStream(HTTPServer::Request *request,
                         size_t content_length);
    
public:
    bool read_line (std::string *line);
    bool read_data (char **data, int *data_len);
    void rewind_buffer (int n);


protected:
    HTTPServer::Request *m_request;
    size_t m_content_length;
    size_t m_bytes_read;
};


class MultipartParser
{
public:
    typedef std::list<std::string> HeaderList;
    typedef std::vector<std::string> StringVector;

    class PartInfo
    {
    public:
        PartInfo();
        PartInfo(const PartInfo& part_info);
        PartInfo& operator=(const PartInfo& part_info);
    public:
        void dump() const;
    public:
        std::string disposition;
        std::string name;
        std::string filename;
        std::string origname;
        void *user_data;
    };

    typedef bool (*ProcessPartCallback)(const PartInfo& part_info, char *data, size_t data_len);

public:
    MultipartParser(HTTPServer::Request *request);
    ~MultipartParser();

public:
    bool parse_init();
    bool begin_next_part (bool *more_parts_remain, PartInfo *part_info);
    bool process_part (const PartInfo& part_info, ProcessPartCallback callback);

protected:
    bool read_part_headers (HeaderList *headers);
    bool extract_disposition_info (const std::string& header_line, PartInfo *part_info);
    std::string extract_boundary (const std::string& type_header);
    std::string extract_content_type (const std::string& header_line, const std::string& default_content_type);

protected:
    HTTPServer::Request *m_request;
    size_t m_max_size;

    size_t m_content_length;
    std::string m_boundary;

    MultipartInputStream *m_input;
};



void xsnap (const char *header, const char *data, size_t data_len, int width, int offset);
void xsnap (const char *header, const unsigned char *data, size_t data_len, int width, int offset);



#endif

