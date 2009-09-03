# Abstract class providing an interface to the SIFT matching database.

class ImageDB

  def ImageDB.set_database(db_path_or_url)
    @@default_db = db_path_or_url
  end

  def initialize(db=nil)
    if db
      @db = db
    else
      begin
        @db = @@default_db
      rescue NameError
        raise "The default image database has not been set."
      end
    end
  end


  def add_image(image_path, label)
    raise NotImplementedError
  end

  def match_image(image_path)
    raise NotImplementedError
  end

  def list
    raise NotImplementedError
  end
  
  def remove_image(image_label)
    raise NotImplementedError
  end
  
end


class ImageMatchResult
  attr_reader :label, :score, :percentage

  def initialize(label, score, percentage)
    @label, @score, @percentage = label, score, percentage
  end

  def to_s
    return "<ImageMatchResult #{@label} #{@score} #{@percentage}%>"
  end
end

class ImageDBEntry
  attr_reader :label, :num_features

  def initialize(label, num_features)
    @label, @num_features = label, num_features
  end

  def to_s
    return "<ImageDBEntry #{@label} #{@num_features}>"
  end
end
