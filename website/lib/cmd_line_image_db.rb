# Provides a Ruby interface to the SIFT matching database via the
# command line tools.

require 'image_db'


SIFT_BIN="/www/sites/imagewiki/sift/bin/"

class CommandLineImageDB < ImageDB

  def add_image(image_path, image_label)
    output = %x[#{SIFT_BIN}db-add #{@db} #{image_path} #{image_label} 2>&1]
    if $?.to_i != 0
      raise "Unable to add image '#{image_path}' with label '#{image_label}': '#{output}'"
    end
  end

  def match_image(image_path)
    output = %x[#{SIFT_BIN}db-match #{@db} #{image_path} 2>&1]
    if $?.to_i != 0
      raise "Unable to match with image '#{image_path}': #{output}"
    end
    results = []
    output.each do |s|
      match = s.split(": ")
      id = match[0].split("/").last.to_i # TODO FIX THIS BADNESS
      score = match[1]
      result = ImageMatchResult.new(id, score)
      results.push(result)
    end
    return results
  end
  
  def remove_image(image_label)
    output = %x[#{SIFT_BIN}db-remove #{@db} #{image_label} 2>&1]
    if $?.to_i != 0
      raise "Unable to remove image with label '#{image_label}': #{output}"
    end
  end

end
