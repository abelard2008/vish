# encoding: utf-8

namespace :fix do

  #Usage
  #Development:   bundle exec rake fix:pictures
  #In production: bundle exec rake fix:pictures RAILS_ENV=production
  task :pictures => :environment do

    printTitle("Fixing pictures")

    #Get all excursions
    excursions = Excursion.all
    excursions.each do |excursion|
      begin
        jsonChange = false
        eJson = JSON(excursion.json)
        eJson["slides"].each do |slide|
          sElements = slide["elements"]
          if sElements != nil
            sElements.each do |el|
              if el["type"]=="image" and el["body"].class == String
                imgPath = el["body"]
                if _isWrongImagePath(imgPath)
                  # puts imgPath
                  #Fix it
                  el["body"] = Vish::Application.config.full_domain + imgPath
                  # puts "Fix image, new URL:"
                  # puts el["body"]
                  jsonChange = true
                end
              end
            end
          end
        end
      if jsonChange
        puts "Excursion ID"
        puts excursion.id
        #excursion.update_column :json, eJson.to_json;
      end
      rescue Exception => e
        puts "Exception with excursion id:"
        puts excursion.id.to_s
        puts "Exception message"
        puts e.message
      end
    end

    printTitle("Task Finished")
  end

  def _isWrongImagePath(imagePath)
    return (!imagePath.nil? and imagePath.include?("/pictures/") and !imagePath.include?("vishub") and !imagePath.include?("http://") and !imagePath.include?("https://"))
  end


  #Usage
  #Development:   bundle exec rake fix:resetScormTimestamp
  #In production: bundle exec rake fix:resetScormTimestamp RAILS_ENV=production
  task :resetScormTimestamp => :environment do

    printTitle("Reset scorm timestamp")

    Excursion.all.map { |ex| 
      ex.update_column :scorm_timestamp, nil
    }

    printTitle("Task Finished")
  end


  #Usage
  #Development:   bundle exec rake fix:authors
  #In production: bundle exec rake fix:authors RAILS_ENV=production
  task :authors => :environment do

    printTitle("Fix authors and contributors")

    Excursion.all.select{|e| !e.author.nil?}.map { |ex|
      eJson = JSON(ex.json)

      #Fix author
      eJson["author"] = {name: ex.author.name, vishMetadata:{ id: ex.author.id}}

      #Fix author in quiz_simple_json.
      begin
        eJson["slides"].each do |slide|
          _fixAuthorInSlide(slide,ex)
          unless slide["slides"].nil?
            slide["slides"].each do |subslide|
              _fixAuthorInSlide(subslide,ex)
            end
          end
        end
      rescue
      end

      #Fix contributors
      if ex.contributors
        ex.contributors.uniq!
        ex.contributors.delete(ex.author)
        Excursion.record_timestamps=false
        ex.save!
        Excursion.record_timestamps=true
      end

      if ex.contributors and ex.contributors.length > 0
        eJson["contributors"] = [];
      end

      ex.contributors.each do |contributor|
        eJson["contributors"].push({name: contributor.name, vishMetadata:{ id: contributor.id}});
      end

      ex.update_column :json, eJson.to_json;
    }

    printTitle("Task Finished")
  end

  def _fixAuthorInSlide(slide,excursion)
    if slide["containsQuiz"]=="true" or slide["containsQuiz"]==true
      slide["elements"].each do |el|
        if el["type"]=="quiz" and !el["quiz_simple_json"].nil?
          el["quiz_simple_json"]["author"] = {name: excursion.author.name, vishMetadata:{ id: excursion.author.id}}
        end
      end
    end
  end


  #Usage
  #Development:   bundle exec rake fix:quizSessionResults
  #In production: bundle exec rake fix:quizSessionResults RAILS_ENV=production
  task :quizSessionResults => :environment do

    printTitle("Fixing Quiz Session Results")

    #Get all excursions
    quizAnswers = QuizAnswer.all
    quizAnswers.each do |qAnswer|
      begin
        answers = JSON(qAnswer.answer)
        newanswers = []

        if !answers.nil?
          answers.each do |answer|
            if !answer["no"].nil?
              answer["choiceId"] = answer["no"]
              answer.delete "no"
            end
            newanswers.push(answer)
          end
        end

        qAnswer.update_column :answer, newanswers.to_json

      rescue Exception => e
        puts "Quiz Answers with id:"
        puts qAnswer.id.to_s
        puts "Exception message"
        puts e.message
      end
    end

    printTitle("Task Finished")
  end

  #Usage
  #Development:   bundle exec rake fix:fillExcursionsLanguage
  #In production: bundle exec rake fix:fillExcursionsLanguage RAILS_ENV=production
  task :fillExcursionsLanguage => :environment do

    printTitle("Filling Excursions language")

    validLanguageCodes = ["de","en","es","fr","it","pt","ru"]
    #"ot" is for "other"

    Excursion.all.map { |ex|
      eJson = JSON(ex.json)

      lan = eJson["language"]
      emptyLan = (lan.nil? or !lan.is_a? String or lan=="independent")

      if emptyLan and !Vish::Application.config.APP_CONFIG["languageDetectionAPIKEY"].nil?
        #Try to infer language
        #Use https://github.com/detectlanguage/detect_language gem

        stringToTestLanguage = ""
        if ex.title.is_a? String and !ex.title.blank?
          stringToTestLanguage = stringToTestLanguage + ex.title + " "
        end
        if ex.description.is_a? String and !ex.description.blank?
          stringToTestLanguage = stringToTestLanguage + ex.description + " "
        end

        if stringToTestLanguage.is_a? String and !stringToTestLanguage.blank?
          detectionResult = (DetectLanguage.detect(stringToTestLanguage) rescue [])
          detectionResult.each do |result|
            if result["isReliable"] == true
              detectedLanguageCode = result["language"]
              if validLanguageCodes.include? detectedLanguageCode
                lan = detectedLanguageCode
              else
                lan = "ot"
              end
              emptyLan = false
              break
            end
          end
        end
      end

      if !emptyLan
        ao = ex.activity_object
        if ao.language != lan
          ao.update_column :language, lan
        end

        if eJson["language"] != lan
          eJson["language"] = lan
          ex.update_column :json, eJson.to_json
        end
      end

    }

    printTitle("Task Finished")
  end

  #Usage
  #Development:   bundle exec rake fix:recalculateScores
  #In production: bundle exec rake fix:recalculateScores RAILS_ENV=production
  task :recalculateScores => :environment do
    printTitle("Recalculating activity object scores")
    ActivityObject.all.each do |ao|
      ao.calculate_qscore
    end
    printTitle("Task Finished")
  end

  #Usage
  #Development:   bundle exec rake fix:fillIndexedLengths
  #In production: bundle exec rake fix:fillIndexedLengths RAILS_ENV=production
  task :fillIndexedLengths => :environment do
    printTitle("Filling indexed lengths")
    ActivityObject.all.each do |ao|
      if ao.title.is_a? String and ao.title.scan(/\w+/).size>0
        ao.update_column :title_length, ao.title.scan(/\w+/).size
      end
      if ao.description.is_a? String and ao.description.scan(/\w+/).size>0
        ao.update_column :desc_length, ao.description.scan(/\w+/).size
      end
      if ao.tag_list.is_a? ActsAsTaggableOn::TagList and ao.tag_list.length>0
        ao.update_column :tags_length, ao.tag_list.length
      end
    end
    printTitle("Task Finished")
  end


  #Usage
  #Development:   bundle exec rake fix:absoluteZipPaths
  #In production: bundle exec rake fix:absoluteZipPaths RAILS_ENV=production
  task :absoluteZipPaths => :environment do
    printTitle("Fixing absolute zip paths")

    (Scormfile.all + Webapp.all).each do |resource|
      unless resource.zippath.nil? or resource.zippath.index("/documents/").nil? or resource.zippath.index("/documents/")==0
        newZippath = resource.zippath[resource.zippath.index("/documents/")..-1]
        resource.update_column :zippath, newZippath
      end

      #Fix also loPaths when APP_CONFIG["code_path"] is not defined
      if Vish::Application.config.APP_CONFIG["code_path"].nil?
        unless resource.class != Scormfile or resource.lopath.nil? or resource.lopath.index("/public/scorm/packages").nil? or resource.lopath.index("/public/scorm/packages")==0
          #Fix Scormfiles
          newLopath = resource.lopath[resource.lopath.index("/public/scorm/packages")..-1]
          resource.update_column :lopath, newLopath
        end

        unless resource.class != Webapp or resource.lopath.nil? or resource.lopath.index("/public/webappscode").nil? or resource.lopath.index("/public/webappscode")==0
          #Fix WebApps
          newLopath = resource.lopath[resource.lopath.index("/public/webappscode")..-1]
          resource.update_column :lopath, newLopath
        end
      end

    end

    printTitle("Task Finished")
  end
  

  ####################
  #Task Utils
  ####################

  def printTitle(title)
    if !title.nil?
      puts "#####################################"
      puts title
      puts "#####################################"
    end
  end

  def printSeparator
    puts ""
    puts "--------------------------------------------------------------"
    puts ""
  end

