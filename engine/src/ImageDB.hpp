#ifndef __IMAGE_DB_H__
#define __IMAGE_DB_H__

extern "C" {
#include <highgui.h>
}

#include <list>
#include <vector>
#include <map>
#include <string>


struct MatchResult
{
    std::string label;
    float score;
    float percentage;

    MatchResult(const std::string& label, float score, float percentage);
    MatchResult(const MatchResult&);
    MatchResult& operator=(const MatchResult&);
    bool operator==(const MatchResult&) const;
};

typedef std::map<std::string,MatchResult> MatchResults;

struct FeatureInfo
{
    struct feature *features;
    int num_features;
    unsigned long id;
};

typedef std::vector<FeatureInfo> FeatureInfoVector;

/*
  Holds the features for all the images in the candidate set.
 */
class ImageDB
{
  public:
    ImageDB();
    ~ImageDB();

    unsigned long num_images();
    bool add_image(IplImage *image, const std::string& label);
    bool add_image_features(struct feature *features, int n, const std::string& label);
    bool add_image_file(const std::string& path, const std::string& label);
    bool remove_image(const std::string& label);
    MatchResults match(struct feature* features, int n, int max_nn_chks=200, double max_dist=50000.0);
    MatchResults exhaustive_match(struct feature* features, int n, int max_nn_chks=200, double dist_sq_ratio=0.49);
    std::list<std::string> all_labels();
    const FeatureInfo* get_image_info(const std::string& label);

    bool save(const char *path, bool binary=true);
    bool save(bool binary=true);
    bool load(const char *path, bool binary=true);

    void coalesce();

  protected:
    const std::string& label_for_id(unsigned long id);
    bool id_for_label(const std::string& label, int *id);
    const std::string& feature_label(const struct feature *feature);
    bool label_exists(const std::string& label);
  protected:
    FeatureInfoVector m_uncoalesced_features;
    
    struct feature *m_coalesced_features;
    struct kd_node *m_kd_tree;
    bool m_need_to_coalesce;
    std::string m_filename;

    unsigned long m_id_counter;
    std::map<unsigned long, std::string> m_labels;
};


#endif
