#include <stdlib.h>
#include <iostream>
#include <errno.h>

#include "ImageDB.hpp"

extern "C" {
#include "imgfeatures.h"
#include "kdtree.h"
#include "sift.h"

#include <cxcore.h>
#include <cv.h>
#include <highgui.h>
}



MatchResult::MatchResult(const std::string& l, float s, float p)
    : label(l), score(s), percentage(p)
{
}

MatchResult::MatchResult(const MatchResult& result)
    : label(result.label), score(result.score), percentage(result.percentage)
{
}

MatchResult& MatchResult::operator=(const MatchResult& result)
{
    if (this != &result) {
        label = result.label;
        score = result.score;
        percentage = result.percentage;
    }
    return *this;
}

bool MatchResult::operator==(const MatchResult& result) const
{
    return label == result.label
        && score == result.score
        && percentage == result.percentage;
}


ImageDB::ImageDB()
: m_coalesced_features(NULL), m_kd_tree(NULL),
  m_need_to_coalesce(true), m_id_counter(0), m_filename("")
{
}

ImageDB::~ImageDB()
{
}

/*
  Extracts features from an image and adds them to the db, indexed by ID.
*/
bool ImageDB::add_image_file(const std::string& path, const std::string& label)
{
    IplImage *image = cvLoadImage(path.c_str(), 1);
    if (!image) {
        std::cerr << "Error loading image '" << path << "': " << strerror(errno) << "\n";
        return false;
    }
    bool result = add_image(image, label);
    cvReleaseImage(&image);
    return result;
}

bool ImageDB::label_exists(const std::string& label)
{
    for (std::map<unsigned long,std::string>::iterator i = m_labels.begin();
         i != m_labels.end();
         i++) {
        if (i->second == label) {
            return true;
        }
    }
    return false;
}

bool ImageDB::id_for_label(const std::string& label, int *id)
{
    bool found_label = false;
    for (std::map<unsigned long,std::string>::iterator i = m_labels.begin();
         i != m_labels.end();
         i++) {
        if (i->second == label) {
            *id = i->first;
            found_label = true;
            break;
        }
    }
    return found_label;
}

const FeatureInfo* ImageDB::get_image_info(const std::string& label)
{
    int id;
    if (!id_for_label(label, &id)) {
        return NULL;
    }
    
    for (FeatureInfoVector::const_iterator i = m_uncoalesced_features.begin();
         i != m_uncoalesced_features.end();
         i++) {
        if (i->id == id) {
            return &(*i);
        }
    }
    return NULL;
}

bool ImageDB::add_image(IplImage *image, const std::string& label)
{
    int i;
    struct feature *features;
    int num_features;

    num_features = sift_features(image, &features);
    return add_image_features(features, num_features, label);
}

/*
  Extracts features from an image and adds them to the db, indexed by ID.
*/
bool ImageDB::add_image_features(struct feature *features, int n, const std::string& label)
{
    if (label_exists(label)) {
        return false;
    }

    int i;
    unsigned long id = m_id_counter++;

    m_labels[id] = label;
    FeatureInfo f;
    f.num_features = n;
    f.features = features;
    f.id = id;
    for (i = 0; i < f.num_features; i++) {
        f.features[i].feature_data = (void*) id;
    }

    m_uncoalesced_features.push_back(f);
    m_need_to_coalesce = true;
    return true;
}

void ImageDB::coalesce()
{
    if (!m_need_to_coalesce) {
        return;
    }

    int total_num_features = 0;

    for (FeatureInfoVector::const_iterator i = m_uncoalesced_features.begin();
         i != m_uncoalesced_features.end();
         i++) {
        total_num_features += i->num_features;
    }

    m_coalesced_features = new struct feature[total_num_features];
    int k = 0;
    for (FeatureInfoVector::const_iterator i = m_uncoalesced_features.begin();
         i != m_uncoalesced_features.end();
         i++) {
        for (int j = 0; j < i->num_features; j++) {
            m_coalesced_features[k++] = i->features[j];
        }
    }
     
    m_kd_tree = kdtree_build(m_coalesced_features, total_num_features);
    m_need_to_coalesce = false;
}

const std::string& ImageDB::label_for_id(unsigned long id)
{
    return m_labels[id];
}

const std::string& ImageDB::feature_label(const struct feature *feature)
{
    return label_for_id((unsigned long)feature->feature_data);
}


MatchResults ImageDB::exhaustive_match(struct feature *features, int n, int max_nn_chks, double dist_sq_ratio)
{
    struct feature **neighbors;
    int k;
    MatchResults results;
    struct kd_node *kd_tree;

    for (FeatureInfoVector::const_iterator i = m_uncoalesced_features.begin();
         i != m_uncoalesced_features.end();
         i++) {
        int num_matches = 0;
        kd_tree = kdtree_build(i->features, i->num_features);
        for (int j = 0; j < n; j++) {
            k = kdtree_bbf_knn(kd_tree, features + j, 2, &neighbors, max_nn_chks);
            if (k == 2) {
                double d0 = descr_dist_sq( features + j, neighbors[0] );
                double d1 = descr_dist_sq( features + j, neighbors[1] );
                if (d0 < d1 * dist_sq_ratio) {
                    num_matches++;
                }
            }
            free(neighbors);
        }
        kdtree_release(kd_tree);
        if (num_matches > 0) {
            results.insert(MatchResults::value_type(m_labels[i->id],
                                                    MatchResult(m_labels[i->id], num_matches,
                                                                (100.0 * num_matches) / n)));
        }
    }
    return results;
}