end


####################
## Some manual fixes
####################

# * Set PDFEX permanent = true
# Pdfex.all.map { |pdfex| pdfex.update_column :permanent, true }
# * PDFEx Update pdf page count
# Pdfex.all.map { |pdfex| pdfex.updatePageCount }

# * Actualizar IDs de excursiones en el JSON, poner su id de verdad en vez del activity object, y meterlo en vish metadata
# Excursion.all.map { |ex| ejson = JSON(ex.json); ejson["vishMetadata"]={}; ejson["vishMetadata"]["id"] = ex.id.to_s; ejson.delete("id"); ex.update_column :json, ejson.to_json}

# * Poner scorm_timestamp a nil en todas las ex
# Excursion.all.map { |ex| ex.scorm_timestamp = nil; ex.update_column :scorm_timestamp, nil}


# Avatares defectuosos:

# Caso A: Thumbnails: "/assets/logos/original/excursion-XX.png"

# excursions = Excursion.all.select { |ex| 
# !ex.thumbnail_url.nil? and ex.thumbnail_url.include?("/assets/logos/original/excursion-") and !ex.thumbnail_url.include?("vishub") and !ex.thumbnail_url.include?("http://") and !ex.thumbnail_url.include?("https://")
# }

# Excursion.all.map { |ex| 
# if (!ex.thumbnail_url.nil? and ex.thumbnail_url.include?("/assets/logos/original/excursion-") and !ex.thumbnail_url.include?("vishub") and !ex.thumbnail_url.include?("http://") and !ex.thumbnail_url.include?("https://"))
#   newThumbnailUrl = Vish::Application.config.full_domain + ex.thumbnail_url;
# ex.update_column :thumbnail_url, newThumbnailUrl;
# ejson = JSON(ex.json); 
# ejson["avatar"]=newThumbnailUrl;
# ex.update_column :json, ejson.to_json;
# end
# }

# Caso B: ViSH Pictures: "/pictures/308.jpg"

# excursions = Excursion.all.select { |ex| 
# !ex.thumbnail_url.nil? and ex.thumbnail_url.include?("/pictures/") and !ex.thumbnail_url.include?("vishub") and !ex.thumbnail_url.include?("http://") and !ex.thumbnail_url.include?("https://")
# }

# Excursion.all.map { |ex| 
# if (!ex.thumbnail_url.nil? and ex.thumbnail_url.include?("/pictures/") and !ex.thumbnail_url.include?("vishub") and !ex.thumbnail_url.include?("http://") and !ex.thumbnail_url.include?("https://"))
#   newThumbnailUrl = Vish::Application.config.full_domain + ex.thumbnail_url;
# ex.update_column :thumbnail_url, newThumbnailUrl;
# ejson = JSON(ex.json); 
# ejson["avatar"]=newThumbnailUrl;
# ex.update_column :json, ejson.to_json;
# end
# }