MatchResults ImageDB::match(struct feature *features, int n, int max_nn_chks, double max_dist)
{
    coalesce();

    struct feature* feat;
    struct feature** nbrs;
    int i, k;
    MatchResults results;

    /* For each feature in the test set, find the nearest feature in the
       candidate set.  The image associated with that feature gets 1.0 added
       to its score. */
    for (i = 0; i < n; i++) {
        feat = features + i;
        k = kdtree_bbf_knn(m_kd_tree, feat, 2, &nbrs, max_nn_chks);
        if (k > 0) {
            if (max_dist <= 0.0 || descr_dist_sq(feat, nbrs[0]) < max_dist) {
                std::string l = feature_label(nbrs[0]);
                MatchResults::iterator r = results.find(l);
                if (r == results.end()) {
                    results.insert(MatchResults::value_type(l, MatchResult(l, 1.0, 0.0)));
                } else {
                    r->second.score += 1.0;
                }
            
                if (k > 1) {
                    if (max_dist <= 0.0 || descr_dist_sq(feat, nbrs[1]) < max_dist) {
                        std::string l = feature_label(nbrs[1]);
                        r = results.find(l);
                        if (r == results.end()) {
                            results.insert(MatchResults::value_type(l, MatchResult(l, 0.2, 0.0)));
                        } else {
                            r->second.score += 0.2;
                        }
                    }
                }
            }
        }
    }

    // Now go through and computer the percentages.
    for (MatchResults::iterator i = results.begin();
         i != results.end();
         i++) {
        i->second.percentage = 100.0 * i->second.score / n;
    }
    return results;
}


bool ImageDB::remove_image(const std::string& label)
{
    unsigned long id;
    bool found_label = false;
    for (std::map<unsigned long,std::string>::iterator i = m_labels.begin();
         i != m_labels.end();
         i++) {
        if (i->second == label) {
            id = i->first;
            found_label = true;
            m_labels.erase(i);
            break;
        }
    }
    if (found_label) {
        for (FeatureInfoVector::iterator i = m_uncoalesced_features.begin();
             i != m_uncoalesced_features.end();
             i++) {
            if (i->id == id) {
                free(i->features);
                m_uncoalesced_features.erase(i);
                m_need_to_coalesce = true;
                break;
            }
        }
    }
    return found_label;
}

std::list<std::string> ImageDB::all_labels()
{
    std::list<std::string> labels;
    for (std::map<unsigned long,std::string>::iterator i = m_labels.begin();
         i != m_labels.end();
         i++) {
        labels.push_back(i->second);
    }
    return labels;
}

unsigned long ImageDB::num_images()
{
    return m_labels.size();
}


bool ImageDB::save(bool binary)
{
  if (m_filename == std::string("")) {
    return false;
  }
  return save(m_filename.c_str(), binary);
}

bool ImageDB::save(const char* path, bool binary)
{
    FILE* file;

    if (!(file = fopen(path, "w" ))) {
        fprintf( stderr, "Warning: error opening %s, %s, line %d\n",
                 path, __FILE__, __LINE__ );
        return false;
    }

    fprintf(file, "%d\n", num_images());
    for (std::map<unsigned long,std::string>::const_iterator i = m_labels.begin();
         i != m_labels.end();
         i++) {
        fprintf(file, "%d\n%s\n", i->first, i->second.c_str());
    }

    for (FeatureInfoVector::const_iterator i = m_uncoalesced_features.begin();
         i != m_uncoalesced_features.end();
         i++) {
        int result;
        if (binary) {
            result = export_features_binary_f(file, i->features, i->num_features);
        } else {
            result = export_features_text_f(file, i->features, i->num_features);
        }
        if (result != 0) {
            return false;
        }
    }
    if (fclose(file)) {
        perror("Error saving database: close:");
        return false;
    } else {
        return true;
    }
}

bool ImageDB::load(const char* path, bool binary)
{
    FILE *file;
    int i;

    if (!(file = fopen(path, "r" ))) {
        fprintf(stderr, "Error opening '%s': %s\n", path, strerror(errno));
        return false;
    }

    unsigned long max_id = 0;
    int num_images;
    
    /* Read number of images. */
    if (fscanf(file, " %u ", &num_images) != 1) {
        perror("File read error: num_images");
        return false;
    }

    for (i = 0; i < num_images; i++) {
        int id;
        char label[4096];
        
        // Read ID.
        if (fscanf(file, " %u ", &id) != 1) {
            perror("File read error: id");
            return false;
        }
        // Read label.
        if (!fgets(label, sizeof label, file)) {
            perror("File read error: label");
            return false;
        }
        // Trim newline.
        label[strlen(label) - 1] = '\0';
        m_labels[id] = std::string(label);

        if (id > max_id) {
            max_id = id;
        }
    }

    for (int i = 0; i < num_images; i++) {
        struct feature *features;
        int n;
        if (binary) {
            n = import_features_binary_f(file, FEATURE_LOWE, &features);
        } else {
            n = import_features_text_f(file, FEATURE_LOWE, &features);
        }
        if (n < 0) return false;

        FeatureInfo f;
        f.num_features = n;
        f.features = features;
        f.id = (unsigned long) f.features[0].feature_data;
        m_uncoalesced_features.push_back(f);
    }

    fclose(file);
    m_filename = std::string(path);
    m_id_counter = max_id + 1;
    m_need_to_coalesce = true;
    return true;
}

